#!/bin/bash

PRECONDITION_ORDER="write read randwrite randread randrw"

PRECONDITION_DIR="pre-conditioning"
PRECONDITION_SEQ_FILE="0001-pre-condition-sequential.ini"
PRECONDITION_RANDOM_FILE="0002-pre-condition-random.ini"

SS_PRECONDITION_TEMPLATE_FILE="0001-steady-state.ini"

SNIA_PRECOND="0005-snia"

PRECONDITION_SEQ="${PRECONDITION_DIR}/0001-workload-independent/${PRECONDITION_SEQ_FILE}"
PRECONDITION_RANDOM="${PRECONDITION_DIR}/0001-workload-independent/${PRECONDITION_RANDOM_FILE}"

PRECOND_SS_DIR="${PRECONDITION_DIR}/0002-workload-dependent"
PRECOND_SS_DIR_SEQ="${PRECONDITION_DIR}/0002-workload-dependent/sequential/"
PRECOND_SS_DIR_RAND="${PRECONDITION_DIR}/0002-workload-dependent/random/"

PRECOND_SEQ="sequential"
PRECOND_RAND="random"

source ${TOPDIR}/scripts/noconfig-lib.sh

get_precond_snia_generic_dir()
{
	if [ "$CONFIG_PRECONDITION_SNIA_IOPS" == "y" ]; then
		echo "tests/${SNIA_PRECOND}/0001-iops"
	fi
}

gen_name_prefix()
{
	echo -n "$NAME_PREFIX"
	case $RW in
	read)
		echo "sequential read"
	;;
	randread)
		echo "random read"
	;;
	write)
		echo "sequential write"
	;;
	randwrite)
		echo "random write"
	;;
	randrw)
		echo "random mixed read write"
	;;
	esac
}

gen_name_prefix_jobname()
{
	NAME_PREFIX="$(gen_name_prefix $RW)"
	echo $NAME_PREFIX | sed -e 's/ /-/g'
}

gen_mix_name()
{
	WRITE_VAL=""
	if [ "$RWMIXREAD_VAL" = "" ]; then
		echo ""
		return
	fi

	WRITE_VAL=$((100-$RWMIXREAD_VAL))
	echo " MIX ${RWMIXREAD_VAL}% read / ${WRITE_VAL}% write"
}

gen_name()
{
	USE_PREFIX=""
	if [ "$NUMJOBS" == "" ]; then
		echo "Number of jobs is empty"
		exit
	fi
	if [ "$1" != "" ]; then
		USE_PREFIX="$1"
	fi
	NAME_PREFIX=$(gen_name_prefix $RW)
	MIX=$(gen_mix_name)
	echo -n "${USE_PREFIX}${BS} $NAME_PREFIX"
	if [ "$MIX" != "" ]; then
		echo -n "$MIX"
	fi
	echo -n " with iodepth $IODEPTH and "
	if [ $NUMJOBS -eq 1 ]; then
		echo -n "1 thread"
	else
		echo -n "$NUMJOBS threads"
	fi
}

gen_fio_filename()
{
	if [ "$MIN_IODEPTH_BATCH_SUBMIT" = "" ]; then
		printf "%04d-bs%s-%dj-%dqd-%s.ini" $FILE_NUMBER $BS $NUMJOBS $IODEPTH $RW
	else
		printf "%04d-bs%s-%diobs-%dj-%dqd-%s.ini" $FILE_NUMBER $BS $IODEPTHBATCHSUBMIT $NUMJOBS $IODEPTH $RW
	fi
}

gen_fio_filename_ss_generic()
{
	BASE_NUM=$1
	TARGET_COND=$2
	FOCUS=$3

	PREFIX_NAME="fio_ss_generic"
	TARGET_DIR=0002-workload-dependent/${TARGET_COND}

	printf "%s/%04d-%s-%s-%s.ini" $TARGET_DIR $BASE_NUM $PREFIX_NAME $TARGET_COND $FOCUS
}

