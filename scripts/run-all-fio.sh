#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# (c) 2018 Luis Chamberlain <mcgrof@kernel.org>
#
# Runs or checks all fio files found in the target directory provided.

FIO_POSTFIX=".ini"
DIR="./tests"
TMP_LIST=""
CHECK="false"
DRYRUN="false"
RUN_COUNT="0"
RUN_COUNT_SNIA="0"
SKIPPED_PRECON=0

TMP_LIST=$(mktemp)
TMP_LIST_SS_SEQ=$(mktemp)
TMP_LIST_SS_RAND=$(mktemp)
TMP_LIST_SNIA_IOPS=$(mktemp)
GENERIC_PRECOND_SNIA=""
ALL_SNIA_LISTS=""
LOG_DIR="logs"
TIME_CMD="date +%s"

NUM_TESTS=0
NUM_TESTS_SNIA=0
NUM_TESTS_SNIA_IOPS=0

ROUND_LIMIT=25
ROUND_MIN_COUNT=5
SOFT_LIMIT=""

source ${TOPDIR}/.config
source ${TOPDIR}/scripts/lib.sh

usage()
{
	echo "Usage: $0 [ options ]"
	echo "[ options ]:"
	echo "-h | --help      Print this help menu"
	echo "-d | --dir       Directory to use as fio terse version 3 input"
	echo "-p | --postfix   Postfix of the fio files to look for, .ini is default"
	echo "-c | --check     Do not run, just check that the files makes sense"
	echo "-n | --dryrun    Do not run, just print the fio commands that will be used"
}

parse_args()
{
	while [[ $# -gt 0 ]]; do
	key="$1"

	case $key in
	-h|--help)
		usage
		exit
	;;
	-c|--check)
		CHECK="true"
		shift
	;;
	-n|--dryrun)
		DRYRUN="true"
		shift
	;;
	-d|--dir)
		DIR="$2"
		shift
		shift
	;;
	-p|--postfix)
		FIO_POSTFIX="$2"
		shift
		shift
	;;
	*)
		echo "Unknown parameter: $key"
		usage
		exit
	;;
	esac
	done
}

remove_list_file()
{
	TARGET_RM=$1
	if [ "$TARGET_RM" != "" ]; then
		if [ -f $TARGET_RM ]; then
			rm -f $TARGET_RM
			rm -f $TARGET_RM.*
		fi
	fi
}

read_snia_round_config_settings()
{
	EVAL_LIST="$1"

	case $EVAL_LIST in
	$TMP_LIST_SNIA_IOPS)
		ROUND_LIMIT=$CONFIG_SNIA_IOPS_WD_ROUND_LIMIT
		ROUND_MIN_COUNT=$CONFIG_SNIA_IOPS_WD_ROUND_MIN_COUNT
		SOFT_LIMIT=$CONFIG_SNIA_IOPS_WD_ROUND_LIMIT_SOFT
	;;
	*)
	;;
	esac
}

snia_list_description()
{
	EVAL_LIST="$1"

	case $EVAL_LIST in
	$TMP_LIST_SNIA_IOPS)
		echo "iops"
	;;
	*)
	;;
	esac

}

test_finish()
{
	remove_list_file $TMP_LIST
	remove_list_file $TMP_LIST_SNIA_IOPS
	remove_list_file $TMP_LIST_SS_SEQ
	remove_list_file $TMP_LIST_SS_RAND
}

parse_config
parse_args $@

trap "test_finish" EXIT

find $DIR* -name \*${FIO_POSTFIX} \
	\! -name $PRECONDITION_SEQ_FILE \
	\! -name $PRECONDITION_RANDOM_FILE \
	-not -path "*0005-snia*" \
	-not -path "*${PRECONDITION_DIR}*" \
	> $TMP_LIST

NUM_TESTS=$(wc -l $TMP_LIST | awk '{print $1}')

