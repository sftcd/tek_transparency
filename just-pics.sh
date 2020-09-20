#!/bin/bash

# set -x

# (re)generate images for survey paper, with settings more suited for
# PDF/print version

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${OUTDIR="`/bin/pwd`"}
x=${OUTFILE:='country-counts.csv'}
x=${START:=''}

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

# and finally some pictures
cdate_list=`$TOP/shortfalls.py -rn -t $OUTDIR/$OUTFILE -d $TOP/country-pops.csv | \
                awk -F, '{print $1$7}' | \
                sed -e 's/\[//' | \
                sed -e 's/]//' | \
                sed -e "s/'//g" | \
                sed -e 's/ /,/'`
for cdate in $cdate_list
do
    country=`echo $cdate | awk -F, '{print $1}'`
    enddate=`grep "^$country," $OUTDIR/$OUTFILE | awk -F, '{print $2}' | sort | tail -1`
    sdate=`echo $cdate | awk -F, '{print $2}'`
    if [[ "$START" != "" ]]
    then
        echo "Doing $country from $START to $enddate"
        $TOP/plot-dailies.py -nt -c $country -1 -i $OUTDIR/$OUTFILE -s $START -o $country-from-$START-to-$enddate.png
    elif [[ "$sdate" != "" ]]
    then
        echo "Doing $country from $sdate to $enddate"
        $TOP/plot-dailies.py -nt -c $country -1 -i $OUTDIR/$OUTFILE -s $sdate -o $country-from-$sdate-to-$enddate.png
    else
        echo "No sign of start date for $country"
    fi
done