get_fio_ss_generic_dir()
{
	TARGET_COND=$1
	if [ "$TARGET_COND" == "$PRECOND_SEQ" ]; then
		echo "$PRECOND_SS_DIR_SEQ"
	elif [ "$TARGET_COND" == "$PRECOND_RAND" ]; then
		echo "$PRECOND_SS_DIR_RAND"
	else
		echo "Invalid target: $TARGET_COND"
		exit
	fi
}

gen_fio_filename_snia_id()
{
	if [ "$USES_FIO_SS" == "" ]; then
		printf "%04d-%s-%s-%dqd-%dj-bs%s.ini" $FILE_NUMBER $MODE $RW $IODEPTH $NUMJOBS $BS
	else
		printf "%04d-%s-%s-%s-%dqd-%dj-bs%s.ini" $FILE_NUMBER $MODE "fio_ss" $RW $IODEPTH $NUMJOBS $BS
	fi
}

gen_fio_filename_snia_wd()
{
	if [ "$MIN_IODEPTH_BATCH_SUBMIT" = "" ]; then
		if [ "$USES_FIO_SS" == "" ]; then
			printf "%04d-%s-%s-%dqd-%dj-bs%s.ini" $FILE_NUMBER $MODE $DIR_RW $IODEPTH $NUMJOBS $BS
		else
			printf "%04d-%s-%s-%s-%dqd-%dj-bs%s.ini" $FILE_NUMBER $MODE "fio_ss" $DIR_RW $IODEPTH $NUMJOBS $BS
		fi
	else
		if [ "$USES_FIO_SS" == "" ]; then
			printf "%04d-%s-%s-%dqd-%diobs-%dj-bs%s.ini" $FILE_NUMBER $MODE $DIR_RW $IODEPTH $IODEPTHBATCHSUBMIT $NUMJOBS $BS
		else
			printf "%04d-%s-%s-%s-%dqd-%diobs-%dj-bs%s.ini" $FILE_NUMBER $MODE "fio_ss" $DIR_RW $IODEPTH $IODEPTHBATCHSUBMIT $NUMJOBS $BS
		fi
	fi
}

cat_template_file_sed()
{
	cat $1 | sed -e \
		'
		s|@NAME@|'"$NAME"'|g;
		s|@BS@|'$BS'|g;
		s|@RUNTIME@|'$RUNTIME'|g;
		s|@RUNTIMESET@|'$RUNTIMESET'|g;
		s|@SIZE@|'$SIZE'|g;
		s|@SIZESET@|'$SIZESET'|g;
		s|@NUMJOBS@|'$NUMJOBS'|g;
		s|@IODEPTH@|'$IODEPTH'|g;
		s|@FILENAME@|'$FILENAME'|g;
		s|@FIRSTJOBNAME@|'$FIRSTJOBNAME'|g;
		s|@RW@|'$RW'|g;
		s|@RWMIXREAD@|'$RWMIXREAD'|g;
		s|@RAMPTIME@|'$RAMPTIME'|g;
		s|@IODEPTHBATCHSUBMIT@|'$IODEPTHBATCHSUBMIT'|g;
		s|@IODEPTHBATCHCOMPLETEMIN@|'$IODEPTHBATCHCOMPLETEMIN'|g;
		s|@IODEPTHBATCHCOMPLETEMAX@|'$IODEPTHBATCHCOMPLETEMAX'|g;
		s|@LOOPS@|'$LOOPS'|g;
		s|@SSSLOPENAME@|'$SSSLOPENAME'|g;
		s|@SSMEANLIMIT@|'$SSMEANLIMIT'|g;
		s|@SSMEANLIMITDUR@|'$SSMEANLIMITDUR'|g;
		s|@SSSLOPENAME@|'$SSSLOPENAME'|g;
		s|@SSSLOPE@|'$SSSLOPE'|g;
		s|@SSSLOPEDUR@|'$SSSLOPEDUR'|g;
		s|@SSMEANLIMITNAME@|'$SSMEANLIMITNAME'|g;
		s|@SSSLOPENAME@|'$SSSLOPENAME'|g;
		s|@RANDOMNUMGEN@|'$RANDOMNUMGEN'|g;
		' | cat -s
}

