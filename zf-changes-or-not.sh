#!/bin/bash

# This is a script to help try figure out how many new
# Polish TEKs are being added after they started to add
# fakes.

for zipf in ~/data/teks/tek_transparency/all-zips/pl-*-*-*.zip; 
do 
    mtime=`stat -c %Y $zipf`
    dstr=`date +%Y%m%d-%H -d @$mtime`
    bz=`basename $zipf`; 
    echo "$bz,$dstr";  
    find ~/data/teks/tek_transparency/2020* -name $bz -exec diff -b $zipf {} \;
done
