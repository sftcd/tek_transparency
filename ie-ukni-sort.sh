#!/bin/bash

# produce a list of TEKs with attribution to IE or UKNI
# based on from where we first saw the value

# set -x

# the input are the set of files in the CWD named either
# ie-.zip or unki*.zip

# we use the file creation times to determine which is
# 'earlier'

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR="$HOME/code/tek_transparency/all-zips"}
OUTFILE="attribution.csv"
IEF="ie-$OUTFILE" 
UKNIF="ukni-$OUTFILE"

# defaults
IEOUT=iefirstteks
UKNIOUT=uknifirstteks

if [[ "$#" == "2" ]]
then
    IEOUT=$1
    UKNIOUT=$2
elif [[ "$#" != "0" ]]
then
    echo "Odd number of argument exiting"
    exit 1
fi

# only do the slow bits if needed

if [ -f $IEF ]
then
    iefmtime=`date -r $IEF +%s`
    now=`date +%s`
    if [ "$((now-iefmtime))" -gt "86400" ]
    then
        # make a wee backup
        mv $IEF $IEF.backup.$NOW
    fi
fi

if [ ! -f $IEF ]
then
    tmpf=`mktemp /tmp/ieunkiXXXX`
    for file in $DATADIR/ie-*.zip
    do
        # modification time
        fm=`stat -c %Y $file`
        tlist=`$TOP/tek_count.sh $file | grep period | awk -F\' '{print $2}'`
        for tek in $tlist
        do
            echo "ie,`basename $file`,$fm,$tek" >>$tmpf
        done
    done
    # sort based on time, then unique-sort based on TEK
    cat $tmpf | sort -t, -k3 | sort -u -t, -k4 >ie-$OUTFILE
    rm -f $tmpf
else
	echo "Using existing $IEF"
fi

if [ -f $UKNIF ]
then
    uknifmtime=`date -r $UKNIF +%s`
    now=`date +%s`
    if [ "$((now-uknifmtime))" -gt "86400" ]
    then
        # make a wee backup
        mv $UKNIF $UKNIF.backup.$NOW
    fi
fi

if [ ! -f $UKNIF ]
then
    tmpf=`mktemp /tmp/ieunkiXXXX`
    for file in $DATADIR/ukni-*.zip
    do
        # modification time
        fm=`stat -c %Y $file`
        tlist=`$TOP/tek_count.sh $file | grep period | awk -F\' '{print $2}'`
        for tek in $tlist
        do
            echo "ukni,`basename $file`,$fm,$tek" >>$tmpf
        done
    done
    # sort based on time, then unique-sort based on TEK
    cat $tmpf | sort -t, -k3 | sort -u -t, -k4 >ukni-$OUTFILE
    rm -f $tmpf 
else
    echo "Using existing $UKNIF"
fi

if [[ -f $IEOUT && -f $UKNIOUT ]]
then
    echo "You did that already!"
    exit 0
fi

# Do checks and produce some numeric outputs

total=0
ieonly=0
uknionly=0
both=0
shite=0
dodgy=0

tmpf=`mktemp /tmp/ieunkiXXXX`
while read line
do
    iefname=`echo $line | awk -F, '{print $2}'`
    ieftime=`echo $line | awk -F, '{print $3}'`
    ietek=`echo $line | awk -F, '{print $4}'`
    uknicnt=`grep -c $ietek $UKNIF`
    if [[ "$uknicnt" == "1" ]]
    then
        ukniline=`grep $ietek $UKNIF`
        uknifname=`echo $ukniline | awk -F, '{print $2}'`
        ukniftime=`echo $ukniline | awk -F, '{print $3}'`
        uknitek=`echo $ukniline | awk -F, '{print $4}'`
        both=$((both+1))
        if [[ "$ieftime" == "$ukniftime" ]]
        then
            shite=$((shite+1))
            echo "Shite! $shite" 
            echo -e "\t$line" 
            echo -e "\t$ukniline"
        else 
            diff=$((ieftime-ukniftime))
            if (( diff > 0 ))
            then
                echo "iefirst,$ietek,$((ieftime-ukniftime))" >>$tmpf
            else
                echo "uknifirst,$ietek,$((ukniftime-ieftime))" >>$tmpf
            fi
        fi
    elif [[ "$uknicnt" == "0" ]]
    then
        ieonly=$((ieonly+1))
        echo "ieonly,$ietek,$ieftime" >>$tmpf
    else
        echo "Dodgy $line"
        dodgy=$((dodgy+1))
    fi
done <$IEF

# produce our outputs for others to use
grep iefirst $tmpf | awk -F, '{print $2}' >$IEOUT
grep uknifirst $tmpf | awk -F, '{print $2}' >$UKNIOUT

echo "Cross-border latencies"
echo "type,sum,count,average,median,min,max"
for str in iefirst uknifirst
do
    # Calculate min,max,average timing diffs
    echo -n "$str,"
    cat $tmpf | grep $str | awk -F, '{print $3}' | sort -n | awk '
		  BEGIN {
		    c = 0;
		    sum = 0;
		  }
		  $1 ~ /^(\-)?[0-9]*(\.[0-9]*)?$/ {
		    a[c++] = $1;
		    sum += $1;
		  }
		  END {
		    ave = sum / c;
		    if( (c % 2) == 1 ) {
		      median = a[ int(c/2) ];
		    } else {
		      median = ( a[c/2] + a[c/2-1] ) / 2;
		    }
		    OFS="\t";
		    print sum","c","ave","median","a[0]","a[c-1];
		  }
		'
done
rm -f $tmpf

# Figure out total and ukni only counts, as a cross-check
total=`cat $IEF $UKNIF | awk -F, '{print $4}' | sort | uniq | wc -l`

# figure out count of UKNI only
cat $IEF | awk -F, '{print $4}' >$tmpf
uknionly=`grep -c -v -f $tmpf $UKNIF` 

echo  "total: $total, ieonly: $ieonly, uknionly: $uknionly, both: $both, same time: $shite, other weirdness: $dodgy"
