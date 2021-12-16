#!/bin/bash

# set -x

# See how appearance of new TEKs is distributed, by hour

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$HOME/code/tek_transparency/data"}
x=${DAILIES:="$DATADIR/dailies4"}

TEK_DECODE="$TOP/tek_file_decode.py"
TEK_TIMES="$TOP/tek_times.sh"
TEK_REPORT="$TOP/tek_report.sh"
DE_CFG_DECODE="$TOP/de_tek_cfg_decode.py"

CURL="/usr/bin/curl -s"
UNZIP="/usr/bin/unzip"

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

# The input here is the set of CSVs produced by dailycounter2.sh
# which have one line per TEK per country and one file per run

# The CSV columns are:
#    country/tek,country,first-seen-time,epoch,hours-between
# e.g.:
#    ch/4423cbb060f5e1805a2d2c09079a6098,ch,1593644956.065555,1591660800,551
# The country is included in the first column as ie and ukni
# share teks so that gets us unique entries

# countries to do by default, or just one if given on command line
. $TOP/country_list.sh

function usage()
{
    echo "$0 [-chiov] - test HPKE test vectors"
    echo "  -c [country-list] specifies which countries to process (defailt: all)"
    echo "      provide the country list as a space separatead lsit of 2-letter codes"
    echo "      e.g. '-c \"$COUNTRY_LIST\"'"
    echo "  -g provides a file glob (default: $GLOB)"
    echo "  -h means print this"
    echo "  -i specifies the input directory file (default: $DAILIES)"
    echo "  -o specifies the output file"
    echo "  -v means be verbose"
    exit 99
}
# default values for parameters
verbose="no"
INDIR="$DAILIES"
GLOB="202?????-??????.csv"

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o c:g:hi:o:v -l countries:,glob:,help,input:,output:,verbose -- "$@")
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
        -h|--help) usage;;
        -i|--input) INDIR=$2; shift;;
        -o|--output) OUTFILE=$2; shift;;
        -g|--glob) GLOB=$2; shift;;
        -v|--verbose) verbose="yes" ;;
        (--) shift; break;;
        (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
        (*)  break;;
    esac
    shift
done

declare -A hours

for country in $COUNTRY_LIST
do
    echo "Doing $country"
    occnt=0
    for hour in {00..23}
    do
        hours[$hour]=0
    done
    for csv in $INDIR/$GLOB
    do
        ccnt=`grep -c ",$country," $csv`
        newteks=$((ccnt-occnt))
        occnt=$ccnt
        tstr=`basename $csv .csv`
        hour=${tstr:9:2}
        oldtot=${hours[$hour]}
        if [[ "$newteks" != "0" ]]
        then
            hours[$hour]=$((oldtot+1))
        fi
        #hours[$hour]=$((oldtot+newteks))
        #echo "$country,$tstr,$newteks"
    done
    for hour in {00..23}
    do
        echo "$country,$hour,fake,${hours[$hour]}"
    done
done