if [ "$CONFIG_SNIA_IOPS" == "y" ] || [ "$CONFIG_PRECONDITION_SNIA_IOPS" == "y" ]; then
	find ./tests/0005-snia/0001-iops/* -name \*${FIO_POSTFIX} \
		> $TMP_LIST_SNIA_IOPS
	NUM_TESTS_SNIA_IOPS=$(wc -l $TMP_LIST_SNIA_IOPS | awk '{print $1}')
fi

if [ "$CONFIG_SNIA_TESTS" == "y" ]; then
	if [ "$CONFIG_PRECONDITION_SNIA_IOPS" != "y" ]; then
		ALL_SNIA_LISTS="$ALL_SNIA_LISTS $TMP_LIST_SNIA_IOPS"
	fi

	# XXX: once we add throughput, latency SNIA tests we extend this below
	#if [ "$CONFIG_PRECONDITION_SNIA_BW" != "y" ]; then
	#	ALL_SNIA_LISTS="$ALL_SNIA_LISTS $TMP_LIST_SNIA_BW"
	#fi
	#
	#if [ "$CONFIG_PRECONDITION_SNIA_LATENCY" != "y" ]; then
	#	ALL_SNIA_LISTS="$ALL_SNIA_LISTS $TMP_LIST_SNIA_LAT"
	#fi
fi

for SLIST in $ALL_SNIA_LISTS; do
	SCOUNT=$(wc -l $SLIST | awk '{print $1}')
	let NUM_TESTS_SNIA=$NUM_TESTS_SNIA+$SCOUNT
done

DIR_PREFIX="./"
if [ "$DIR" != "./" ]; then
	DIR_PREFIX=""
fi

print_header()
{
	if [ "$CHECK" == "true" ]; then
		printf "%28s %34s %42s %12s %12s\n" "Test" "Profile" "File" "Count" "Parses"
	else
		printf "%28s %34s %42s %12s %12s\n" "Test" "Profile" "File" "Count" "ETA"
	fi
}

print_header_snia()
{
	if [ "$CHECK" == "true" ]; then
		printf "%28s %34s %42s %12s %12s\n" "Test" "Profile" "File" "Count" "Parses"
	else
		printf "%10s %15s %60s %12s %12s\n" "Test" "Profile" "File" "Count" "Status"
	fi
}

print_header_ss()
{
	if [ "$CHECK" == "true" ]; then
		printf "%60s %12s\n" "File" "Parses"
	fi
}

run_list()
{
	RUN_LIST=$1

	echo $RUN_LIST | grep -q "^provision"
	if [ $? -eq 0 ]; then
		return
	fi

	print_header
	for i in $(cat $RUN_LIST | sort -n) ; do
		FILE=$(basename $i)
		TEST_TYPE=${i#${DIR_PREFIX}tests/}
		TEST_TYPE=${TEST_TYPE%%/*}

		PROFILE=${i#./tests/${TEST_TYPE}/}
		PROFILE=${PROFILE%%/*}

		TEST_NUMBER="$((RUN_COUNT+1))/$NUM_TESTS"

		NUM_TESTS_TO_GO=$((NUM_TESTS - RUN_COUNT))
		SECONDS_TO_COMPLETION=$((DUT_TOTAL_RUNTIME * NUM_TESTS_TO_GO))
		SHOW_PRECOND_TIME_ARG=""

		ETA=$(compute_eta $SECONDS_TO_COMPLETION)
		ANN_PRECOND=""

		uses_fio_ss_generic $FILE
		if [ $? -eq 0 ]; then
			ANN_PRECOND="--announce-precondition"
		fi
		PRE_DESC=$(get_precondition_file_prefill_desc $i)
		if [ "$PREFILL_DESC" != "" ]; then
			ANN_PRECOND="--announce-precondition"
			SHOW_PRECOND_TIME_ARG="--show-time"
		fi

		if [ "$CHECK" == "false" ]; then
			printf "%28s %34s %42s %12s %12s\n" "$TEST_TYPE" "$PROFILE" "$FILE" "$TEST_NUMBER" "$ETA"
			DRY_RUN_ARG=""
			if [ "$DRYRUN" == "true" ]; then
				DRY_RUN_ARG="--dryrun"
			fi
			scripts/run-fio.sh -f $i $DRY_RUN_ARG $ANN_PRECOND $SHOW_PRECOND_TIME_ARG
		else
			fio --parse-only $i 2>/dev/null
			RET=$?
			STATUS="OK"
			if [ $RET -ne 0 ]; then
				STATUS="FAIL: $RET"
			fi
			printf "%28s %34s %40s %10s %10s\n" "$TEST_TYPE" "$PROFILE" "$FILE" "$TEST_NUMBER" "$STATUS"
		fi
		let RUN_COUNT=$RUN_COUNT+1
	done
}

run_list_snia()
{
	RUN_LIST=$1
	ALL_RUN_RET=0
	ONCE_ARG=""
	TIME_ARG=""
	ANNOUNCE_PRECOND=""
	PREFILL_RUN="N"
	NUM_SS_ATTAINS=0
	NUM_SS_RUNS=0
	ATTAIN_PERCENT=0
	THIS_SS_RUN=0

	print_header_snia
	RUN_COUNT_SNIA=0
	LIST_NUM_TESTS=$(wc -l $RUN_LIST | awk '{print $1}')
	for i in $(cat $RUN_LIST | sort -n) ; do
		FILE=$(basename $i)
		is_snia_wi $FILE
		if [ $? -eq 1 ]; then
			PREFILL_RUN="Y"
		else
			PREFILL_RUN="N"
		fi

		if [ "$PREFILL_RUN" == "Y" ]; then
			echo " ----- Prefilling drive, this will take time -----"
			ONCE_ARG="--once"
			TIME_ARG="--show-time"
		else
			ONCE_ARG=""
			TIME_ARG=""
		fi
		uses_fio_ss $FILE
		if [ $? -eq 1 ]; then
			THIS_SS_RUN=1
			let NUM_SS_RUNS=$NUM_SS_RUNS+1
			ANNOUNCE_PRECOND="--announce-precondition"
		else
			THIS_SS_RUN=0
			ANNOUNCE_PRECOND=""
		fi
		TEST_TYPE=${i#${DIR_PREFIX}tests/}
		TEST_TYPE=${TEST_TYPE%%/*}

		PROFILE=${i#./tests/${TEST_TYPE}/}
		PROFILE=${PROFILE%%/*}

		TEST_NUMBER="$((RUN_COUNT_SNIA+1))/$LIST_NUM_TESTS"

		if [ "$CHECK" == "false" ]; then
			printf "%10s %15s %60s %12s" "$TEST_TYPE" "$PROFILE" "$FILE" "$TEST_NUMBER"
			DRY_RUN_ARG=""
			if [ "$DRYRUN" == "true" ]; then
				DRY_RUN_ARG="--dryrun"
			fi

			# run-fio.sh will return non-zero if either the fio run
			# failed or if steady-state (if the fio file uses it)
			# was not attained.
			scripts/run-fio.sh -f $i $ANNOUNCE_PRECOND $DRY_RUN_ARG $ONCE_ARG $TIME_ARG

			THIS_RET=$?
			if [ $THIS_RET -eq 0 ] && [ $THIS_SS_RUN -eq 1 ]; then
				let NUM_SS_ATTAINS=$NUM_SS_ATTAINS+1
			fi
			if [ $ALL_RUN_RET -eq 0 ] && [ $THIS_RET -ne 0 ]; then
				ALL_RUN_RET=$THIS_RET
			fi
			if [ "$PREFILL_RUN" == "Y" ] && [ $THIS_RET -ne 0 ]; then
				echo " Pre-fill failed, this should not happen, inspect..."
				echo "Fio file used: $i"
				echo "Command we ran:"
				echo
				echo "scripts/run-fio.sh -f $i $ANNOUNCE_PRECOND $DRY_RUN_ARG $ONCE_ARG $TIME_ARG"
				echo
			fi
		else
			fio --parse-only $i 2>/dev/null
			RET=$?
			STATUS="OK"
			if [ $RET -ne 0 ]; then
				STATUS="FAIL: $RET"
			fi
			printf "%28s %34s %40s %10s %10s\n" "$TEST_TYPE" "$PROFILE" "$FILE" "$TEST_NUMBER" "$STATUS"
		fi
		let RUN_COUNT_SNIA=$RUN_COUNT_SNIA+1
	done
	if [ "$CHECK" == "false" ] && [ $NUM_SS_RUNS -gt 0 ]; then
		ATTAIN_PERCENT=$((NUM_SS_ATTAINS*100/NUM_SS_RUNS))
		echo "------------------------------ $NUM_SS_ATTAINS / $NUM_SS_RUNS ($ATTAIN_PERCENT %) tests attained steady state"
	fi
	return $ALL_RUN_RET
}

run_list_snia_rounds()
{
	RUN_LIST=$1
	ROUND_COUNT=0
	ROUND_OK=0

	ALL_ROUNDS_RET=1

	read_snia_round_config_settings $RUN_LIST

	if [ "$CHECK" != "false" ]; then
		run_list_snia $RUN_LIST
		return $?
	fi

	if [ "$SOFT_LIMIT" == "y" ]; then
		echo "---- WARNING: will run *forever* until $ROUND_MIN_COUNT rounds succeed ! ----"
	fi

	while [ $ROUND_COUNT -lt $ROUND_LIMIT ] || [ "$SOFT_LIMIT" == "y" ]; do
		let ROUND_COUNT=$ROUND_COUNT+1
		if [ "$SOFT_LIMIT" == "y" ]; then
			echo "------------------------------ Round $ROUND_COUNT -----------------------------------"
		else
			echo "------------------------------ Round $ROUND_COUNT / $ROUND_LIMIT -----------------------------------"
		fi
		run_list_snia $RUN_LIST
		SNIA_RET=$?
		if [ $SNIA_RET -eq 0 ]; then
			echo "------------------------------ Round $ROUND_COUNT passed ! -------------------------------"
			let ROUND_OK=$ROUND_OK+1
			if [ $ROUND_OK -ge $ROUND_MIN_COUNT ]; then
				ALL_ROUNDS_RET=0
				echo "-------------------- Reached $ROUND_OK consecutive successful runs! -------------------"
				break
			fi
		else
			ROUND_OK=0
			echo "------------------------------ Round $ROUND_COUNT failed ------------------------------"
		fi
		if [ "$SOFT_LIMIT" == "y" ] && [ $ROUND_COUNT -eq $ROUND_LIMIT ]; then
			echo "-- Round limit reached: $ROUND_COUNT but configured as soft! Won't stop --"
		fi
	done

	return $ALL_ROUNDS_RET
}

run_list_ss()
{
	RUN_LIST=$1
	SS_RET=0
	THIS_SS_RET=0

	print_header_ss
	for i in $(cat $RUN_LIST | sort -n) ; do
		FILE=$(basename $i)

		if [ "$CHECK" == "false" ]; then
			DRY_RUN_ARG=""
			if [ "$DRYRUN" == "true" ]; then
				DRY_RUN_ARG="--dryrun"
			fi
			scripts/run-fio.sh -f $i --once $DRY_RUN_ARG --announce-precondition --show-time
			THIS_SS_RET=$?
			if [ $THIS_SS_RET -ne 0 ] && [ $SS_RET -eq 0 ]; then
				SS_RET=$THIS_SS_RET
			fi
		else
			fio --parse-only $i 2>/dev/null
			RET=$?
			STATUS="OK"
			if [ $RET -ne 0 ]; then
				STATUS="FAIL: $RET"
			fi
			printf "%60s %12s\n" "$i" "$STATUS"
		fi
	done

	return $THIS_SS_RET
}

run_list_sc_ss_rounds()
{
	RUN_LIST=$1
	SC_ROUND_LIMIT=$CONFIG_SANTA_CLARA_ROUND_LIMIT
	SC_ROUND=0
	SC_RET=0

	while [ $SC_ROUND -lt $SC_ROUND_LIMIT ]; do
		let SC_ROUND=$SC_ROUND+1
		#echo "Trying Santa Clara method round $SC_ROUND"
		run_list_ss $RUN_LIST
		SC_RET=$?
		if [ $SC_RET -eq 0 ]; then
			#echo "Round $SC_ROUND attained steady state successfully!"
			break
		fi
	done

	return $SC_RET
}

get_fio_rw()
{
	FIO_FILE=$1

	RW_LINE=$(grep ^rw= $FIO_FILE)
	if [ $? -eq 0 ]; then
		echo $RW_LINE | awk -F"=" '{print $2}'
	else
		echo ""
	fi
}

pre_condition_split_list()
{
	LIST=$1
	rm -f ${LIST}.*

	if [ "$LIST" == "provision" ]; then
		return
	fi

	echo "Sorting for pre-conditioning ..."
	for i in $(cat $LIST | sort -n) ; do
		RW=$(get_fio_rw $i)
		if [ "$RW" == "" ]; then
			echo "Invalid fio file, no rw= line entry: $i"
			exit 1
		fi
		SPLIT_LIST=${LIST}.${RW}
		echo $i >> $SPLIT_LIST
	done
}

pre_condition_print_stats()
{
	LIST=$1

	if [ "$LIST" == "provision" ]; then
		return
	fi

	printf "%10s %35s %25s\n" "Operation" "Description" "Number of tests"
	for RW in $PRECONDITION_ORDER; do
		SPLIT_LIST=${LIST}.${RW}
		if [ ! -f $SPLIT_LIST ]; then
			continue
		fi
		COUNT=$(wc -l $SPLIT_LIST | awk '{print $1}')
		printf "%10s %35s %25s\n" "$RW" "$(gen_name_prefix $RW)" "$COUNT"
	done
}

precondition_generic_prefill()
{
	TARGET_PRECOND=$1

	DRY_RUN_ARG=""
	if [ "$DRYRUN" == "true" ]; then
		DRY_RUN_ARG="--dryrun"
	fi

	PRECONDITION_FIO=$(get_precondition_file $TARGET_PRECOND)

	scripts/run-fio.sh -f $PRECONDITION_FIO --once $DRY_RUN_ARG --announce-precondition --show-time
	return $?
}

get_ss_tmp_list()
{
	TARGET_PRECOND=$1

	case $TARGET_PRECOND in
	$PRECOND_SEQ)
		echo $TMP_LIST_SS_SEQ
	;;
	$PRECOND_RAND)
		echo $TMP_LIST_SS_SEQ
	;;
	esac
}

build_precond_ss_list()
{
	TARGET_PRECOND=$1
	TMP_LIST_SS=$(get_ss_tmp_list $TARGET_PRECOND)

	TARGET_SEARCH_DIR=$(get_fio_ss_generic_dir $TARGET_PRECOND)

	find $TARGET_SEARCH_DIR/* -name \*${FIO_POSTFIX} > $TMP_LIST_SS
	echo $TMP_LIST_SS
}

__precondition_generic()
{
	TARGET_PRECOND=$1
	SC_SS_ROUND_RET=0

	DRY_RUN_ARG=""
	if [ "$DRYRUN" == "true" ]; then
		DRY_RUN_ARG="--dryrun"
	fi

	precondition_generic_prefill $TARGET_PRECOND
	PREFILL_RET=$?
	if [ $PREFILL_RET -ne 0 ]; then
		echo "Prefill failed: $PREFILL_RET"
		echo "This should not happen, please inspect the fio file and try to reproduce manually"
		return $PREFILL_RET
	fi

	if [ "$CONFIG_PRECONDITION_FIO_STEADY_STATE" == "y" ]; then
		PRECOND_SS_LIST=$(build_precond_ss_list $TARGET_PRECOND)
		run_list_sc_ss_rounds $PRECOND_SS_LIST
		SC_SS_ROUND_RET=$?
		if [ $SC_SS_ROUND_RET -ne 0 ]; then
			echo "Failed to attain steady state for target workload: $TARGET_PRECOND ..."
		fi
	fi
	return $SC_SS_ROUND_RET
}

precondition_energized()
{
	LOG_DIR_ENERGIZED="${LOG_DIR}/energized"
	DEVNAME=$(basename $CONFIG_DUT_FILENAME)
	LOG_FILE="$LOG_DIR_ENERGIZED/$DEVNAME"

	drive_requires_energized_state $CONFIG_DUT_FILENAME
	if [ $? -eq 1 ]; then
		mkdir -p $LOG_DIR_ENERGIZED
		DATE=$($TIME_CMD)
		echo "Energizing|$CONFIG_DUT_FILENAME|$DATE" >> $LOG_FILE
		echo "$CONFIG_DUT_FILENAME -- waiting to be properly energized... "
		drive_wait_for_energized_state $CONFIG_DUT_FILENAME
		echo "$CONFIG_DUT_FILENAME meets its energized preconditioning requirements"
		DATE=$($TIME_CMD)
		echo "Energized|$CONFIG_DUT_FILENAME|$DATE" >> $LOG_FILE
	fi
}

precondition_stage_1_skip_stage_2()
{
	LOG_DIR_SKIP_PRECON="${LOG_DIR}/skip-precon"
	DEVNAME=$(basename $CONFIG_DUT_FILENAME)
	LOG_FILE_PRECON="$LOG_DIR_SKIP_PRECON/$DEVNAME"

	precondition_energized

	drive_can_skip_precondition $CONFIG_DUT_FILENAME
	SKIP_PRECON=$?
	if [ "$SKIP_PRECON" -eq 1 ]; then
		if [ "$SKIPPED_PRECON" -ne 1 ]; then
			mkdir -p $LOG_DIR_SKIP_PRECON
			echo "$CONFIG_DUT_FILENAME does not need pre-conditioning, to force use CONFIG_FORCE_PRECONDITION=y"
			DATE=$($TIME_CMD)
			echo "Skipping preconditioning|$CONFIG_DUT_FILENAME|$DATE" >> $LOG_FILE_PRECON
		fi
		SKIPPED_PRECON=1
		return 1
	fi
	return 0
}

precondition_generic()
{
	TARGET_PRECOND=$1

	if [ "$TARGET_PRECOND" == "none" ]; then
		return 0
	fi

	precondition_stage_1_skip_stage_2
	if [ $? -ne 0 ]; then
		return 0
	fi

	__precondition_generic $TARGET_PRECOND
	return $?
}

pre_condition_run_split_lists()
{
	LIST=$1

	for RW in $PRECONDITION_ORDER; do
		SPLIT_LIST=${LIST}.${RW}
		if [ "$CONFIG_PRECONDITION_PROVISION_SC" != "y" ] && [ ! -f $SPLIT_LIST ]; then
			continue
		fi
		DRY_RUN_ARG=""
		if [ "$DRYRUN" == "true" ]; then
			DRY_RUN_ARG="--dryrun"
		fi

		if [ "$CONFIG_PRECONDITION_GENERIC_SC" == "y" ]; then
			PRIOR_REQ=$(get_pre_condition_prior_req $RW)
			PRECOND_REQ=$(get_pre_condition_req $RW)

			if [ "$LIST" == "provision" ] && [ "$CONFIG_PROVISION_SC_SEQUENTIAL" == "y" ]; then
				op_is_random $RW
				if [ $? -eq 1 ]; then
					continue
				fi
			fi

			precondition_generic $PRIOR_REQ
			SC_PRECOND_PREQ_RET=$?
			if [ $SC_PRECOND_PREQ_RET -ne 0 ]; then
				return $SC_PRECOND_PREQ_RET
			fi

			precondition_generic $PRECOND_REQ
			SC_PRECOND_REQ_RET=$?
			if [ $SC_PRECOND_REQ_RET -ne 0 ]; then
				return $SC_PRECOND_REQ_RET
			fi
		elif [ "$CONFIG_PRECONDITION_SNIA_IOPS" == "y" ]; then
			echo "-- Pre-conditioning using SNAI iops ---"
			echo "Number of SNIA iops pre-conditioning tests: $NUM_TESTS_SNIA_IOPS"
			run_list_snia_rounds $TMP_LIST_SNIA_IOPS
			SNIA_RET=$?
			if [ $SNIA_RET -eq 0 ]; then
				echo "Succeeded!"
			else
				echo "Failed!"
				return $SNIA_RET
			fi
		fi

		run_list $SPLIT_LIST
	done
}

pre_condition_list()
{
	LIST=$1

	pre_condition_split_list $LIST
	pre_condition_print_stats $LIST
	pre_condition_run_split_lists $LIST
}

get_purge_ses_option()
{
	SES_VAL=0

	for i in $(seq 0 7); do
		VAR=CONFIG_PURGE_SES_$i
		if [ "${!VAR}" != "" ]; then
			SES_VAL=$i
			break
		fi
	done

	echo $SES_VAL
}

get_purge_pil()
{
	PIL_VAL=0

	for i in $(seq 0 1); do
		VAR=CONFIG_PURGE_PIL_$i
		if [ "${!VAR}" != "" ]; then
			PIL_VAL=$i
			break
		fi
	done

	echo $PIL_VAL
}

get_purge_pi()
{
	PIL_ARG=""
	if [ "$CONFIG_PURGE_PI" == "y" ]; then
		PIL_ARG_VAL=$(get_purge_pil)
		PIL_ARG="--pi=1 --pil=$PIL_ARG_VAL"
	fi
	echo $PIL_ARG
}

get_purge_nsid()
{
	NSID=""

	if [ "$CONFIG_PURGE_NSID_SPECIFIC" == "y" ]; then
		NSID="--namespace-id=$CONFIG_PURGE_NSID"
	fi

	echo $NSID
}

get_purge_lbaf()
{
	LBAF=""

	if [ "$CONFIG_PURGE_LBAF_SPECIFIC" == "y" ]; then
		LBAF="--lbaf=$CONFIG_PURGE_LBAF"
	fi

	echo $LBAF
}

get_purge_ms()
{
	MS_SET=""

	if [ "$CONFIG_PURGE_MS_SPECIFIC" == "y" ]; then
		MS_SET="--ms=$CONFIG_PURGE_MS"
	fi

	echo $MS_SET
}

get_purge_timeout()
{
	PURGE_TM=""

	if [ "$CONFIG_PURGE_TIMEOUT_SET" = "y" ]; then
		PURGE_TM="--timeout $CONFIG_PURGE_TIMEOUT_MS"
	fi

	echo $PURGE_TM
}

get_purge_reset()
{
	PURGE_RESET=""

	if [ "$CONFIG_PURGE_RESET" == "y" ]; then
		PURGE_RESET="-r"
	fi

	echo $PURGE_RESET
}

nvme_get_dpc()
{
	echo $(nvme id-ns $1 -H | grep ^dpc| awk -F": " '{print $2}')
}

nvme_check_purge_pi()
{
	if [ "$CONFIG_PURGE_PI" != "y" ]; then
		return 0
	fi

	NVME_CAP_DPC=$(nvme_get_dpc $CONFIG_DUT_FILENAME)

	if [ "$NVME_CAP_DPC" == "0" ]; then
		echo "Data protection is not supported by $CONFIG_DUT_FILENAME, but you configured your NVMe purge"
		echo "settings to format the $CONFIG_DUT_FILENAME with data protection enabled (CONFIG_PURGE_PI)."

		return 1
	fi

	return 0
}

nvme_check_purge_lbaf()
{
	# XXX
	return 0
}

nvme_check_purge_cmd()
{
	RET=0

	if [ "$CONFIG_PURGE_NVME_PURGE_VERIFY" != "y" ] || [ "$DRYRUN" == "true" ]; then
		return 0
	fi

	nvme_check_purge_pi
	RET=$((RET || $?))

	nvme_check_purge_lbaf
	RET=$((RET || $?))

	if [ $RET -ne 0 ]; then
		echo
		echo "Formatting your NVMe device with your current configuration would fail,"
		echo "we are preventing things to move forward to avoid unclear errors."
		echo
		echo "Verify your configuration is valid."
	fi

	return $?
}

nvme_purge_device()
{
	LOG_DIR_PURGE="${LOG_DIR}/purge"
	DEVNAME=$(basename $CONFIG_DUT_FILENAME)
	LOG_FILE_PURGE="${LOG_DIR_PURGE}/${DEVNAME}"

	if [ "$CONFIG_PURGING_NVME" != "y" ]; then
		return
	fi

	PURGE_DEVICE=$CONFIG_DUT_FILENAME
	PURGE_NSID_ARGS=$(get_purge_nsid)
	PURGE_PI_ARGS=$(get_purge_pi)
	PURGE_LBAF_ARG=$(get_purge_lbaf)
	PURGE_MS_ARG=$(get_purge_ms)
	PURGE_TIMEOUT_ARG=$(get_purge_timeout)
	PURGE_RESET_ARG=$(get_purge_reset)

	PURGE_ALL_ARGS="$PURGE_NSID_ARGS --ses=$(get_purge_ses_option)"
	PURGE_ALL_ARGS="$PURGE_ALL_ARGS $PURGE_PI_ARGS $PURGE_LBAF_ARG"
	PURGE_ALL_ARGS="$PURGE_ALL_ARGS $PURGE_MS_ARG $PURGE_TIMEOUT_ARG"
	PURGE_ALL_ARGS="$PURGE_ALL_ARGS $PURGE_RESET_ARG $PURGE_DEVICE"

	nvme_check_purge_cmd
	if [ $? -ne 0 ]; then
		exit
	fi

	echo "Purging device, this will take a while ..."
	echo nvme format $PURGE_ALL_ARGS
	mkdir -p $LOG_DIR_PURGE
	DATE=$($TIME_CMD)
	echo "Start purge|$CONFIG_DUT_FILENAME|$DATE|nvme format $PURGE_ALL_ARGS" >> $LOG_FILE_PURGE
	if [ "$DRYRUN" != "true" ]; then
		time nvme format $PURGE_ALL_ARGS
	fi
	RET=$?
	DATE=$($TIME_CMD)
	echo "Finished purge|$CONFIG_DUT_FILENAME|$DATE|$RET" >> $LOG_FILE_PURGE
	if [ $RET -ne 0 ]; then
		echo
		echo "NVME purge failed, return error: $RET"
		echo
		exit
	fi
}

run_snia_tests()
{
	LOG_DIR_SNIA="${LOG_DIR}/snia"
	DEVNAME=$(basename $CONFIG_DUT_FILENAME)

	precondition_stage_1_skip_stage_2
	if [ $? -ne 0 ]; then
		return 0
	fi

	for SLIST in $ALL_SNIA_LISTS; do
		SNIA_DESC="$(snia_list_description $SLIST)"
		LOG_DIR_SNIA_IOPS="${LOG_DIR_SNIA}/${SNIA_DESC}"
		LOG_FILE_SNIA_IOPS="${LOG_DIR_SNIA_IOPS}/${DEVNAME}"

		mkdir -p $LOG_DIR_SNIA_IOPS

		DATE=$($TIME_CMD)
		echo "Start SNIA test|$CONFIG_DUT_FILENAME|${DATE}|$SNIA_DESC" >> $LOG_FILE_SNIA_IOPS

		DATE=$($TIME_CMD)
		echo "Purge start|$CONFIG_DUT_FILENAME|${DATE}|$SNIA_DESC" >> $LOG_FILE_SNIA_IOPS

		nvme_purge_device

		DATE=$($TIME_CMD)
		echo "Purge finished|$CONFIG_DUT_FILENAME|${DATE}|$SNIA_DESC" >> $LOG_FILE_SNIA_IOPS

		DATE=$($TIME_CMD)
		echo "Start SNIA rounds|$CONFIG_DUT_FILENAME|${DATE}|$SNIA_DESC" >> $LOG_FILE_SNIA_IOPS

		run_list_snia_rounds $SLIST

		DATE=$($TIME_CMD)
		echo "Finished SNIA rounds|${CONFIG_DUT_FILENAME}|${DATE}|$SNIA_DESC" >> $LOG_FILE_SNIA_IOPS

		SNIA_RET=$?
		if [ $SNIA_RET -eq 0 ]; then
			echo "Succeeded!"
		else
			echo "Failed!"
		fi

		DATE=$($TIME_CMD)
		echo "Finished SNIA test|$CONFIG_DUT_FILENAME|${DATE}|$SNIA_DESC|$SNIA_RET" >> $LOG_FILE_SNIA_IOPS
	done
}


LOG_DIR_RUNS="${LOG_DIR}/runs"
DEVNAME=$(basename $CONFIG_DUT_FILENAME)
LOG_FILE_RUNS="$LOG_DIR_RUNS/$DEVNAME"

mkdir -p $LOG_DIR_RUNS

DATE=$($TIME_CMD)
echo "Start run|$CONFIG_DUT_FILENAME|$DATE" >> $LOG_FILE_RUNS
echo "$DATE" > ${LOG_DIR_RUNS}/START

LOG_DIR_PROVISIONING="${LOG_DIR}/provisioning"

TOTAL_NUM_TESTS=$((NUM_TESTS+NUM_TESTS_SNIA+NUM_TESTS_SNIA_IOPS))
if [ $TOTAL_NUM_TESTS -ne 0 ]; then
	NON_SNIA_TESTS=$((TOTAL_NUM_TESTS-NUM_TESTS_SNIA))
	if [ $NON_SNIA_TESTS -eq $TOTAL_NUM_TESTS ]; then
		if [ "$CONFIG_PRECONDITION_SNIA_IOPS" == "y" ]; then
			LOG_DIR_PROVISION_SNIA="${LOG_DIR_PROVISIONING}/snia/"
			LOG_DIR_PROVISION_SNIA_IOPS="${LOG_DIR_PROVISION_SNIA}/iops"
			LOG_FILE_PROVISION_SNIA_IOPS="${LOG_DIR_PROVISION_SNIA_IOPS}/${DEVNAME}"

			echo "Provisioning $CONFIG_DUT_FILENAME using SNIA IOPS test ..."

			mkdir -p $LOG_DIR_PROVISION_SNIA_IOPS

			DATE=$($TIME_CMD)
			echo "Start provisioning|$CONFIG_DUT_FILENAME|${DATE}|SNIA IOPS" >> $LOG_FILE_PROVISION_SNIA_IOPS

			run_snia_tests

			DATE=$($TIME_CMD)
			echo "Finished provisioning|$CONFIG_DUT_FILENAME|${DATE}SNIA IOPS" >> $LOG_FILE_PROVISION_SNIA_IOPS
		else
			echo "A SNIA style of pre-conditioning was enabled but no tests were enabled"
		fi
	else
		echo "Total number of tests: $TOTAL_NUM_TESTS"
	fi
else
	if [ "$CONFIG_PRECONDITION_PROVISION_SC" == "y" ]; then
		LOG_DIR_PROVISION_SANTA_CLARA="${LOG_DIR_PROVISIONING}/santa-clara/"
		LOG_FILE_PROVISION_SANTA_CLARA="${LOG_DIR_PROVISION_SANTA_CLARA}/${DEVNAME}"

		echo "Provisioning $CONFIG_DUT_FILENAME using the Santa Clara method ..."

		mkdir -p $LOG_DIR_PROVISION_SANTA_CLARA

		DATE=$($TIME_CMD)
		echo "Start provisioning|$CONFIG_DUT_FILENAME|${DATE}|Santa Clara" >> $LOG_FILE_PROVISION_SANTA_CLARA

		nvme_purge_device
		pre_condition_list provision

		DATE=$($TIME_CMD)
		echo "Finished provisioning|${CONFIG_DUT_FILENAME}|${DATE}|Santa Clara" >> $LOG_FILE_PROVISION_SANTA_CLARA
	else
		echo "No tests were enabled."
	fi
fi

if [ $NUM_TESTS -ne 0 ]; then
	LOG_DIR_EVAL_TESTS="${LOG_DIR}/performance-evaluation"

	echo "Number of performance evaluation tests: $NUM_TESTS"

	if [ "$CONFIG_STEADY_STATE_PROVISIONING" == "y" ]; then
		LOG_DIR_EVAL_PROVISIONED_TESTS="${LOG_DIR_EVAL_TESTS}/provisioned"
		LOG_FILE_EVAL_PROVISIONED_TESTS="${LOG_DIR_EVAL_PROVISIONED_TESTS}/${DEVNAME}"

		mkdir -p $LOG_DIR_EVAL_PROVISIONED_TESTS

		DATE=$($TIME_CMD)
		echo "Start provisioned performance evaluation|$CONFIG_DUT_FILENAME|$DATE|Number of tests: $NUM_TESTS" >> $LOG_FILE_EVAL_PROVISIONED_TESTS

		nvme_purge_device
		pre_condition_list $TMP_LIST

		DATE=$($TIME_CMD)
		echo "Finished provisioned performance evaluation|$CONFIG_DUT_FILENAME|$DATE|Number of tests: $NUM_TESTS" >> $LOG_FILE_EVAL_PROVISIONED_TESTS
	else
		LOG_DIR_EVAL_UNPROVISIONED_TESTS="${LOG_DIR_EVAL_TESTS}/unprovisioned"
		LOG_FILE_EVAL_UNPROVISIONED_TESTS="${LOG_DIR_EVAL_UNPROVISIONED_TESTS}/${DEVNAME}"

		mkdir -p $LOG_DIR_EVAL_UNPROVISIONED_TESTS

		DATE=$($TIME_CMD)
		echo "Start unprovisioned performance evaluation|$CONFIG_DUT_FILENAME|$DATE|Number of tests: $NUM_TESTS" >> $LOG_FILE_EVAL_UNPROVISIONED_TESTS

		run_list $TMP_LIST

		DATE=$($TIME_CMD)
		echo "Finished unprovisioned performance evaluation|$CONFIG_DUT_FILENAME|$DATE|Number of tests: $NUM_TESTS" >> $LOG_FILE_EVAL_UNPROVISIONED_TESTS
	fi
fi

if [ "$CONFIG_SNIA_TESTS" == "y" ] && [ $NUM_TESTS_SNIA -ne 0 ]; then
	echo "Number of all SNIA tests: $NUM_TESTS_SNIA"
	run_snia_tests
fi

DATE=$($TIME_CMD)
echo "Finished run|$CONFIG_DUT_FILENAME|$DATE" >> $LOG_FILE_RUNS
echo "$DATE" > ${LOG_DIR_RUNS}/END
