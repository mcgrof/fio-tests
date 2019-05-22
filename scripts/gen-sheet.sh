#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# (c) 2018 Luis Chamberlain <mcgrof@kernel.org>
#
# Generates csv or data files from fio output in terse mode version 3.
# There are two currently supported format outputs and two output modes.
# The supported format outputs are:
#
#   o csv: comma separated values with top column description
#   o ssv: space separated values, with no top column description, useful for
#          gnuplot
#
# The output modes depend on the range focus of the fio job that was used to
# generate the output:
#
# 1) io depth range focus
# 2) thread count range focus
#
# You specify the directory to take as input for the fio terse output version 3
# data. If no directory is specified it is assumed you want to work with the
# current directory. If no focus is specified IO depth range focus is assumed.

OUTPUT_FOCUS="io"
RESULTS_POSTFIX="res"
OUTPUT_FORMAT="csv"

usage()
{
	echo "Usage: $0 [ options ]"
	echo "[ options ]:"
	echo "-h | --help    Print this help menu"
	echo "-f | --format  <csv|data> Convert fio data files to this format"
	echo "               csv: comman separated value"
	echo "               ssv: space separated, no top column description,"
	echo "               useful for gnuplot parsing"
	echo "-i | --io      Run for the IO depth range focus (default)"
	echo "-t | --thread  Run for the thread range focus"
	echo "-d | --dir     Directory to use as fio terse version 3 input"
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
	-i|--io)
		OUTPUT_FOCUS="io"
		shift
	;;
	-t|--thread)
		OUTPUT_FOCUS="thread"
		shift
	;;
	-f|--format)
		if [ "$2" = "csv" ]; then
			OUTPUT_FORMAT="csv"
		elif [ "$2" = "ssv" ]; then
			OUTPUT_FORMAT="ssv"
		else
			echo "Unsupported format specified: $2"
			echo "Supported formats: csv, ssv"
			usage
			exit
		fi
		shift
		shift
	;;
	-d|--dir)
		DIR="$2"
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

gen_csv_header_io()
{
	echo "IO depth,Read IO throughput (KiB/s),Read IOPS,Read completion latency,Write IO throughput (KiB/s),Write IOPS,Write completion latency"
}

gen_csv_header_thread()
{
	echo "Threads,Read IO throughput (KiB/s),Read IOPS,Read completion latency,Write IO throughput (KiB/s),Write IOPS,Write completion latency"
}

get_csv_header_row()
{
	if [ "$OUTPUT_FORMAT" != "csv" ]; then
		return
	fi
	case $OUTPUT_FOCUS in
	thread)
		gen_csv_header_thread
	;;
	io)
		gen_csv_header_io
	;;
	*)
		gen_csv_header_io
	esac
}

file_get_key()
{
	FILE=$1
	KEY=$2

	echo $FILE | grep -q $KEY
	if [ $? -ne 0 ]; then
		echo
		return
	fi
	VALUE=$(echo $FILE | awk -F "$KEY" '{print $1}')
	VALUE=${VALUE##*-}

	if [ "$OUTPUT_FORMAT" == "csv" ]; then
		echo "$VALUE,"
	else
		echo "$VALUE "
	fi
}

file_get_qd()
{
	echo "$(file_get_key $1 qd)"
}

file_get_iobs()
{
	echo "$(file_get_key $1 iobs)"
}

file_get_jobs()
{
	echo "$(file_get_key $1 j)"
}

# If fio runs into errors on terse output format v3 we end up getting
# garbled spaces / new lines / returns on the output file. Fix this.
# XXX: this is a work around for an fio output issue. If you end up
# with an error on running fio the terse output will be rather mixed.
# We should fix this upstream. Also the csv or graph should check
# for the *.BAD files in case we ran into an error to highlight this
# on the csv / graph to ensure folks are aware of this. This is where
# we get these mixed garbled files.
cat_fix_blanks()
{
	cat $1 | tr -d " \t\n\r"
	echo
}

parse_args $@

DIRNAME=$(basename $DIR)
TEST_NUMBER=${DIRNAME%%-*}
TEST_NAME=${DIRNAME##${TEST_NUMBER}-}
OUTPUT="${DIRNAME}.${OUTPUT_FORMAT}"

# You may run it from within the same directory, or outside of it.
if [ -d $DIR ]; then
	cd $DIR
fi

get_csv_header_row > $OUTPUT

COUNT=0
for i in *.${RESULTS_POSTFIX} ; do
	IODEPTH="$(file_get_qd $i)"
	IOBS="$(file_get_iobs $i)"
	JOBS="$(file_get_jobs $i)"

	if [ "$OUTPUT_FOCUS" == "io" ]; then
		echo -n "$IODEPTH" >> $OUTPUT
	else
		echo -n "$JOBS" >> $OUTPUT
	fi

	if [ "$OUTPUT_FORMAT" == "csv" ]; then
		cat_fix_blanks $i >> $OUTPUT
	else
		cat_fix_blanks $i | sed -e 's|,| |g' >> $OUTPUT
	fi
	let COUNT=$COUNT+1
done
