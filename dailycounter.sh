#!/bin/bash

# set -x

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR="$HOME/data/teks/tek_transparency"}
x=${OUTDIR="`/bin/pwd`"}


# script to count each day's TEKs for each country/region

# Our definition of that day's TEKs is the number of TEKs
# that were first seen on that day for that country/region

# The input here is the run-directory for the run at 
# UTC midnight each day (currently, 1am Irish Summer Time)

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
    echo "  -d specifies the input data directory (default: $DATADIR)"
    echo "  -e specifies the end time, in secs since UNIX epoch (default: $END)"
    echo "  -h means print this"
    echo "  -o specifies the output directory (default: $OUTDIR)"
    echo "  -O specifies the output CSV file (default: $OUTFILE)"
    echo "  -s specifies the start time, in secs since UNIX epoch (default: $START)"
    echo "  -v means be verbose"
    exit 99
}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o c:d:e:ho:O:s:v -l countries:,dir:,end:,help,outdir:,outfile:,start:,verbose -- "$@")
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

#echo "Going to count daily TEKS from $START_STR ($START) to $END_STR ($END) in $COUNTRY_LIST"

# We'll make a CSV in each relevant directory, if one doesn't
# already exist there that's younger than all the zips in that
# place

TMPF=`mktemp $OUTDIR/dctekXXXX`
TMPF1=`mktemp $OUTDIR/dctekXXXX`

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
            #echo -e "\tSkipping $run"
            continue
        fi 
        dirtarget="$OUTDIR/$year-$month-$day"
        if [ ! -d $dirtarget ]
        then
            echo -e "\tGenerating $dirtarget"
            mkdir -p "$dirtarget"
            if [ ! -d $dirtarget ]
            then
                echo "Failed to create $dirtarget - exiting"
                exit 1
            fi
            # this is **sloooow** - but works:-)
            echo "Created $dirtarget"
            $TOP/tek_times.sh -r -d $run -o $dirtarget -c "$COUNTRY_LIST"
        fi

        # only process one run's worth per day
        break
    done

    mn=$((mn+DAYSECS))
done

# Now go back over the CSV in each directory 

mn=$START
while ((mn < END))
do
    year=`date -d @$mn +%Y`
    month=`date -d @$mn +%m`
    day=`date -d @$mn +%d`
    dirtarget="$OUTDIR/$year-$month-$day"
    if [ ! -d $dirtarget ]
    then
        # no results for anywhere that day ah well
        #echo "No sign of $dirtarget when analysing - skipping"
        mn=$((mn+DAYSECS))
        continue
    fi
    for country in $COUNTRY_LIST
    do
        if [ -f $dirtarget/$country-tek-times.csv ]
        then
            ll=`tail -1 $dirtarget/$country-tek-times.csv`
            if [[ $ll == $country,202* ]] 
            then
                alreadythere=`grep -c "$ll" $TMPF`
                if [[ "$alreadythere" == "0" ]]
                then
                    # Handle any exceptions for weird counters, we need to decode for that
                    # Moved that code to tek_times.sh
                    llc=`echo "$ll" | awk -F, '{print $1}'` 
                    llday=`echo "$ll" | awk -F, '{print $2}'` 
                    lltime_t=`date -d "$llday" +%s`
                    lltek=`echo "$ll" | awk -F, '{print $3}'` 
                    llcnt=`echo "$ll" | awk -F, '{print $4}'` 
                    #echo "Input: $ll"
                    #echo "Output: $llc,$llday,$lltek,$llcnt" 
                    echo "$llc,$llday,$lltek,$llcnt" >>$TMPF
                fi
            fi
        fi

    done
    mn=$((mn+DAYSECS))
done

# Now tidy up by adding any days with zero TEKs
mn=$START
while ((mn < END))
do
    year=`date -d @$mn +%Y`
    month=`date -d @$mn +%m`
    day=`date -d @$mn +%d`
    for country in $COUNTRY_LIST
    do
        alreadythere=`grep -c "$country,$year-$month-$day" $TMPF`
        if [[ "$alreadythere" == "0" ]]
        then
            allcases=`grep "$country,$year-$month-$day" "$dirtarget/jhu.csv" | awk -F, '{print $4}'`
            if [[ "$allcases" == "" ]]
            then
                allcases=0
            fi
            echo "$country,$year-$month-$day,0,$allcases" >>$TMPF1
        fi
    done
    mn=$((mn+DAYSECS))
done

if [[ -f $OUTDIR/$OUTFILE ]]
then
    mv $OUTDIR/$OUTFILE $OUTDIR/$OUTFILE-backed-up-at-$NOW.csv
fi

# catenate the non-zero days and zero days, then sort, reverse (tac)
# and sort removing columns with the same date, (col2) then reverse
# again to get our output
cat $TMPF $TMPF1 | sort | tac | sort -u -t, -r -k1,2 |tac > $OUTDIR/$OUTFILE
# cat $TMPF $TMPF1 | sort > $OUTDIR/$OUTFILE
rm -f $TMPF $TMPF1
