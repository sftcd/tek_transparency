#!/bin/bash

# Count unique TEKS overall -- VERY VERY slow

# set -x

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${DOCROOT:='/var/www/tact/tek-counts/'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$TOP/data"}
x=${ARCHIVE:="$DATADIR/all-zips"}
x=${DAILIES:="$DATADIR/dailies"}
x=${DAILIES2:="$DATADIR/dailies2"}

TEK_LIST="$TOP/tek_list.py"

CURL="/usr/bin/curl -s"
UNZIP="/usr/bin/unzip"

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

howmany() { echo $#; }

tmpf=`mktemp /tmp/teksXXXX`

list="$ARCHIVE/*.zip"
count=0
goodcount=0
badcount=0
num=`howmany $list`

echo "Starting processing at $NOW of $num into $tmpf"

for file in $list
do
    count=$((count+1))
	echo "Doing $count of $num which is $file"
    rm -f export.bin export.sig content.sig content.bin
    # try unzip and decode
    timeout 120s unzip $file >/dev/null 2>&1
    if [[ $? == 0 ]]
    then
        goodcount=$((goodcount+1))
        $TEK_LIST $file >>$tmpf
    else
        badcount=$((badcount+1))
        echo "Unzip of $file failed or took too long"
    fi
done

allteks=`wc -l $tmpf`

echo "result of processing $num (good: $goodcount, bad: $badcount) is $allteks"

cat $tmpf | sort | uniq >$tmpf.uni

uniteks=`wc -l $tmpf.uni`

NOW=$(whenisitagain)
echo "Finished at $NOW, de-duped result is $uniteks, non de-duped set in $tmpf"

exit 0