dut_time_val_to_seconds()
{
	SECONDS="-1"
	case $1 in
	*h)
		HOURS=${1%*h}
		SECONDS=$((HOURS * 60 * 60))
	;;
	*m)
		MINUTES=${1%*m}
		SECONDS=$((MINUTES * 60))
	;;
	*s)
		SECONDS=${1%*s}
	;;
	*)
		SECONDS="-1"
	;;
	esac
	echo $SECONDS
}

dut_runtime_to_seconds()
{
	echo $(dut_time_val_to_seconds $CONFIG_DUT_RUNTIME)
}

dut_ramptime_to_seconds()
{
	echo $(dut_time_val_to_seconds $CONFIG_DUT_RAMP_TIME)
}

compute_seconds_portable()
{
	case $(uname -s) in
	Darwin)
		echo "About ~ $1 seconds"
	;;
	Linux)
		eval "echo $(date -ud "@$1" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')"
	;;
	*)
		echo "About ~ $1 seconds"
	;;
	esac
}

compute_eta()
{
	seconds=$1
	compute_seconds_portable $seconds
}


config_sanity_check()
{
	if [ ! -f $TOPDIR/.config ]; then
		echo "Configuration not written, run make menuconfig"
		exit
	fi
	DUT_RUNTIME=$(dut_runtime_to_seconds)
	if [ "$DUT_RUNTIME" == "-1" ]; then
		echo "Unsupported time configuration on CONFIG_DUT_RUNTIME: $CONFIG_DUT_RUNTIME"
		exit
	fi

	DUT_RAMPTIME=$(dut_ramptime_to_seconds)
	if [ "$DUT_RAMPTIME" == "-1" ]; then
		echo "Unsupported time configuration on CONFIG_DUT_RAMP_TIME: $CONFIG_DUT_RAMP_TIME"
		exit
	fi
	if [ "$CONFIG_DUT_RAMP_TIME" == "" ] || [ "$CONFIG_DUT_RAMP_TIME" == "0s" ]; then
		RAMPTIME_VAL=""
		RAMPTIME=""
	else
		RAMPTIME_VAL="$CONFIG_DUT_RAMP_TIME"
		RAMPTIME="ramp_time=$RAMPTIME_VAL"
	fi

	DUT_TOTAL_RUNTIME=$((DUT_RUNTIME + DUT_RAMPTIME))
}

get_pre_condition_prior_req()
{
	RW=$1
	RANDOM_REQ="none"

	if [ "$CONFIG_PRECONDITION_STRICT_ORDER" = "y" ]; then
		RANDOM_REQ="$PRECOND_SEQ"
	fi

	case $RW in
	write)
		echo none
	;;
	read)
		echo none
	;;
	randwrite)
		echo $RANDOM_REQ
	;;
	randread)
		echo $RANDOM_REQ
	;;
	randrw)
		echo $RANDOM_REQ
	;;
	esac
}

get_pre_condition_req()
{
	RW=$1

	case $RW in
	write)
		echo $PRECOND_SEQ
	;;
	read)
		echo $PRECOND_SEQ
	;;
	randwrite)
		echo $PRECOND_RAND
	;;
	randread)
		echo $PRECOND_RAND
	;;
	randrw)
		echo $PRECOND_RAND
	;;
	esac
}

op_is_random()
{
	RW=$1

	case $RW in
	write)
		return 0;
	;;
	read)
		return 0;
	;;
	randwrite)
		return 1;
	;;
	randread)
		return 1;
	;;
	randrw)
		return 1;
	;;
	esac

	return 0;
}


get_precondition_file()
{
	TARGET_COND=$1
	case $TARGET_COND in
	$PRECOND_SEQ)
		echo $PRECONDITION_SEQ
	;;
	$PRECOND_RAND)
		echo $PRECONDITION_RANDOM
	;;
	esac
}

is_snia_wd()
{
	case $1 in
	*snia-wd*)
		return 1
	;;
	*)
		return 0
	;;
	esac
}

is_snia_wi()
{
	case $1 in
	*snia-wi*)
		return 1
	;;
	*)
		return 0
	;;
	esac
}

uses_fio_ss()
{
	case $1 in
	*fio_ss*)
		return 1
	;;
	*)
		return 0
	;;
	esac
}

