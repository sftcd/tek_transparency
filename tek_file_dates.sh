#!/bin/bash

# set -x

# list the number of TEKs for each date from one or more zips

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
# The trick here is to depend on the file dates.
TEK_COUNT="$TOP/tek_count.sh"

list=$*
tekepochs=""
tekdates=""

for file in $list
do
	tekepochs="$tekepochs `$TEK_COUNT $file 2>/dev/null | grep "^b" | awk -F\' '{print $3}' | sed -e 's/,.*//' ` "
done
for epoch in $tekepochs
do
    tekdates="$tekdates\n`date -d @$((epoch*600)) +"%Y-%m-%d"`"
done
echo -e $tekdates | sort | uniq -c
