#!/bin/bash
#
# Generates pre-conditioning files using the .config as source.

if [ ! -f $TOPDIR/.config ]; then
	echo "Run make menuconfig first"
	exit
fi

source ${TOPDIR}/.config
source ${TOPDIR}/scripts/lib.sh

trap "sig_exit" SIGINT SIGTERM

TEMPLATE_FILE=""
NAME=""
BS=""
SIZE="100%"
SIZESET=""
RUNTIMESET=""
NUMJOBS=""
FILENAME=""
IODEPTH=""
FIRSTJOBNAME=""
RW=""
LOOPS=""

# Even though we don't use these we define these so we can share the
# same cat_template_file_sed() between general fio file generation and
# for fio pre-conditioningfile parsing.
RWMIXREAD=""
RAMPTIME=""
IODEPTHBATCHSUBMIT=""
IODEPTHBATCHCOMPLETEMIN=""
IODEPTHBATCHCOMPLETEMAX=""

usage()
{
	echo "Usage: $0 [ options ]"
	echo "[ options ]:"
	echo "-h | --help                   Print this help menu"
	echo "-f | --filename               Filename to use"
	echo "-j | --jobs                   Number of threads to spawn"
	echo "--template-file               File to use as template"
	echo "--iodepth                     Set all files to use this iodepth"
	echo "--rw                          Operation: randread/randwrite"
}

sig_exit()
{
	echo "Caught signal, bailing..."
	exit 1
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
	--template-file)
		TEMPLATE_FILE="$2"
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
	-j|--jobs)
		NUMJOBS="$2"
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

parse_precondition_prefill()
{
	DIR_NAME="pre-conditioning"
	SOURCE_DIR="${TOPDIR}/templates/pre-condition/prefill"
	WI_DIR=${TOPDIR}/$DIR_NAME/0001-workload-independent

	TEMPLATE_SEQ_PREFILL="$SOURCE_DIR/${PRECONDITION_SEQ_FILE}.in"
	TEMPLATE_RAND_PREFILL="$SOURCE_DIR/${PRECONDITION_RANDOM_FILE}.in"

	SIZE="$CONFIG_DUT_IOSIZE"
	echo "Generating fio files for generic pre-conditioning prefill (workload independent) ..."

	mkdir -p $WI_DIR

	NAME="Sequential pre-fill pre-condition"
	FIRSTJOBNAME="sequential-pre-condition"
	cat_template_file_sed $TEMPLATE_SEQ_PREFILL  > ${WI_DIR}/$PRECONDITION_SEQ_FILE
	NAME="Random pre-fill pre-condition"
	FIRSTJOBNAME="random-pre-condition"
	cat_template_file_sed $TEMPLATE_RAND_PREFILL > ${WI_DIR}/$PRECONDITION_RANDOM_FILE
}

parse_precondition_snia_generic()
{
	TARGET_DIR=$(get_precond_snia_generic_dir)
	ln -sf ../$TARGET_DIR .
}

