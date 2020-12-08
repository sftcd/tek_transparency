#!/bin/bash

# set -x

# script to count TEKs for various places, and stash 'em

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}

TEK_DECODE="$TOP/tek_file_decode.py"


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

zarr=( $zips )
# echo to stderr 
>&2 echo "Doing ${#zarr[@]} zips, first is ${zarr[0]}" 

total_keys=0
for file in $zips
do
    2>&1 echo -e "\tDoing $file"
    rm -f export.bin export.sig content.sig content.bin
    # try unzip and decode
    timeout 120s unzip $file >/dev/null 2>&1
    if [[ $? == 0 ]]
    then
        $TEK_DECODE
        new_keys=$?
        total_keys=$((total_keys+new_keys))
    else
        echo "Unzip of $file failed or took too long"
    fi
    rm -f export.bin export.sig content.sig content.bin
    chunk_no=$((chunk_no+1))
done

END=$(whenisitagain)
2>&1 echo "Finished at $END, got $total_keys (mod 256 - thanks to bash's 1 octet return)"
