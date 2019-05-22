#!/bin/bash
#
# Generates fio files. There are 5 modes to use this script, for each mode it
# will generate a range of files:
#
#   a) If min and max iodepth are specified it will generate an fio file
#      for each power of 2 iodepth between min-iodepth and max-iodepth
#      using the parameters passed. This is the default mode, and an iopdepth
#      range between 1 and 4096 is used.
#   b) If min and max jobs are set then it will generate an fio file
#      for each power of 2 number of jobs in between min-jobs and max-jobs
#      using the parameters passed.
#   c) If min and max iodepth batch-submit has been specified it will generate
#      an fio file for each power of 2 batch-submit using the parameters passed
#      but also for the given range of jobs, in between min and max jobs.
#   d) SNIA workload independent pre-conditioning
#   e) SNIA workload dependent pre-conditioning

source ${TOPDIR}/.config
source ${TOPDIR}/scripts/lib.sh

trap "sig_exit" SIGINT SIGTERM

TEMPLATE_FILE=""
NAME=""
BS="4k"
SIZE="4G"
SIZESET=""
NUMJOBS="1"
FILENAME="/dev/nvme0n1"
IODEPTH=""
RUNTIME="5m"
RUNTIMESET=""
STEADY_STATE=""
FIRSTJOBNAME=""
RW=""
RWMIXREAD=""
RWMIXREAD_VAL=""
RAMPTIME=""
RAMPTIME_VAL=""

SSMEANLIMITNAME=""
SSMEANLIMIT=""
SSMEANLIMITDUR=""

SSSLOPENAME=""
SSSLOPE=""
SSSLOPEDUR=""

IOPS_ROUND_LIMIT=""
IOPS_ROUND_LIMIT_HARD="soft"

# These are built-in defaults to fio, but since we are being explicit
# we always express it so we can use just one template file.
IODEPTHBATCHSUBMIT="1"
IODEPTHBATCHCOMPLETEMIN="1"
IODEPTHBATCHCOMPLETEMAX="1"

MIN_IODEPTH="1"
MAX_IODEPTH="4096"

MIN_JOBS=""
MAX_JOBS=""

MIN_IODEPTH_BATCH_SUBMIT=""
MAX_IODEPTH_BATCH_SUBMIT=""

MODE=""
PRECONDITION=""

SIZE_SET=""
IODEPTH_STEP=""
JOB_STEP=""
RANDRW_STEP=""
BS_STEP=""

FOCUS_PRECOND=""

USES_FIO_SS=""

usage()
{
	echo "Usage: $0 [ options ]"
	echo "[ options ]:"
	echo "-h | --help                   Print this help menu"
	echo "-b | --bs                     Base size"
	echo "-s | --size                   Max size to write"
	echo "-j | --jobs                   Number of threads to spawn"
	echo "-f | --filename               Filename to use"
	echo "-r | --runtime                Amount of runtime to run fio for"
	echo "--ramptime                    Amount of ramptime to use, defaults to what is on .config, but this can override"
	echo "--template-file               File to use as template"
	echo "--iodepth                     Set all files to use this iodepth"
	echo "--rw                          Operation: read/randread/write/randwrite"
	echo "--rwmixread                   Percent of read ops, the rest is write"
	echo "--iodepth_batch_submit        Amount of IOs to wait to have prior to submission"
	echo "--iodepth_batch_complete_min  How  many  pieces  of I/O to retrieve at once"
	echo "--iodepth_batch_complete_man  The maximum  pieces of I/O to retrieve at once."
	echo "--mode                        Use this mode for file generation"
	echo "Supported modes:"
	echo "             snia-wi          SNIA workload independent"
	echo "             snia-wd          SNIA workload dependent"
	echo "--precondition                Annotates that the fio files are for preconditioning"
	echo
	echo "The following define the three different modes possible, they are"
	echo "mutually exclusive:"
	echo
	echo "For a range of files to be generated using a range of jobs:"
	echo "--min-jobs                    Minimum number of jobs to use"
	echo "--max-iodepth                 Maximum number of jobs to use"
	echo
	echo "For a range of files to be generated using a range of iodepth:"
	echo "--min-iodepth                 Minimum number to use for iopdepth"
	echo "--max-iodepth                 Maximum number to use for iopdepth"
	echo
	echo "For a range of files to be generated using a range of iodepth batch submit:"
	echo "--min-iodepth-batch-submit   Mininmum batch submit to use"
	echo "--max-iodepth-batch-submit   Mininmum batch submit to use"
	echo
	echo "For SNIA workload dependent mode you will be expected to provide"
	echo "these parameters:"
	echo "--precondition               You must set this"
	echo "--uses-fio-ss                Indicates that fio's steady state mechanism is used"
	echo "--iodepth-step [32,128,etc]  Use this set for iodepth range"
	echo "--job-step [2,4,8,etc]       The set of jobs threads to use"
	echo "--randrw-step [100/0,95/5]   The set of randrw mixed profiles to use"
	echo "--bs-step [1024k,128k,512]  The set of block sizes to us"
	echo "--sizeset 100%               Use 100% of the device's size"
	echo "--ss-iops-mean-limit 20%     Set the steady state mean limit to 20%"
	echo "--ss-iops-mean-limit-dur 60s Sets the steady state mean limit duration to 60s"
	echo "--ss-iops-slope 10%          Sets the steady state slope requirement to 20%"
	echo "--ss-iops-slope-dur 60s%     Sets the steady state slope duration to 60s"
	echo "The file output for these will also include information about:"
	echo "  o iodepth"
	echo "  o jobs"
	echo "  o randrw profile used"
	echo "  o blocksize used"
}

