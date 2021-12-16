#!/bin/bash

# set -x

# script to extract numbers from ie-stats.json files

x=${HOME:='/home/stephen'}
x=${DOCROOT:='/var/www/tact/tek-counts/'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$HOME/data/teks/tek_transparency/data"}

# find our list of files

lof="$DATADIR/202*-00*/ie-stats.json"

lastcases=0
lastup=0
iepop=4900000

echo run,ga,iepop,ins,au,up,cases,dayup,perinst,peract,expup,cpop,sf
for file in $lof
do
    dn=`dirname $file`
    run=`basename $dn`
    ga=`cat $file | json_pp | jq .generatedAt | sed -e 's/"//g'`
    au=`cat $file | json_pp | jq .activeUsers`
    up=`cat $file | json_pp | jq .uploads`
    ins=`cat $file | json_pp | jq .installs[-1][1]`
    cases=`cat $file | json_pp | jq .chart[-1][1]`
    daycases=$((cases-lastcases))
    dayup=$((up-lastup))
    lastup=$up
    lastcases=$cases
    perinst=$((100*ins/iepop))
    peract=$((100*au/iepop))
    expup=$((peract*cases/100))
    mult=100000
    cpop=$(((mult*cases)/iepop))
    hc=$(((mult*dayup)/au))
    sf=$(((100*(cpop-hc)/cpop)))
    echo $run,$ga,$iepop,$ins,$au,$up,$cases,$dayup,$perinst,$peract,$expup,$cpop,$sf
done
