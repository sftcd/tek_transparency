#!/bin/bash

# count the number of new TEKs each day from Italy

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
# The trick here is to depend on the file dates.
TEK_COUNT="$TOP/tek_count.sh"

for file in it-*.zip
do
	fnum=`echo $file | sed -e 's/it-//' | sed -e 's/.zip//'`
	sestring=`$TEK_COUNT $file | grep "file timestamps"`
	start_time_t=`echo $sestring | awk '{print $4}' | sed -e 's/,//'`
	start_str=`date -d @$start_time_t`
	end_time_t=`echo $sestring | awk '{print $6}'`
	end_str=`date -d @$end_time_t`
	echo "$fnum $file goes from $start_str to $end_str"
done