sig_exit()
{
	echo "Caught signal, bailing..."
	exit 1
}

valid_mode_check()
{
	case "$1" in
	snia-wi)
		return 0
	;;
	snia-wd)
		return 0
	;;
	*)
		return -1
	esac
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
	--rw)
		RW="$2"
		shift
		shift
	;;
	--rwmixread)
		RWMIXREAD_VAL="$2"
		RWMIXREAD="rwmixread=$RWMIXREAD_VAL"
		shift
		shift
	;;
	--template-file)
		TEMPLATE_FILE="$2"
		shift
		shift
	;;
	--mode)
		valid_mode_check $2
		if [ $? -ne 0 ]; then
			echo "Invalid mode: $2"
			usage
			exit
		fi
		MODE="$2"
		shift
		shift
	;;
	--precondition)
		PRECONDITION="true"
		shift
	;;
	-b|--bs)
		BS="$2"
		shift
		shift
	;;
	-s|--size)
		SIZE="$2"
		shift
		shift
	;;
	-j|--jobs)
		NUMJOBS="$2"
		shift
		shift
	;;
	-f|--filename)
		FILENAME="$2"
		shift
		shift
	;;
	--iodepth)
		IODEPTH="$2"
		shift
		shift
	;;
	--min-iodepth)
		MIN_IODEPTH="$2"
		shift
		shift
	;;
	--max-iodepth)
		MAX_IODEPTH="$2"
		shift
		shift
	;;
	--min-jobs)
		MIN_JOBS="$2"
		shift
		shift
	;;
	--max-jobs)
		MAX_JOBS="$2"
		shift
		shift
	;;
	-r|--runtime)
		RUNTIME="$2"
		shift
		shift
	;;
	--ramptime)
		RAMPTIME_VAL="$2"
		RAMPTIME="ramp_time=$RAMPTIME_VAL"
		shift
		shift
	;;
	--iodepth_batch_submit)
		IODEPTHBATCHSUBMIT="$2"
		shift
		shift
	;;
	--iodepth_batch_complete_min)
		IODEPTHBATCHCOMPLETEMIN="$2"
		shift
		shift
	;;
	--iodepth_batch_complete_max)
		IODEPTHBATCHCOMPLETEMAX="$2"
		shift
		shift
	;;
	--min-iodepth-batch-submit)
		MIN_IODEPTH_BATCH_SUBMIT="$2"
		shift
		shift
	;;
	--max-iodepth-batch-submit)
		MAX_IODEPTH_BATCH_SUBMIT="$2"
		shift
		shift
	;;
	--loop)
		LOOPS="loops=$2"
		shift
		shift
	;;
	--sizeset)
		SIZESET="size=$2"
		shift
		shift
	;;
	--uses-fio-ss)
		USES_FIO_SS="true"
		shift
	;;
	--iodepth-step)
		IODEPTH_STEP="$2"
		shift
		shift
	;;
	--job-step)
		JOB_STEP="$2"
		shift
		shift
	;;
	--randrw-step)
		RANDRW_STEP="$2"
		RW="randrw"
		shift
		shift
	;;
	--bs-step)
		BS_STEP="$2"
		shift
		shift
	;;
	--ss-iops-mean-limit)
		SSMEANLIMIT="iops:$2"
		shift
		shift
	;;
	--ss-iops-mean-limit-dur)
		SSMEANLIMITDUR="$2"
		shift
		shift
	;;
	--ss-iops-slope)
		SSSLOPE="iops_slope:$2"
		shift
		shift
	;;
	--ss-iops-slope-dur)
		SSSLOPEDUR="$2"
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

