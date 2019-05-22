#!/bin/bash

DESC=""
DUT_RUNTIME=""
RUN_ONCE="N"
FIO_FILE=""
DRY_RUN="N"
ANNOUNCE_PRECOND="N"
SHOW_TIME="N"
USE_JSON="N"
PRECOND_PRIOR="none"
PREFILL_DESC=""
GENERIC_SS_DESC=""
IS_PREFILL="N"

USES_FIO_SS="N"

# XXX: add latency fio ss support and then expand this with another 1, so we'd
# have "1,1,1" eventually.
SS_OK_RESULTS="1,1"

source ${TOPDIR}/.config
source ${TOPDIR}/scripts/lib.sh

usage()
{
	echo "Usage: $0 [ options ]"
	echo "[ options ]:"
	echo "-h | --help                   Print this help menu"
	echo "-f                            Use this fio file to run"
	echo "-n | --dryrun                 Do everything but do not run the test"
	echo "--announce-precondition       Announce pre-conditioning"
	echo "--show-time                   After running display the amount of time it took to run"
	echo "--once                        Run only once, if this test was run before, skip it"
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
	-f)
		FIO_FILE="$2"
		shift
		shift
	;;
	--once)
		RUN_ONCE="Y"
		shift
	;;
	--announce-precondition)
		ANNOUNCE_PRECOND="Y"
		shift
	;;
	--show-time)
		SHOW_TIME="Y"
		shift
	;;
	-n|--dryrun)
		DRY_RUN="Y"
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

parse_config
parse_args $@

if [ ! -f $FIO_FILE ]; then
	echo "Missing file: $FIO_FILE"
	exit 1
fi

OUTPUT="${FIO_FILE}.out"

# Only way to detect if ss is attained is using json files.
# These files will be big, so hope is to ensure they the runtime is small.
uses_fio_ss $FIO_FILE
if [ $? -eq 1 ]; then
	USE_JSON="Y"
	USES_FIO_SS="Y"
	OUTPUT="${FIO_FILE}.json"
	JSON_FILE="${FIO_FILE}.json"
	SS_RESULTS="${FIO_FILE}.ss"
fi

BAD="${FIO_FILE}.BAD"
OK="${FIO_FILE}.OK"
TIME="${FIO_FILE}.TIME"
RESULTS="${FIO_FILE}.res"

# We want to get only *one* output for now, so make it as long as the entire
# test time + 60 seconds.
INTERVAL=$((DUT_TOTAL_RUNTIME + 60))

is_snia_wi $FIO_FILE
if [ $? -eq 1 ]; then
	IS_PREFILL="Y"
fi

if [ "$RUN_ONCE" == "Y" ]; then
	if [ -f $OK ]; then
		RET=$(cat $OK)
		if [ "$IS_PREFILL" == "Y" ]; then
			echo " Prefill completed successfully earlier, skipping ..."
		fi
		exit $RET
	fi
	if [ -f $BAD ]; then
		RET=$(cat $BAD)
		if [ "$IS_PREFILL" == "Y" ]; then
			echo " Prefill failed earlier stopping."
		fi
		exit $RET
	fi
fi

if [ "$ANNOUNCE_PRECOND" == "Y" ]; then
	PREFILL_DESC=$(get_precondition_file_prefill_desc $FIO_FILE)
	if [ "$PREFILL_DESC" != "" ]; then
		IS_PREFILL="Y"
		echo -n "Preconditioning by pre-filling for $PREFILL_DESC, this will take a while ... "
	fi
	uses_fio_ss_generic $FIO_FILE
	if [ $? -eq 1 ]; then
		GENERIC_SS_DESC=$(generic_ss_desc $FIO_FILE)
		if [ "$GENERIC_SS_DESC" != "" ]; then
			echo -n "Trying to attain steady state for $GENERIC_SS_DESC ... "
		fi
	fi
fi

PARSE_ARGS="--output-format=terse --terse-version=3 --status-interval=${INTERVAL}s"
if [ "$USE_JSON" == "Y" ]; then
	PARSE_ARGS="--output-format=json+"
fi

rm -f $RESULTS $OK $BAD $SS_RESULTS $TIME

if [ "$DRY_RUN" == "Y" ]; then
	(time echo "This test never ran -- dry-run" > $OUTPUT) &> $TIME
else
	(time fio --warnings-fatal $PARSE_ARGS $FIO_FILE > $OUTPUT) &> $TIME
fi

RES="$?"
if [ $RES -ne 0 ]; then
	echo $RES > $BAD
else
	echo 0 > $OK
fi

if [ "$IS_PREFILL" == "Y" ]; then
	if [ $RES -eq 0 ]; then
		echo " OK!"
	else
		echo " FAIL"
	fi
fi

if [ "$DRY_RUN" == "Y" ] && [ "$ANNOUNCE_PRECOND" == "Y" ]; then
	echo " Attained (dryrun)!"
fi

if [ "$SHOW_TIME" == "Y" ] && [ "$USE_JSON" != "Y" ]; then
	cat $TIME
fi

if [ "$DRY_RUN" == "Y" ]; then
	echo "0,0,0,0,0,0" > $RESULTS
	exit
fi

if [ "$USE_JSON" != "Y" ]; then
	READ_BW=$(cat $OUTPUT | awk -F";" '{print $7}')
	READ_IOPS=$(cat $OUTPUT | awk -F";" '{print $8}')
	READ_CLAT_MEAN=$(cat $OUTPUT | awk -F";" '{print $16}')

	WRITE_BW=$(cat $OUTPUT | awk -F";" '{print $48}')
	WRITE_IOPS=$(cat $OUTPUT | awk -F";" '{print $49}')
	WRITE_CLAT_MEAN=$(cat $OUTPUT | awk -F";" '{print $57}')

	echo "$READ_BW,$READ_IOPS,$READ_CLAT_MEAN,$WRITE_BW,$WRITE_IOPS,$WRITE_CLAT_MEAN" > $RESULTS
else
	SS_ARGS=""
	if [ "$USES_FIO_SS" == "Y" ]; then
		SS_ARGS="--steady-state"
	fi
	scripts/json2res $SS_ARGS $JSON_FILE
	JSON_GEN_RES=$?
	if [ "$USES_FIO_SS" == "Y" ]; then
		if [ $JSON_GEN_RES -eq 0 ]; then
			if [ -f $SS_RESULTS ]; then
				grep -q "^$SS_OK_RESULTS" $SS_RESULTS
				if [ $? -eq 0 ]; then
					if [ $RES -ne 0 ]; then
						echo "Unexpected error, fio failed but steady state attained"
						exit 1
					fi
					echo " Steady state Attained!"
					if [ "$SHOW_TIME" == "Y" ]; then
						cat $TIME
					fi
				else
					echo " SS FAIL"
					if [ $RES -eq 0 ]; then
						RES=1
					fi
				fi
			else
				if [ -f $OK ]; then
					echo "Unexpected error: scripts/json2res succeeded but steady-state file:"
					echo "$SS_RESULTS"
					echo "was not generated."
				elif [ -f $BAD ]; then
					echo " fio run FAIL"
				else
					echo "Unexpected error: $OK or $BAD file does not exist"
				fi
			fi
		else
			echo "Failed"
			if [ $RES -eq 0 ]; then
				RES=1
			fi
		fi
	fi
fi

exit $RES
