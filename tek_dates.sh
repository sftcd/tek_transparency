#!/bin/bash

# Small script to parse out the number of TEKs of each
# epoch in a set of country-zips in the current dir.
# Mostly for manual use:-)

country="ch"

if [[ "$1" != "" ]]
then
    country=$1
fi

for file in $country-*.zip
do
    bf=`basename $file .zip`
    rm -f export.bin export.sig 
    unzip $file >/dev/null
    $HOME/code/tek_transparency/tek_file_decode.py >$bf.out
    tcount=`cat $bf.out | grep period | wc -l` 
    epochs=`cat $bf.out | grep period | awk -F\' '{print $3}' | sed -e 's/,.*$//' | sort | uniq -c | awk '{print $1","$2}'`
    for epoch in $epochs
    do
        ecnt=`echo $epoch | awk -F, '{print $1}'`
        eval=`echo $epoch | awk -F, '{print $2}'`
        dstr=`date -d @$((eval*600))`
        echo "$bf has $ecnt at $dstr"
    done
done