seq_pow2()
{
	SEQ=""
	MIN=$1
	MAX=$2
	ITER=$MIN
	while [ $ITER -le $MAX ]; do
		SEQ="$SEQ $ITER"
		ITER=$(($ITER * 2))
	done
	echo $SEQ
}

gen_fio_dirname()
{
	printf "%04d-%diobs-%s" $DIR_NUMBER $IODEPTHBATCHSUBMIT $RW
}

gen_fio_dirname_iodepth()
{
	printf "%04d-%dqd-%s" $DIR_NUMBER $IODEPTH $RW
}

gen_fio_dirname_snia_rw()
{
	case $RW in
	write)
		printf "%s" $RW
	;;
	read)
		printf "%s" $RW
	;;
	randwrite)
		printf "%s" $RW
	;;
	randread)
		printf "%s" $RW
	;;
	randrw)
		WRITE_VAL=$((100-RWMIXREAD_VAL))
		printf "%s" ${RW}_${RWMIXREAD_VAL}_${WRITE_VAL}
	;;
	esac
}

gen_fio_dirname_snia_rw_num()
{
	RW_NAME_DIR=$(gen_fio_dirname_snia_rw)

	case $RW in
	write)
		printf "%04d-%s" $DIR_NUMBER $RW_NAME_DIR
	;;
	read)
		printf "%04d-%s" $DIR_NUMBER $RW_NAME_DIR
	;;
	randwrite)
		printf "%04d-%s" $DIR_NUMBER $RW_NAME_DIR
	;;
	randread)
		printf "%04d-%s" $DIR_NUMBER $RW_NAME_DIR
	;;
	randrw)
		printf "%04d-%s" $DIR_NUMBER $RW_NAME_DIR
	;;
	esac
}

gen_mode_batch_submit()
{
	for IODEPTHBATCHSUBMIT in $(seq_pow2 $MIN_IODEPTH_BATCH_SUBMIT $MAX_IODEPTH_BATCH_SUBMIT); do
		FILE_NUMBER=1
		DIR_NAME=$(gen_fio_dirname)
		mkdir -p $DIR_NAME
		echo "Generating fio files for $DIR_NAME ..."
		for NUMJOBS in $(seq_pow2 $MIN_JOBS $MAX_JOBS); do
			NAME="$(gen_name)"
			FIO_FILENAME=$(gen_fio_filename)
			cat_template_file_sed $TEMPLATE_FILE > $DIR_NAME/$FIO_FILENAME
			let FILE_NUMBER=$FILE_NUMBER+1
		done
		let DIR_NUMBER=$DIR_NUMBER+1
	done
}

gen_mode_iodepth_range()
{
	for IODEPTH in $(seq_pow2 $MIN_IODEPTH $MAX_IODEPTH); do
		if [ "$MIN_JOBS" = "" ]; then
			NAME="$(gen_name)"
			FIO_FILENAME=$(gen_fio_filename)
			cat_template_file_sed $TEMPLATE_FILE > $FIO_FILENAME
			let FILE_NUMBER=$FILE_NUMBER+1
		else
			FILE_NUMBER=1
			DIR_NAME=$(gen_fio_dirname_iodepth)
			mkdir -p $DIR_NAME
			echo "Generating fio files for $DIR_NAME ..."
			for NUMJOBS in $(seq_pow2 $MIN_JOBS $MAX_JOBS); do
				NAME="$(gen_name)"
				FIO_FILENAME=$(gen_fio_filename)
				cat_template_file_sed $TEMPLATE_FILE > $DIR_NAME/$FIO_FILENAME
				let FILE_NUMBER=$FILE_NUMBER+1
			done
			let DIR_NUMBER=$DIR_NUMBER+1
		fi
	done
}


gen_mode_job_range()
{
	for NUMJOBS in $(seq_pow2 $MIN_JOBS $MAX_JOBS); do
		NAME="$(gen_name)"
		FIO_FILENAME=$(gen_fio_filename)
		cat_template_file_sed $TEMPLATE_FILE > $FIO_FILENAME
		let FILE_NUMBER=$FILE_NUMBER+1
	done
}

