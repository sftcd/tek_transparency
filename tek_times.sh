#!/bin/bash

# Parse out all the TEKs we have into country-specific CSVs 
# comparing the number of TEKs available per day to the 
# number of cases declared per day

# set -x

# script we use
TEK_COUNT="/home/stephen/code/tek_transparency/tek_count.sh"
CURL="/usr/bin/curl -s"

# countries to do by default, or just one if given on command line
COUNTRY_LIST="ie it de ch pl dk at lv es"

if [[ "$#" != "0" ]]
then
    COUNTRY_LIST=$@
fi

# list of cases for all countries

# You can get the WHO file via some JS crap at https://covid19.who.int/
# If that exists, and is <24 hours old, we prefer it. 
# If not, we have a backup, but are not as confident in the numbers or 
# source. 
#
# Illustration of the issue: our "backup" resource added 300+ to
# Italy on June 19th, but then (I guess) corrected something via
# counting -148 on June 20. Not sure if the WHO did the same or
# not but presumably WHO are more authoritative.
# The WHO direct data:
#   2020-06-19T00:00:00Z,IT,Italy,EURO,183,238011,66,34514
#   2020-06-20T00:00:00Z,IT,Italy,EURO,0,238011,47,34561
# Our alternate: 
#   20/06/2020,20,6,2020,-148,47,Italy,IT,ITA,60359546,Europe
#   19/06/2020,19,6,2020,331,66,Italy,IT,ITA,60359546,Europe

# Anyway, if we have a file called this that's <24 hours old
# we'll use it...
WHO_WORLD_CASES="WHO-COVID-19-global-data.csv"

# If not, we'll grab one that kinda works via curl 
CASES_URL="https://opendata.ecdc.europa.eu/covid19/casedistribution/csv"
# local copy - refreshed if > 1 day old
WORLD_CASES="world-cases.csv"

# the (suffix of the) final outcome
TARGET="tek-times.csv"

# some temp files
T1="t1.tmp"
T2="t2.tmp"
T3="t3.tmp"
T4="t4.tmp"
T5="t5.tmp"

rm -f $TARGET $T1

do_who="no"
# use a WHO file is it's fresh enough
if [ -f $WHO_WORLD_CASES ]
then
    mtime=`date -r $WHO_WORLD_CASES +%s`
    now=`date +%s`
    if [ "$((now-mtime))" -le "86400" ]
    then
        do_who="yes"
        echo "Using who.int data this time."
    fi
fi

if [[ "$do_who" == "no" ]]
then
    # grab a new cases file if the one we have is older than a day
    if [ -f $WORLD_CASES ]
    then
        mtime=`date -r $WORLD_CASES +%s`
        now=`date +%s`
        if [ "$((now-mtime))" -gt "86400" ]
        then
            echo "ECDC cases file Too old, getting a new one: $now, $mtime"
            $CURL -L $CASES_URL --output $WORLD_CASES
        fi
    else
        $CURL -L $CASES_URL --output $WORLD_CASES
    fi
fi
    
for country in $COUNTRY_LIST
do
    # upper case variant
    ucountry=${country^^}
    echo "Doing $country"
    $TEK_COUNT $country-*.zip >$T2

    grep period $T2 | sort | uniq | awk -F\' '{print $3}' | awk -F, '{print 600*$1}' | sort -n >$T3
    rm -f $T2

    rm -f $T1 $country-$WORLD_CASES
    for tm in `cat $T3`
    do 
        td=`date +%Y-%m-%d -d @$tm` 
        echo $td >>$T1  
        day=`echo $td | awk -F- '{print $3}'`
        month=`echo $td | awk -F- '{print $2}'`
        year=`echo $td | awk -F- '{print $1}'`
        # month and day can have leading zeros - the trick below
        # zaps those:-)
        if [[ "$do_who" == "yes" ]]
        then
            grep ",$ucountry," $WHO_WORLD_CASES | \
                grep "^$year-$month-$day" | \
                awk -F, '{print "'$country','$td',"$5}' >>$country-$T4
        else
            grep ",$ucountry," $WORLD_CASES | \
                grep ",$((10#$day)),$((10#$month)),$year" | \
                awk -F, '{print "'$country','$td',"$5}' >>$country-$T4
        fi
    done

    rm -f $T3 $country-$T5
    if [ -f $T1 ]
    then
        cat $T1 | uniq -c | awk '{print "'$country',"$2","$1}' >>$country-$T5
		rm -f $T1
    else
        echo "No dates for $country sorry"
    fi
done

rm -f $country-$TARGET
for country in $COUNTRY_LIST
do
    # get rid of dupes
    uniq $country-$T4 >$country-$WORLD_CASES
    # lastly do a join
	echo "Country,Date,TEKs,Cases" >$country-$TARGET
    paste -d, $country-$T5 $country-$WORLD_CASES | awk -F, '{print $1","$2","$3","$6}' >>$country-$TARGET
    # clean up
    rm -f $country-$T4 $country-$T5 $country-$WORLD_CASES
done


