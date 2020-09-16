#!/bin/bash

# compare our estimated uploads to data from service operators

# we have Swiss and German sources

# set -x

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${JHU_TOP:="$HOME/code/covid/jhu/COVID-19"}
x=${DATADIR="$HOME/code/tek_transparency"}
x=${DAILIES="$HOME/code/tek_transparency/dailies2"}
# Swiss

slist=`ls -dr $DATADIR/202*`
sinput=""
for rundir in $slist
do
    if [ -d $rundir ] 
    then
        if [ -s $rundir/ch-codes.json ]
        then
            sinput=$rundir/ch-codes.json
            break
        fi
    fi
done
if [ -s $sinput ]
then
    cinput="$DAILIES/country-counts.csv"
    if [ ! -s $cinput  ]
    then
        echo "$cinput is empty or missing - exiting"
        exit 1
    fi
    echo "Plotting Swiss ground-truth from $sinput and $cinput" 
    ctmp=`mktemp /tmp/ctmpXXXX`
    stmp=`mktemp /tmp/stmpXXXX`
    grep "ch," $cinput | awk -F, '{print $2","$3}' >$ctmp
    cdlist=`cat $sinput | json_pp  -json_opt canonical,indent | grep -A1 Codeact | \
        tr '\n' ' ' | tr '\-\-' '\n' |  \
        sed -e 's/", *$//' | sed -e 's/^.*t":"//' | sed -e 's/".*"/,/'`
    for cd in $cdlist
    do
        c=`echo $cd | awk -F, '{print $1}'`
        d=`echo $cd | awk -F, '{print $2}'`
        echo "${d:6:4}-${d:3:2}-${d:0:2},$c" >>$stmp
    done
    $TOP/plot-2bar.py -1 $ctmp -2 $stmp -o "TEK Survey" -t "Swiss Codes" -c "Switzerland" -f -i ch-ground.png $*
    convert ch-ground.png -resize 115x71 ch-ground-small.png
    rm -f $ctmp $stmp
else
    echo "$sinput is empty or missing - exitint"
    exit 2
fi

# Germany

sinput=""
for rundir in $slist
do
    if [ -d $rundir ] 
    then
        if [ -s $rundir/de-keys.csv ]
        then
            sinput=$rundir/de-keys.csv
            break
        fi
    fi
done
if [ -s $sinput ]
then
    cinput="$DAILIES/country-counts.csv"
    if [ ! -s $cinput  ]
    then
        echo "$cinput is empty or missing - exiting"
        exit 1
    fi
    echo "Plotting German ground-truth from $sinput and $cinput" 
    ctmp=`mktemp /tmp/ctmpXXXX`
    stmp=`mktemp /tmp/stmpXXXX`
    grep "de," $cinput | awk -F, '{print $2","$3}' >$ctmp
    tail -n +2 $sinput | awk -F, '{print strftime("%Y-%m-%d",$1)","$3}' >$stmp
    $TOP/plot-2bar.py -1 $ctmp -2 $stmp -o "TEK Survey" -t "German Codes" -c "Germany" -f -i de-ground.png $*
    convert de-ground.png -resize 115x71 de-ground-small.png
    rm -f $ctmp $stmp
else
    echo "$sinput is empty or missing - exitint"
    exit 2
fi