# Without this we'd get the warning:
# file /dev/nvme0n1 exceeds 32-bit tausworthe random generator
get_random_num_gen_bs()
{
	B=$1
	BYTE_BS=0
	BS_VAL=0

	case $1 in
	*k)
		BS_VAL=${B%%k}
		BYTE_BS=$((BS_VAL*1024))
	;;
	*)
		BYTE_BS=$B
	;;
	esac

	if [ $BYTE_BS -lt 1024 ]; then
		echo "random_generator=tausworthe64"
	else
		echo ""
	fi
}

get_mode_snia_bs_step()
{
	DIR_NAME=${DIR_RW_NUM}
	FILE_NUMBER=1
	for BS in $(echo $BS_STEP | sed -e 's|,| |g'); do
		NAME=$(gen_name "SNIA workload dependent pre-conditioning for $FOCUS_PRECOND - ")
		FIO_FILENAME=$(gen_fio_filename_snia_wd)
		RANDOMNUMGEN=$(get_random_num_gen_bs $BS)
		cat_template_file_sed $TEMPLATE_FILE > $DIR_NAME/$FIO_FILENAME
		let FILE_NUMBER=$FILE_NUMBER+1
	done
}

set_vars_focus_precond()
{
	case "$1" in
	iops)
		IODEPTH=$CONFIG_SNIA_IOPS_IODEPTH
		NUMJOBS=$CONFIG_SNIA_IOPS_JOBS
	;;
	throughput)
		IODEPTH=$CONFIG_SNIA_BW_IODEPTH
		NUMJOBS=$CONFIG_SNIA_BW_JOBS
	;;
	latency)
		IODEPTH=$CONFIG_SNIA_LAT_IODEPTH
		NUMJOBS=$CONFIG_SNIA_LAT_JOBS
	;;
	*)
		echo "Invalid pre-conditioning: $1"
		exit
	esac

	SSMEANLIMITNAME="steady-state-${1}-mean-limit"
	SSSLOPENAME="steady-state-${1}-slope"

	if [ "$IODEPTH" == "" ] || [ "$NUMJOBS" == "" ]; then
		echo "Empty iodepth or number of jobs"
		exit
	fi
}

gen_mode_snia_wi()
{
	FOCUS_PRECOND=$(basename ${PWD})
	FOCUS_PRECOND=${FOCUS_PRECOND#*-}

	set_vars_focus_precond $FOCUS_PRECOND

	FILE_NUMBER=1
	NAME=$(gen_name "SNIA workload independent pre-conditioning for $FOCUS_PRECOND - ")
	FIO_FILENAME=$(gen_fio_filename_snia_id)
	SIZE=$CONFIG_SNIA_IOPS_ACTIVE_RANGE
	cat_template_file_sed $TEMPLATE_FILE > $FIO_FILENAME
}

gen_mode_snia_wd()
{
	FOCUS_PRECOND=$(basename ${PWD})
	FOCUS_PRECOND=${FOCUS_PRECOND#*-}

	set_vars_focus_precond $FOCUS_PRECOND

	# We reserve the first directory for workload independent work
	DIR_NUMBER_RANDRW=2
	for RANDRW in $(echo $RANDRW_STEP | sed -e 's|,| |g'); do
		DIR_NUMBER=$DIR_NUMBER_RANDRW
		RWMIXREAD_VAL=${RANDRW%%/*}
		DIR_RW=$(gen_fio_dirname_snia_rw)
		DIR_RW_NUM=$(gen_fio_dirname_snia_rw_num)
		mkdir -p $DIR_RW_NUM
		get_mode_snia_bs_step
		let DIR_NUMBER_RANDRW=$DIR_NUMBER_RANDRW+1
	done
}

parse_config
parse_args $@

if [ "$TEMPLATE_FILE" = "" ]; then
	echo "Template file not specified, it must be specified"
	exit
fi

if [ ! -f $TEMPLATE_FILE ]; then
	echo "File $TEMPLATE_FILE does not exist"
	exit
fi

FIRSTJOBNAME=$(gen_name_prefix_jobname)

FILE_NUMBER=1
DIR_NUMBER=1

DIR_IODEPTH=""
DIR_JOBS=""
DIR_RANDRW=""

if [ "$MODE" == "snia-wd" ]; then
	gen_mode_snia_wd
elif [ "$MODE" == "snia-wi" ]; then
	gen_mode_snia_wi
elif [ "$MIN_IODEPTH_BATCH_SUBMIT" != "" ]; then
	gen_mode_batch_submit
elif [ "$MIN_IODEPTH" != "" ]; then
	gen_mode_iodepth_range
elif [ "$MIN_JOBS" != "" ]; then
	gen_mode_job_range
fi