parse_precondition_steady_state()
{
	DIR_NAME="pre-conditioning"
	SOURCE_DIR="${TOPDIR}/templates/pre-condition/steady-state"
	WD_DIR=${TOPDIR}/$DIR_NAME/0002-workload-dependent

	TEMPLATE_SS="$SOURCE_DIR/${SS_PRECONDITION_TEMPLATE_FILE}.in"

	echo "Generating fio files for generic pre-conditioning steady state (workload dependent) ..."

	mkdir -p $WD_DIR

	unset LOOPS

	BASE_FILE_NUM=0

	if [ "$CONFIG_PRECONDITION_FIO_STEADY_STATE_IOPS" == "y" ]; then
		let BASE_FILE_NUM=$BASE_FILE_NUM+1
		NAME="Workload dependent steady state iops sequential pre-conditioning"
		RW="write"
		RUNTIME=$CONFIG_IOPS_WD_SS_MEAN_LIMIT_DUR

		SSMEANLIMITNAME="steady-state-mean-iops"
		SSMEANLIMIT="iops:${CONFIG_IOPS_WD_SS_MEAN_LIMIT}"
		SSMEANLIMITDUR=$CONFIG_IOPS_WD_SS_MEAN_LIMIT_DUR

		SSSLOPENAME="steady-state-slope-iops"
		SSSLOPE="iops_slope:$CONFIG_IOPS_WD_SS_SLOPE"
		SSSLOPEDUR=$CONFIG_IOPS_WD_SS_SLOPE_DUR

		echo "     Generating iops steady state files ..."

		SS_TARGET_FILE=$(gen_fio_filename_ss_generic $BASE_FILE_NUM $PRECOND_SEQ iops)
		CREATE_DIR=$(dirname $SS_TARGET_FILE)
		mkdir -p $CREATE_DIR
		cat_template_file_sed $TEMPLATE_SS > $SS_TARGET_FILE

		NAME="Workload dependent steady state iops random pre-conditioning"
		RW="randwrite"
		SS_TARGET_FILE=$(gen_fio_filename_ss_generic $BASE_FILE_NUM $PRECOND_RAND iops)
		CREATE_DIR=$(dirname $SS_TARGET_FILE)
		mkdir -p $CREATE_DIR
		cat_template_file_sed $TEMPLATE_SS > $SS_TARGET_FILE
	fi

	if [ "$CONFIG_PRECONDITION_FIO_STEADY_STATE_BW" == "y" ]; then
		let BASE_FILE_NUM=$BASE_FILE_NUM+1
		NAME="Workload dependent steady state bw sequential pre-conditioning"
		RW="write"
		RUNTIME=$CONFIG_BW_WD_SS_MEAN_LIMIT_DUR

		SSMEANLIMITNAME="steady-state-mean-bw"
		SSMEANLIMIT="bw:${CONFIG_BW_WD_SS_MEAN_LIMIT}"
		SSMEANLIMITDUR=$CONFIG_BW_WD_SS_MEAN_LIMIT_DUR

		SSSLOPENAME="steady-state-slope-bw"
		SSSLOPE="bw_slope:$CONFIG_BW_WD_SS_SLOPE"
		SSSLOPEDUR=$CONFIG_BW_WD_SS_SLOPE_DUR

		echo "     Generating throughput steady state files ..."
		SS_TARGET_FILE=$(gen_fio_filename_ss_generic $BASE_FILE_NUM $PRECOND_SEQ bw)
		CREATE_DIR=$(dirname $SS_TARGET_FILE)
		mkdir -p $CREATE_DIR
		cat_template_file_sed $TEMPLATE_SS > $SS_TARGET_FILE

		RW="randwrite"
		NAME="Workload dependent steady state bw random pre-conditioning"
		SS_TARGET_FILE=$(gen_fio_filename_ss_generic $BASE_FILE_NUM $PRECOND_RAND bw)
		CREATE_DIR=$(dirname $SS_TARGET_FILE)
		mkdir -p $CREATE_DIR
		cat_template_file_sed $TEMPLATE_SS > $SS_TARGET_FILE
	fi
}

parse_config_generic_precondition()
{
	FILENAME=$CONFIG_DUT_FILENAME
	BS=$CONFIG_PRECONDITION_BLOCKSIZE
	IODEPTH=$CONFIG_PRECONDITION_IODEPTH
	NUMJOBS=$CONFIG_PRECONDITION_NUMJOBS
	LOOPS="loops=$CONFIG_PRECONDITION_PREFILL_LOOP"
}

parse_config
parse_args $@

if [ "$CONFIG_PRECONDITIONING" != "y" ]; then
	exit
fi

if [ "$CONFIG_PRECONDITION_GENERIC_SC" == "y" ]; then
	parse_config_generic_precondition
	parse_precondition_prefill
	if [ "$CONFIG_PRECONDITION_FIO_STEADY_STATE" == "y" ]; then
		parse_precondition_steady_state
	fi
else
	parse_precondition_snia_generic
fi
