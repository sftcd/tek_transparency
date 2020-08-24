#!/bin/bash

# set -x

# This is incomplete - will come back to it...

# script to count each day's TEKs for each country/region

# Our definition of that day's TEKs is the number of TEKs
# that were first seen on that day for that country/region

# We also note the hourly distribution of first seen TEKs
# for each day and country/region

# The input here is a CSV produced by firstseen-v-epoch.py

# The CSV columns are:
#    country/tek,country,first-seen-time,epoch,hours-between
# e.g.:
#    ch/4423cbb060f5e1805a2d2c09079a6098,ch,1593644956.065555,1591660800,551
# The country is included in the first column as ie and ukni
# share teks so that gets us unique entries

# countries to do by default, or just one if given on command line
COUNTRY_LIST="ie ukni it de ch pl dk at lv es usva ca"

function usage()
{
    echo "$0 [-chiov] - test HPKE test vectors"
    echo "  -c [country-list] specifies which countries to process (defailt: all)"
    echo "      provide the country list as a space separatead lsit of 2-letter codes"
    echo "      e.g. '-c \"$COUNTRY_LIST\"'"
    echo "  -e specifies the end time, in secs since UNIX epoch (default: now)"
    echo "  -h means print this"
    echo "  -i specifies the input file (defailt: teks.csv)"
    echo "  -o specifies the output file (format: TBD)"
    echo "  -s specifies the start time, in secs since UNIX epoch (default: 20200601-000000Z)"
    echo "  -v means be verbose"
    exit 99
}
# default values for parameters
verbose="no"
INFILE="teks.csv"
START=`date +%s -d 2020-06-01T00:00:00Z`
END=`date +%s`

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o c:hi:o:v -l countries:,help,input:,output:,verbose -- "$@")
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
        -e|--end) END=$2; shift;;
        -h|--help) usage;;
        -i|--input) INFILE=$2; shift;;
        -o|--output) OUTFILE=$2; shift;;
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

HOURS="48"

echo "Going to count daily TEKS from $START_STR ($START) to $END_STR ($END) in $COUNTRY_LIST"

for country in $COUNTRY_LIST
do
    tmpf=`mktemp /tmp/dctekXXXX`
    grep ",$country," $INFILE >$tmpf
    ctot=`wc -l $tmpf | awk '{print $1}'`
    cat $tmpf | awk -F, ' $5 < '$HOURS' ' >$tmpf.1
    dtot=`wc -l $tmpf.1 | awk '{print $1}'`
    echo "Doing $country: We have $ctot TEKS of which $dtot were seen < $HOURS hours after epoch"
    # clear up
    rm -f $tmpf $tmpf.1
done
