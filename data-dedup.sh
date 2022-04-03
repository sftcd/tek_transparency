#!/bin/bash

# Where a zip file is present in allzips and in the hourly
# data dir, then replace the latter with a link to the former
# but only if the files are identical

SRCDIR=$HOME/code/tek_transparency/
DATADIR=$SRCDIR/data
ARCHDIR=$SRCDIR/data/all-zips

# just do 2020 to start - as I have a 2nd backup of those
for hdir in $DATADIR/2020*
do
    bsize=`du -sh $hdir`
    echo "De-duping $hdir - started at $bsize"
    for zipf in $hdir/*.zip
    do
        if [ ! -L $zipf ] 
        then
            basezipf=`basename $zipf`
            if [ -f $ARCHDIR/$basezipf ]
            then
                cmp -s $zipf $ARCHDIR/$basezipf
                cres=`echo $?`
                if [[ "$cres" == "0" ]]
                then
                    echo "$zipf and $ARCHDIR/$basezipf are the same"
                    rm -f $zipf
                    ln -s $ARCHDIR/$basezipf $zipf
                else
                    echo "$zipf and $ARCHDIR/$basezipf differ"
                fi
            else
                echo "No sign of $ARCHDIR/$basezipf"
            fi
        else
            echo "$zipf is a link already"
        fi
    done
    asize=`du -sh $hdir`
    echo "De-duping $hdir - started at $bsize ended at $asize"
done