uses_fio_ss_generic()
{
	case $1 in
	*fio_ss_generic*)
		return 1
	;;
	*)
		return 0
	;;
	esac
}

get_precondition_file_prefill_desc()
{
	PRECOND_FILE=$1

	case $PRECOND_FILE in
	$PRECONDITION_SEQ)
		echo "sequential workloads"
	;;
	$PRECONDITION_RANDOM)
		echo "random workloads"
	;;
	*)
		echo ""
	esac
}

generic_ss_desc()
{
	case $1 in
	*iops*)
		echo "IOPS"
	;;
	*bw*)
		echo "throughput"
	;;
	esac
}

parse_config()
{
	config_sanity_check
}

intel_nvme_drive_can_skip_precondition()
{
	DRIVE=$1
	MARKET_NAME=$(nvme intel market-name $DRIVE | tail -1)

	case $MARKET_NAME in
	*Optane*)
		return 1
	;;
	*)
		return 0
	esac
}

nvme_drive_can_skip_precondition()
{
	DRIVE=$1
	MN=$(nvme id-ctrl $DRIVE | grep "^mn ")
	echo $MN | grep -q -i intel
	if [ $? -eq 0 ]; then
		intel_nvme_drive_can_skip_precondition $DRIVE
		return $?
	else
		return 0
	fi
}

drive_can_skip_precondition()
{
	DRIVE=$1

	if [ "$CONFIG_FORCE_PRECONDITION" == "y" ]; then
		return 0;
	fi

	is_nvme $DRIVE
	if [ $? -eq 1 ]; then
		nvme_drive_can_skip_precondition $DRIVE
		return $?
	fi
	return 0
}

intel_nvme_drive_requires_energized_state()
{
	DRIVE=$1
	MARKET_NAME=$(nvme intel market-name $DRIVE | tail -1)

	if [ "$CONFIG_ENERGIZED_STEADY_STATE" != "y" ]; then
		return 0;
	fi

	case $MARKET_NAME in
	*Optane*)
		return 1
	;;
	*)
		return 0
	esac
}

nvme_drive_requires_energized_state()
{
	DRIVE=$1
	MN=$(nvme id-ctrl $DRIVE | grep "^mn ")
	echo $MN | grep -q -i intel
	if [ $? -eq 0 ]; then
		intel_nvme_drive_requires_energized_state $DRIVE
		return $?
	else
		return 0
	fi
}

drive_requires_energized_state()
{
	DRIVE=$1
	is_nvme $DRIVE
	if [ $? -eq 1 ]; then
		nvme_drive_requires_energized_state $DRIVE
		return $?
	fi
	return 0
}

intel_nvme_wait_for_energized_state()
{
	DRIVE=$1
	MARKET_NAME=$(nvme intel market-name $DRIVE | tail -1)

	if [ "$CONFIG_ENERGIZED_STEADY_STATE" != "y" ]; then
		return;
	fi

	UPTIME=$(cat /proc/uptime | awk '{print $1}')
	UPTIME=${UPTIME%.*}
	case $MARKET_NAME in
	*P4500*)
		# XXX: a system could be powered up for a period of time but
		# the drive may not have been powered on during that same
		# period of time. We accept this risk for now by expecting
		# a fully deployed OS on powerup.
		ENERGY_TIME=$((24*60*60))
		TIME_LEFT=$((ENERGY_TIME-UPTIME))
		if [ $TIME_LEFT -gt 0 ]; then
			echo "Energized state requires $DRIVE be powered on for at least $ENERGY_TIME"
			compute_eta $TIME_LEFT
			sleep $TIME_LEFT
		fi
	;;
	esac
}

nvme_drive_wait_for_energized_state()
{
	DRIVE=$1
	MN=$(nvme id-ctrl $DRIVE | grep "^mn ")
	echo $MN | grep -q -i intel
	if [ $? -eq 0 ]; then
		intel_nvme_wait_for_energized_state $DRIVE
	fi
}

drive_wait_for_energized_state()
{
	DRIVE=$1
	is_nvme $DRIVE
	if [ $? -eq 1 ]; then
		nvme_drive_wait_for_energized_state $DRIVE
	fi
}
