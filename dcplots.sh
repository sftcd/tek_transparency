#!/bin/bash

# Do the plots for dailycounter2.sh

# set -x

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${JHU_TOP:="$HOME/code/covid/jhu/COVID-19"}
x=${THEDIR="`/bin/pwd`"}
x=${DOCROOT:='/var/www/tact/tek-counts/'}

TEK_DECODE="$TOP/tek_file_decode.py"

# default values for parameters
verbose="no"
THEFILE="country-counts.csv"

function usage()
{
    echo "$0 [-cdhoOrsv] - estimate uploads/day from TEKS"
    echo "  -h means print this"
    echo "  -d specifies the input directory (default: $THEDIR)"
    echo "  -f specifies the input CSV file (default: $THEFILE)"
    echo "  -v means be verbose"
    exit 99
}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o d:f:hO:v -l dir:,file:,help,verbose -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi
#echo "|$options|"
eval set -- "$options"
while [ $# -gt 0 ]
do
    case "$1" in
        -h|--help) usage;;
        -d|--dir) THEDIR=$2; shift;;
        -f|--file) THEFILE=$2; shift;;
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

# and finally some pictures
cdate_list=`$TOP/shortfalls.py -rn -t $THEDIR/$THEFILE -d $TOP/country-pops.csv | \
                awk -F, '{print $1$7}' | \
                sed -e 's/\[//' | \
                sed -e 's/]//' | \
                sed -e "s/'//g" | \
                sed -e 's/ /,/'`
for cdate in $cdate_list
do
    country=`echo $cdate | awk -F, '{print $1}'`
    sdate=`echo $cdate | awk -F, '{print $2}'`
    if [[ "$sdate" == "" ]]
    then
        echo "No sign of start date for $country"
    else
        # linear plots
        $TOP/plot-dailies.py -nt -c $country -1 -i $THEDIR/$THEFILE -s $sdate -o $THEDIR/$country.png
        #$TOP/plot-dailies.py -nt -c $country -1 -i $THEDIR/$THEFILE -s 2020-06-22 -o $THEDIR/$country.png
        # log plot
        $TOP/plot-dailies.py -ntl -c $country -1 -i $THEDIR/$THEFILE -s $sdate -o $THEDIR/$country-log.png
        # abs log plot
        $TOP/plot-dailies.py -antl -c $country -1 -i $THEDIR/$THEFILE -s 2020-06-22 -o $THEDIR/$country-abs-log.png
        # abs plot
        $TOP/plot-dailies.py -ant -c $country -1 -i $THEDIR/$THEFILE -s 2020-06-22 -o $THEDIR/$country-abs.png
        convert $THEDIR/$country.png -resize 115x71 $THEDIR/$country-small.png
        if [ -d $DOCROOT ]
        then
            cp $THEDIR/$country.png $THEDIR/$country-small.png $DOCROOT
        fi
    fi
done


NOW=$(whenisitagain)
echo "At $NOW: Finished running $0 $*"

