#!/bin/bash
# Provisioning a single disk is rather simple, but provisioning all disks
# requires a bit more of work. Demo how to do this by allowing you to
# provision all disks specified for the specified workload criteria
# using one of the supported pre-conditioning methods.

PROVISION_CLEAN="false"
PROVISION_FORCE="false"
PROVISION_DRYRUN="false"
PROVISION_TYPE="nvme"
PROVISION_METHOD="sc"
PROVISION_WORKLOAD="random"
PROVISION_WORKDIR="provisioning"
PROVISION_MASTER="$PROVISION_WORKDIR/master"

DEFCONFIG_SEQ="defconfig-prov_sc_seq"
DEFCONFIG_RANDOM="defconfig-prov_sc_random"
DEFCONFIG="$DEFCONFIG_SEQ"

source scripts/noconfig-lib.sh

usage()
{
	echo "Usage: $0 [ options ]"
	echo "[ options ]:"
	echo "-h | --help      Print this help menu"
	echo "-c | --clean      Leave no trace behind, remove all work we generate"
	echo "-f | --force      If prior provision results are found, remove them and start fresh"
	echo "--dryrun          Don't do the actual provisioning, just do a dry run"
	echo "-t | --type       The type of storage devices to provision"
	echo "                  Supported types:"
	echo "                    nvme"
	echo "-m | --method     Use this mechanism to provision, valid methods:"
	echo "                    sc: Santa Clara method"
	echo "-w | --workload   Workload to provision. Valid workloads:"
	echo "                    seq : sequential workloads"
	echo "                    random: random workloads"
	echo "                    mixed: a mix of workloads, use even number"
	echo "                         ending devices for sequential, odd for"
	echo "                         random worloads. For instance,"
	echo "                         /dev/nvme0n1 /dev/nvme2n1 /dev/nvme4n1"
	echo "                         will end up with sequential workloads"
	echo "                         /dev/nvme1n1 /dev/nvme3n1 /dev/nvme5n1"
	echo "                         will end up with random workloads"
}

check_type()
{
	TYPE=$1

	case $TYPE in
	nvme)
		return 0
	;;
	*)
		echo -e "Unknown type: $TYPE\n"
		usage
		exit
	;;
	esac
}

check_method()
{
	METHOD=$1

	case $METHOD in
	sc)
		return 0
	;;
	*)
		echo -e "Unknown method: $METHOD\n"
		usage
		exit
	;;
	esac
}

check_workload()
{
	WORKLOAD=$1

	case $WORKLOAD in
	seq)
		DEFCONFIG="$DEFCONFIG_SEQ"
		return 0
	;;
	random)
		DEFCONFIG="$DEFCONFIG_RANDOM"
		return 0
	;;
	mixed)
		DEFCONFIG="$DEFCONFIG_SEQ"
		return 0
	;;
	*)
		echo -e "Unknown workload: $WORKLOAD\n"
		usage
		exit
	;;
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
	-c|--clean)
		PROVISION_CLEAN="true"
		shift
	;;
	-f|--force)
		PROVISION_FORCE="true"
		shift
	;;
	--dryrun)
		PROVISION_DRYRUN="false"
		shift
	;;
	-t|--type)
		PROVISION_TYPE="$2"
		shift
		shift
	;;
	-m|--method)
		PROVISION_METHOD="$2"
		shift
		shift
	;;
	-w|--workload)
		PROVISION_WORKLOAD="$2"
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

verify_params()
{
	check_type $PROVISION_TYPE
	check_method $PROVISION_METHOD
	check_workload $PROVISION_WORKLOAD
}

provision_finish()
{
	if [ "$PROVISION_CLEAN" == "true" ]; then
		rm -rf $TMP_WORKDIR
	fi
}

trap "provision_finish" EXIT

provision_dev()
{
	PROVISION_DEV=$1
	PROVISION_CONFIG=$2

	export DEV="$PROVISION_DEV"
	make $PROVISION_CONFIG
	make -j$(nproc --all)
	if [ "$PROVISION_DRYRUN" != "true" ]; then
		make run
	else
		make dryrun
	fi
}

provision_dev_copy_code()
{
	PROVISION_DEV=$1
	PROVISION_CONFIG=$2

	DEV_PROVISION_DIR="${PROVISION_WORKDIR}/${PROVISION_DEV#/dev/*}"
	cp -a $PROVISION_MASTER $DEV_PROVISION_DIR
	cd $DEV_PROVISION_DIR
	provision_dev $PROVISION_DEV $PROVISION_CONFIG | tee log
}

switch_defconfig()
{
	CONF=$1

	if [ "$CONF" == "$DEFCONFIG_SEQ" ]; then
		echo "$DEFCONFIG_RANDOM"
	elif [ "$CONF" == "$DEFCONFIG_RANDOM" ]; then
		echo "$DEFCONFIG_SEQ"
	fi
}

CHECK_USER="$(id -u)"
if [ "$CHECK_USER" -ne 0 ]; then
	echo "$0 must be run as root"
	exit 1
fi

parse_args $@
verify_params

if [ -d $PROVISION_WORKDIR ] && [ "$PROVISION_FORCE" != "true" ]; then
	echo "$PROVISION_WORKDIR directory not empty, use $0 -f if you want to remove it"
	exit 1
fi

list_nvme_devs > /dev/null
if [ $? -ne 0 ]; then
	echo "No nvme devices to provision"
	exit 1
fi

rm -rf $PROVISION_WORKDIR
mkdir -p $PROVISION_MASTER
git archive master | tar -x -C $PROVISION_MASTER

for i in $(list_nvme_devs); do
	nohup $(provision_dev_copy_code $i $DEFCONFIG) >/dev/null 2>&1 &
	if [ "$PROVISION_WORKLOAD" == "mixed" ]; then
		DEFCONFIG="$(switch_defconfig $DEFCONFIG)"
	fi
done
