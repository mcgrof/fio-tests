#!/bin/bash

# Pre-configuration library file. This means that you can include this helper
# into scripts which do not need .config generated.

is_nvme()
{
	case $1 in
	Node)
		return 0
	;;
	*--*)
		return 0
	;;
	/dev/nvme*)
		return 1
	esac
}

list_nvme_devs()
{
	NVME_DEVS=0

	which nvme 2>&1 > /dev/null
	if [ $? -ne 0 ]; then
		echo "nvme util not installed"
		return 1
	fi

	for i in $(nvme list | awk '{print $1}'); do
		is_nvme $i
		if [ $? -eq 1 ]; then
			let NVME_DEVS=$NVME_DEVS+1
			echo $i
		fi
	done

	if [ $NVME_DEVS -ne 0 ]; then
		return 0
	else
		return 1
	fi
}
