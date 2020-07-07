#!/bin/bash

# set -x

# script to count TEKs for various places, and stash 'em

TEK_DECODE=/home/stephen/code/tek_transparency/tek_file_decode.py

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)


# pass on zip file names, if given some, or go with all
zips="*.zip"
if [[ "$#" != "0" ]]
then
	zips=$@
fi 

total_keys=0
for file in $zips
do
    # try unzip and decode
    unzip $file >/dev/null 2>&1
    if [[ $? == 0 ]]
    then
        $TEK_DECODE
        new_keys=$?
        total_keys=$((total_keys+new_keys))
    fi
    rm -f export.bin export.sig
    chunk_no=$((chunk_no+1))
done

END=$(whenisitagain)
echo "Finished at $END, got $total_keys (mod 256 - thanks to bash's 1 octet return)"
