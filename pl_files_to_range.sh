#!/bin/bash

# count the number of new TEKs each day from Italy

# The trick here is to depend on the file dates.
TEK_COUNT="/home/stephen/code/tek_transparency/tek_count.sh"

for file in pl-*.zip
do
	fnum=`echo $file | sed -e 's/pl-//' | sed -e 's/.zip//'`
	sestring=`$TEK_COUNT $file | grep "file timestamps"`
	start_time_t=`echo $sestring | awk '{print $4}' | sed -e 's/,//'`
	start_str=`date -d @$start_time_t`
	end_time_t=`echo $sestring | awk '{print $6}'`
	end_str=`date -d @$end_time_t`
	echo "$fnum $file goes from $start_str to $end_str"
done
