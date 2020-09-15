#!/bin/bash

# sort IE and UKNI TEKs apart, in an incremental manner

# set -x

x=${TOP:="$HOME/code/tek_transparency"}
x=${IEF:="new-iefirsts"}
x=${UKNIF:="new-uknifirsts"}
x=${DODGY:="new-notieuknifirsts"}

tmpf=`mktemp /tmp/newsortXXXX`
tmpf1=`mktemp /tmp/newsortXXXX`


# find modification time
iemod=`stat -c %Y $IEF`
uknimod=`stat -c %Y $UKNIF`
early=$iemod
if (( uknimod < iemod ))
then
    early=$uknimod
fi

maxfdate=0

# build list of files newer than our outputs
iflist=202*.csv
oflist=""
for f in $iflist
do
    fdate=`stat -c %Y $f`
    if (( fdate > maxfdate ))
    then
        maxfdate=$fdate
    fi
    if (( fdate >= early ))
    then
        oflist="$oflist $f"
    fi
done

if [[ "$oflist" == "" ]]
then
    mstr=`date -d @$maxfdate`
    istr=`date -d @$early`
    echo "Nothing to do - exiting - newewst CSV ($mstr) older than output ($istr)"
    exit 0
fi

# grep entire lines
grep ",ie," $oflist >$tmpf1
grep ",ukni," $oflist >>$tmpf1
sort $tmpf1
# grep tek values
cat $tmpf1 | awk -F, '{print $9}' | sort | uniq >$tmpf

iecnt=`wc -l $tmpf | awk '{print $1}'`

echo "Found $iecnt .ie TEKS"

# rm -f new-iefirsts new-uknifirsts new-notieuknifirsts

for tek in `cat $tmpf`
do
    firstline=`grep $tek $tmpf1 | sort | head -1`
    first=`echo $firstline | awk -F, '{print $2}'`
    if [[ "$first" == "ie" ]]
    then
        echo "$firstline" | awk -F, '{print $9}' >>$IEF
    elif [[ "$first" == "ukni" ]]
    then
        echo "$firstline" | awk -F, '{print $9}' >>$UKNIF
    else
        echo "$firstline" | awk -F, '{print $9}' >>$DODGY
        echo "We have a dodgy one!"
    fi
done

rm -f $tmpf $tmpf1

