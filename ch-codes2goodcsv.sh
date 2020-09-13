#!/bin/bash

# Map the JSON variant of the Swiss codes info to CSV

# set -x

x=${DATADIR:="$HOME/data/teks/tek_transparency"}

lastrun=`ls -d $DATADIR/202* | tail -1`

CHCODES=$lastrun/ch-codes.json

cat $CHCODES | json_pp  | grep -A1 Codeact | tr '\n' ' ' | tr '\-\-' '\n' | \
    sed -e 's/", *$//' | sed -e 's/^.*t" : "//' | sed -e 's/",.* "/,/' | \
    tr '\n\n' 'xx\n' | sed -e 's/xx/\n/g' >ch-codes.csv



