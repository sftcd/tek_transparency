#!/bin/bash

# Make a CSV with start/end dates for services 
# based on the zip files seen

# set -x

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${OUTCSVFILE="begin-end.csv"}

. $TOP/country_list.sh

# default values for parameters
verbose="no"
START=`date +%s -d 2020-06-25T00:00:00Z`
STARTGIVEN="no"
END=`date +%s`
AUCSTR=""

function usage()
{
    echo "$0 [-chov] - track begin/end of services"
    echo "  -c [country-list] specifies which countries to process (defailt: all)"
    echo "      provide the country list as a space separatead lsit of 2-letter codes"
    echo "      e.g. '-c \"$COUNTRY_LIST\"'"
    echo "  -h means print this"
    echo "  -o specifies the output CSV file (default: $OUTCSVFILE)"
    echo "  -v means be verbose"
    exit 99
}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o c:ho:v -l countries:,help,outfile:,verbose -- "$@")
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
        -o|--output) OUTCSVFILE=$2; shift;;
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

echo "At $NOW: Running $0 $*"

# seconds per 2-weeks (fortnight)
WKSECS=$((7*60*60*24))

# for each country:
#   - find the start date (if any)
#   - find the end date (if any)
#   - whack into CSV
# plot that CSV

# end of loop time_t
endtt=`date +%s`

mintt=$endtt

csvbase=`basename $OUTCSVFILE .csv`
if [[ "$csvbase.csv" != "$OUTCSVFILE" ]]
then
    echo "Output CSV should be a .csv file - things may get weird, but I'll try"
fi

if [ -f $OUTCSVFILE ]
then
    mv $OUTCSVFILE $OUTCSVFILE.backup-$NOW.csv
fi
echo "country,name,start,end" >$OUTCSVFILE

for country in $COUNTRY_LIST
do
    ccsv="$TOP/data/all-zips/$country-tek-times.csv"
    if [ ! -f $ccsv ]
    then
        echo "Skipping $country - no CSV for it"
        continue
    fi
    lines=`wc -l $ccsv | awk '{print $1}'`
    if ((lines < 3))
    then
        echo "Skipping $country - CSV has too few lines"
        continue
    fi
    first_day=`head -2 $ccsv | tail -1 | awk -F, '{print $2}'`
    # some files have 1970 dates at the start, likely due to data oddities
    # but we'll skip such
    if [[ $first_day == 1970-* ]]
    then
        first_day=`head -3 $ccsv | tail -1 | awk -F, '{print $2}'`
    fi
    last_day=`tail -1 $ccsv | awk -F, '{print $2}'`
    # Canada has a 2038 date we also wanna skip
    if [[ $last_day == 2038-* ]]
    then
        last_day=`tail -2 $ccsv | head -1 | awk -F, '{print $2}'`
    fi
    if [[ "$verbose" == "yes" ]]
    then
        echo "$country: first: `basename $first_file`, $first_tstr; last: `basename $last_file`, $last_tstr"
    fi
    cstring="${COUNTRY_NAMES[$country]}"
    echo "$country,$cstring,$first_day,$last_day" >>$OUTCSVFILE

done

exit 0
