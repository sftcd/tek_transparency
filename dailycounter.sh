#!/bin/bash

# set -x

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR="$HOME/data/teks/tek_transparency"}
x=${OUTDIR="."}


# script to count each day's TEKs for each country/region

# Our definition of that day's TEKs is the number of TEKs
# that were first seen on that day for that country/region

# The input here is the run-directory for the run at 
# UTC midnight each day (currently, 1am Irish Summer Time)

# we generate a CSV for all the zips seen in each run and
# count those with the epoch matching the day before for
# each of the countries/regions

# there are some special cases, with dates associated:
# - Switzerland added 10 fakes until (approx) July 19th
#   runs (so with epoch up to 17th)
chstoppedfakes=`date -d "2020-07-19" +%s`
# - Germany were posting 10 TEKs for each real one until
#   July 2nd, at which point they switched to posting 5
#   TEKs for each real one (we offset that by 2 days
#   in the run-dates)
de10xtill=`date -d "2020-07-04" +%s`
# - since July 7th Ireland and UKNI share TEKS so we just
#   do Ireland here, another script will separate those 
#   based on firstseen times if/as possible
# - Austria were posting 1000's of fake TEKs until about
#   August 11th, not sure if we can make much sense of
#   numbers before then, just TBC
#   

# countries to do by default, or just one if given on command line
COUNTRY_LIST="ie ukni it de ch pl dk at lv es usva ca"

# default values for parameters
verbose="no"
OUTFILE="country-counts.csv"
START=`date +%s -d 2020-06-01T00:00:00Z`
END=`date +%s`

function usage()
{
    echo "$0 [-chiov] - test HPKE test vectors"
    echo "  -c [country-list] specifies which countries to process (defailt: all)"
    echo "      provide the country list as a space separatead lsit of 2-letter codes"
    echo "      e.g. '-c \"$COUNTRY_LIST\"'"
    echo "  -e specifies the end time, in secs since UNIX epoch (default: $END)"
    echo "  -h means print this"
    echo "  -i specifies the input data directory (default: $DATADIR)"
    echo "  -o specifies the output directory (default: $OUTDIR)"
    echo "  -O specifies the output CSV file (default: $OUTFILE)"
    echo "  -s specifies the start time, in secs since UNIX epoch (default: $START)"
    echo "  -v means be verbose"
    exit 99
}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o c:d:ho:O:v -l countries:,dir:,help,outdir:,outfile:,verbose -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi
#echo "|$options|"
eval set -- "$options"
while [ $# -gt 0 ]
do
    case "$1" in
        -c|--countries) COUNTRY_LIST=$2; shift;;
        -d|--dir) DATADIR=$2; shift;;
        -e|--end) END=$2; shift;;
        -h|--help) usage;;
        -o|--outdir) OUTDIR=$2; shift;;
        -O|--outfile) OUTFILE=$2; shift;;
        -s|--start) START=$2; shift;;
        -v|--verbose) verbose="yes" ;;
        (--) shift; break;;
        (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
        (*)  break;;
    esac
    shift
done

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

START_STR=`date -d @$START`
END_STR=`date -d @$END`
DAYSECS=$((60*60*24))

HOURS="48"

echo "Going to count daily TEKS from $START_STR ($START) to $END_STR ($END) in $COUNTRY_LIST"

# We'll make a CSV in each relevant directory, if one doesn't
# already exist there that's younger than all the zips in that
# place

if [[ -f $OUTDIR/$OUTFILE ]]
then
    mv $OUTDIR/$OUTFILE $OUTDIR/$OUTFILE-backed-up-at-$NOW.csv
fi

mn=$START
while ((mn < END))
do
    year=`date -d @$mn +%Y`
    month=`date -d @$mn +%m`
    day=`date -d @$mn +%d`
    # let's find the best run for that day - recently it should
    # be in "$DATADIR/$year$month$day-000001"
    # but, some could be missing and I used only do 6 hourly
    # runs early on, so we'll take the earliest run we can find
    # for that day - I hope that doesn't mean we miss any TEKS
    runlist4day="$DATADIR/$year$month$day-*"
    for run in $runlist4day
    do
        if [[ ! -d $run ]]
        then
            echo -e "\tSkipping $run"
            continue
        fi 
        csvtarget="earliest-$year$month$day.csv"
        if [ ! -f $OUTDIR/$csvtarget ]
        then
            # skip it - we've done it before
            echo -e "\tdGenerating $csvtarget for $run"
            $TOP/teks2csv.py -i $run -o $OUTDIR/$csvtarget
        fi

        # the start of the most recent epoch is two days
        # before
        epoch=$(((mn-2*DAYSECS)/600))
        # count the TEKs from here for the most recent epoch
        for country in $COUNTRY_LIST
        do
            if [[ "$country" == "de" ]]
            then
                # one day less
                epoch=$(((mn-3*DAYSECS)/600))
            fi
            #dtot=`grep ",$country," $OUTDIR/$csvtarget | grep -c ",$epoch,"`
            dtot=`grep ",$country," $OUTDIR/$csvtarget | \
                grep ",$epoch," | \
                awk -F, '{print $9}' | \
                sort | uniq | wc -l | awk '{print $1}'`
            #echo -e "\tDoing $country: We have $dtot TEKS for $epoch on $year-$month-$day"
            # Exception processing:
            if [[ "$country" == "ch" && $dtot -gt 10 && $mn -lt $chstoppedfakes ]]
            then
                dtot=$((dtot-10))
            fi
            if [[ "$country" == "de" && $mn -lt $de10xtill ]]
            then
                tt=$dtot
                dtot=$((dtot/10))
                #echo "Mapped $tt to $dtot for $country on $year-$month-$day"
            elif [[ "$country" == "de" && $mn -ge $de10xtill ]]
            then
                tt=$dtot
                dtot=$((dtot/5))
                #echo "Mapped $tt to $dtot for $country on $year-$month-$day"
            fi
            echo "$year-$month-$day,$country,$dtot,$epoch" >>$OUTFILE
        done

        # only process one run's worth per day
        break
    done
    mn=$((mn+DAYSECS))
done

