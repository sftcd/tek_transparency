#!/bin/bash

# sort IE and UKNI TEKs apart, in an incremental manner

# set -x

x=${TOP:="$HOME/code/tek_transparency"}
x=${IEF:="new-iefirsts"}
x=${UKNIF:="new-uknifirsts"}
x=${DODGY:="new-notieuknifirsts"}
x=${CSVDIR:="`/bin/pwd`"}

tmpf=`mktemp /tmp/newsortXXXX`
tmpf1=`mktemp /tmp/newsortXXXX`
tmpf2=`mktemp /tmp/newsortXXXX`


# find modification time
if [ -f $IEF ]
then
    iemod=`stat -c %Y $IEF`
else
    iemod=0
fi
if [ -f $UKNIF ]
then
    uknimod=`stat -c %Y $UKNIF`
else
    uknimod=0
fi
early=$iemod
if (( uknimod < iemod ))
then
    early=$uknimod
fi

maxfdate=0

# build list of files newer than our outputs
iflist=$CSVDIR/202*.csv
oflist=""
ofcount=0
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
        ofcount=$((ofcount+1))
    fi
done

if [[ "$oflist" == "" ]]
then
    mstr=`date -d @$maxfdate`
    istr=`date -d @$early`
    echo "Nothing to do - exiting - newewst CSV ($mstr) older than output ($istr)"
    exit 0
fi

echo "Will search $ofcount CSVs"

# grep entire lines
grep ",ie," $oflist >$tmpf1
grep ",ukni," $oflist >>$tmpf1
sort $tmpf1 >$tmpf2
mv $tmpf2 $tmpf1

# ditch any TEKs we've already assigned - can happen if
# some manual messing with files or modification times
somdels="False"
if [ -f $IEF ]
then
    b4ie=`wc -l $tmpf1 | awk '{print $1}'`
    grep -v -f $IEF $tmpf1 >$tmpf2
    mv $tmpf2 $tmpf2
    aftrie=`wc -l $tmpf1 | awk '{print $1}'`
    somedels="True"
fi
if [ -f $UKNIF ]
then
    b4ukni=`wc -l $tmpf1 | awk '{print $1}'`
    grep -v -f $UKNIF $tmpf1 >$tmpf2
    mv $tmpf2 $tmpf2
    aftrukni=`wc -l $tmpf1 | awk '{print $1}'`
    somedels="True"
fi
if [[ "$somedels" != "False" ]]
then
    echo "Ditched some already-known TEKS:"
    echo "\tWe started with $b4ie apparently new TEKs"
    echo "\tThere were $((b4ie-aftrie)) already known in .ie out of $b4ie"
    echo "\tThere were $((b4ukni-aftrukni)) already known in .ukni out of $b4ukni"
    echo "\tWe ended with $aftrukni apparently new TEKs"
fi

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

# Now reduce size in case there're dups
cat $IEF | sort | uniq >$tmpf
mv $tmpf $IEF
cat $UKNIF | sort | uniq >$tmpf1
mv $tmpf1 $UKNIF

