#!/bin/bash

# Parse out all the TEKs we have into country-specific CSVs 
# comparing the number of TEKs available per day to the 
# number of cases declared per day

# set -x

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
TEK_COUNT="$TOP/tek_count.sh"

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
T2="t2.tmp"
T3="t3.tmp"

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
    echo "Country,Date,TEKs,Cases" >$country-$TARGET
    # upper case variant
    ucountry=${country^^}
    echo "Doing $country"
    $TEK_COUNT $country-*.zip >$T2

    grep period $T2 | sort | uniq | awk -F\' '{print $3}' | awk -F, '{print 600*$1}' | sort -n | uniq -c | awk '{print $1","$2}' >$T3
    rm -f $T2

    for cnttm in `cat $T3`
    do 
        tm=`echo $cnttm | awk -F, '{print $2}'`
        cnt=`echo $cnttm | awk -F, '{print $1}'`
        td=`date +%Y-%m-%d -d @$tm` 
        day=`echo $td | awk -F- '{print $3}'`
        month=`echo $td | awk -F- '{print $2}'`
        year=`echo $td | awk -F- '{print $1}'`
        # month and day can have leading zeros - the trick below
        # zaps those:-)
        if [[ "$do_who" == "yes" ]]
        then
            grep ",$ucountry," $WHO_WORLD_CASES | \
                grep "^$year-$month-$day" | \
                awk -F, '{print "'$country','$td','$cnt',"$5}' >>$country-$TARGET
        else
            grep ",$ucountry," $WORLD_CASES | \
                grep ",$((10#$day)),$((10#$month)),$year" | \
                awk -F, '{print "'$country','$td','$cnt',"$5}' >>$country-$TARGET
        fi
    done
    rm -f $T3

done



