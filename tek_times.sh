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
COUNTRY_LIST="ie ukni it de ch pl dk at lv es usva ca"

declare -A COUNTRY_NAMES=(["ie"]="Ireland" \
               ["ukni"]="Northern Ireland" \
               ["it"]="Italy" \
               ["de"]="Germany" \
               ["ch"]="Switzerland" \
               ["pl"]="Poland" \
               ["at"]="Austria" \
               ["dk"]="Denmark" \
               ["lv"]="Latvia" \
               ["es"]="Spain" \
               ["usva"]="Virginia" \
               ["ca"]="Canada" )

if [[ "$#" != "0" ]]
then
    COUNTRY_LIST=$@
fi

# list of cases for all countries
# Now that we want UK regions (NI anyway) and US states, we'll change
# to using the JHU data.
do_jhu="yes"
do_who="no"
do_ecdc="no"

x=${JHU_TOP:="$HOME/code/covid/jhu/COVID-19"}
# We create this file from JHU data
JHU_WORLD_CASES="jhu.csv"

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
ECDC_WORLD_CASES="world-cases.csv"

# the (suffix of the) final outcome
TARGET="tek-times.csv"

# some temp files
T2="t2.tmp"
T3="t3.tmp"

# use a WHO file is it's fresh enough
if [[ "$do_who" == "yes" ]]
then
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
fi

if [[ "$do_ecdc" == "yes" ]]
then
    # grab a new cases file if the one we have is older than a day
    if [ -f $ECDC_WORLD_CASES ]
    then
        mtime=`date -r $ECDC_WORLD_CASES +%s`
        now=`date +%s`
        if [ "$((now-mtime))" -gt "86400" ]
        then
            echo "ECDC cases file Too old, getting a new one: $now, $mtime"
            $CURL -L $CASES_URL --output $ECDC_WORLD_CASES
        fi
    else
        $CURL -L $CASES_URL --output $ECDC_WORLD_CASES
    fi
fi

if [[ "$do_jhu" == "yes" ]]
then
    remake_jhu="no"
    # we want to extract the daily count from the cumulative totals
    if [ -f $JHU_WORLD_CASES ]
    then
        mtime=`date -r $JHU_WORLD_CASES +%s`
        now=`date +%s`
        if [ "$((now-mtime))" -gt "86400" ]
        then
            remake_jhu="yes"
        fi
    else
        remake_jhu="yes"
    fi
    if [[ "$remake_jhu" == "yes" ]]
    then
        echo "time for a new $JHU_WORLD_CASES"
        rm -f $JHU_WORLD_CASES
        (cd $JHU_TOP; git pull)
        for country in $COUNTRY_LIST
        do
            cstring=",${COUNTRY_NAMES[$country]}"
            # we'll rebuild from scratch - if that takes too long we can
            # optimise later
            # We need to work with the daily files to get the regions (ukni, usva)
            # Those have the accumulated totals, so we'll need to subtract to get
            # the daily values
            # We don't want the early CSV files as those had a different format
            tmpf=`mktemp jhuXXXX`
            tmpf1=`mktemp jhuXXXX`
            tmpf2=`mktemp jhuXXXX`
            grep "$cstring" $JHU_TOP/csse_covid_19_data/csse_covid_19_daily_reports/*.csv  | awk -F, '{print $5,$8}' >$tmpf
            cat $tmpf | grep "^202[01]-" | awk -F' ' '{print $1","$3}' >$tmpf1
            cat $tmpf1 | awk -F, '{array[$1]+=$2} END { for (i in array) {print i"," array[i]}}' | sort  >$tmpf2
            cat $tmpf2 | awk -F, 'BEGIN {last=0} {print "'$country',"$1","$2","$2-last; last=$2}' >>$JHU_WORLD_CASES
            rm -f $tmpf $tmpf1 $tmpf2 
        done
    fi
fi

for country in $COUNTRY_LIST
do
    if [ -f $country-canary ]
    then
        echo "Skipping $country"
        continue
    fi
    echo "Country,Date,TEKs,Cases" >$country-$TARGET
    # upper case variant
    ucountry=${country^^}
    echo "Doing $country"
    $TEK_COUNT $country-*.zip >$T2

    grep period $T2 | sort | uniq | awk -F\' '{print $3}' | awk -F, '{print 600*$1}' | sort -n | uniq -c | awk '{print $1","$2}' >$T3
    rm -f $T2

    cnt=''
    td=''
    for cnttm in `cat $T3`
    do 
        tm=`echo $cnttm | awk -F, '{print $2}'`
        cnt=`echo $cnttm | awk -F, '{print $1}'`
        td=`date +%Y-%m-%d -d @$tm` 
        day=`echo $td | awk -F- '{print $3}'`
        month=`echo $td | awk -F- '{print $2}'`
        year=`echo $td | awk -F- '{print $1}'`
        # month and day can have leading zeros - the tricks below
        # zap those:-)
        if [[ "$do_who" == "yes" ]]
        then
            grep ",$ucountry," $WHO_WORLD_CASES | \
                grep "^$year-$month-$day" | \
                awk -F, '{print "'$country','$td','$cnt',"$5}' >>$country-$TARGET
        elif [[ "$do_ecdc" == "yes" ]]
        then
            grep ",$ucountry," $ECDC_WORLD_CASES | \
                grep ",$((10#$day)),$((10#$month)),$year" | \
                awk -F, '{print "'$country','$td','$cnt',"$5}' >>$country-$TARGET
        elif [[ "$do_jhu" == "yes" ]]
        then
            # some dates can be missing in the JHU data for some countries/regions
            gotJHU=`grep -c "$country,$year-$month-$day" $JHU_WORLD_CASES` 
            if [[ "$gotJHU" != 0 ]]
            then
                grep "$country,$year-$month-$day" $JHU_WORLD_CASES | \
                    awk -F, '{print "'$country','$td','$cnt',"$4}' >>$country-$TARGET
            else
                    echo "$country,$td,$cnt,0" >>$country-$TARGET
            fi
        else
            echo "No idea what country count to use - exiting"
            exit 99
        fi
    done
    rm -f $T3
    # as the cases file can be 24 hours old, the TEKs can get
    # ahead of that, so we'll output an empty cases number in
    # that case, we won't see $td in $country-$TARGET yet so
    # add in a line in that case - that should only happend 
	# for the most recent day, so this can be outside the
	# loop
    if [[ "$td" != "" ]]
    then
        addedteks=`grep -c $td $country-$TARGET`
        if [[ "$addedteks" == "0" ]]
        then
        echo "$country,$td,$cnt," >>$country-$TARGET
        fi
    fi

done



