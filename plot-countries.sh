#!/bin/bash

x=${TOP:="$HOME/code/tek_transparency"}

csvfile="country-counts.csv"

if [[ "$1" != "" ]]
then
    csvfile="$1"
fi

if [ ! -f $csvfile ]
then
    echo "Can't read $csvfile - exiting"
    exit 1
fi

countries=`cat country-counts.csv | awk -F, '{print $1}' | sort | uniq`
for c in $countries 
do 
    $TOP/plot-dailies.py -1 -i $csvfile -c $c -s 2020-07-01 -o $c.png 
done
