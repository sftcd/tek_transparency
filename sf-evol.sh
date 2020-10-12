#!/bin/bash

# Make a CSV showing the evolution of shorfalls

# set -x

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${INCSVFILE="country-counts.csv"}
x=${OUTCSVFILE="shortfall-evol.csv"}
x=${PNGFILE="shortfall-evol.png"}

# script to count each day's TEKs for each country/region

# Our definition of that day's TEKs is the number of TEKs
# that were first seen on that day for that country/region

# The input here is the run-directory for the run at 
# UTC midnight each day (currently, 1am Irish Summer Time)

. $TOP/country_list.sh


# default values for parameters
verbose="no"
START=`date +%s -d 2020-06-25T$RUNHOUR:00:00Z`
STARTGIVEN="no"
END=`date +%s`

function usage()
{
    echo "$0 [-cCehoOsv] - track evolution of shortfall"
    echo "  -c [country-list] specifies which countries to process (defailt: all)"
    echo "      provide the country list as a space separatead lsit of 2-letter codes"
    echo "      e.g. '-c \"$COUNTRY_LIST\"'"
    echo "  -e specifies the end time, in secs since UNIX epoch (default: $END)"
    echo "  -h means print this"
    echo "  -i specifies the input CSV file (default: $INCSVFILE)"
    echo "  -o specifies the output CSV file (default: $OUTCSVFILE)"
    echo "  -p specifies the output PNG file (default: $PNGFILE)"
    echo "  -s specifies the start time, in secs since UNIX epoch (default: $START)"
    echo "  -v means be verbose"
    exit 99
}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o c:e:hi:o:p:s:v -l countries:,end:,help,infile:,outfile:,pngfile:,start:,verbose -- "$@")
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
        -i|--input) INCSVFILE=$2; shift;;
        -o|--output) OUTCSVFILE=$2; shift;;
        -p|--pngfile) PNGFILE=$2; shift;;
        -s|--start) STARTGIVEN="yes"; START=$2; shift;;
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
#   - for each 2week period 'till now, figure shortfall
#   - whack into CSV
# plot that CSV

# end of loop time_t
endtt=`date +%s`

mintt=$endtt

if [ ! -f $INCSVFILE ]
then
    echo "No input $INCSVFILE - exiting"
    exit 1
fi

if [ -f $OUTCSVFILE ]
then
    mv $OUTCSVFILE $OUTCSVFILE.backup-$NOW.csv
fi
echo "country,start,end,shortfall" >$OUTCSVFILE

if [ -f $PNGFILE ]
then
    cp $PNGFILE $PNGFILE.backup-$NOW.png
fi

pngbase=`basename $PNGFILE .png`
if [[ "$pngbase.png" != "$PNGFILE" ]]
then
    echo "Output PNG should be a .png file - things may get weird, but I'll try"
fi
csvbase=`basename $OUTCSVFILE .csv`
if [[ "$csvbase.csv" != "$OUTSCVFILE" ]]
then
    echo "Output CSV should be a .csv file - things may get weird, but I'll try"
fi

# a temp file is always handy:-)
ctmp=`mktemp /tmp/sfevolXXXX`

# We'll do this 3 times, with a 1 week window, then with a
# 2 week window, and then from the start extending by one
# week each time

# it'd be more elegant if I did that in one loop but it's
# quicker to not, so I'm going with quicker:-)

### 1 week at a time
for country in $COUNTRY_LIST
do
    sdate=`grep "$country," $INCSVFILE | grep -v ",0," | sort -t, -k2 | head -1 | awk -F, '{print $2}'`
    if [[ "$sdate" == "" ]]
    then
        echo "Skipping $country - no first TEK"
        continue
    fi
    sdtt=`date +%s -d $sdate`
    echo "Doing $country 1w starting from $sdate"
    dow=`date +%u -d @$sdtt`
    # move back to the prev monday
    sdtt=$((sdtt-(dow-1)*(60*60*24)))
    # keep track of min date
    if (( sdtt < mintt ))
    then
        mintt=$sdtt
    fi
    gotone="False"
    while (((sdtt+WKSECS) < endtt ))
    do
        sstr=`date +%Y-%m-%d -d @$sdtt`
        estr=`date +%Y-%m-%d -d @$((sdtt+WKSECS))`
        sfo=`$TOP/shortfalls.py -c $country -t $INCSVFILE -d $TOP/country-pops.csv -rn -s $sstr -e $estr`
        sfr=`echo $sfo | awk -F, '{print $6}' | sed -e "s/'//g" | sed -e 's/ //g'`
        if [[ "$gotone" == "False" ]] 
        then
            if [[ "$sfr" == "" || "$sfr" == "-" ]]
            then
                echo "Breaking out of $country"
                break
            fi
            gotone="True"
        fi
        if [[ "$sfr" == "" || "$sfr" == "-" ]]
        then
            # expected something, got nohting => 100% shortfall
            echo "$country,$sstr,$estr,100.0" >>$csvbase-1w.csv
        else
            echo "$country,$sstr,$estr,$sfr" >>$csvbase-1w.csv
        fi
        sdtt=$((sdtt+WKSECS))
    done
    # do a bit of plotting
    ccnt=`grep -c "$country," $csvbase-1w.csv`
    if [[ "$ccnt" == "0" ]]
    then
        echo "Not plotting $country - nothing there"
    else
        echo "Plotting $country into $pngbase-1w-$country.png"
        grep "$country," $csvbase-1w.csv >$ctmp
        $TOP/plot-evol.py -i $ctmp -o $pngbase-1w-$country.png
    fi
done
# last - plot all at once
$TOP/plot-evol.py -i $csvbase-1w.csv -o $pngbase-1w.png

### 2 weeks at a time
for country in $COUNTRY_LIST
do
    sdate=`grep "$country," $INCSVFILE | grep -v ",0," | sort -t, -k2 | head -1 | awk -F, '{print $2}'`
    if [[ "$sdate" == "" ]]
    then
        echo "Skipping $country - no first TEK"
        continue
    fi
    sdtt=`date +%s -d $sdate`
    echo "Doing $country 2w starting from $sdate"
    dow=`date +%u -d @$sdtt`
    # move back to the prev monday
    sdtt=$((sdtt-(dow-1)*(60*60*24)))
    # check that it's an even numbered week so all countries on the 
    # same schedule
    weekno=`date +%V -d @$sdtt`
    if (( (weekno%2) == 1 ))
    then
        # go back a week further
        sdtt=$((sdtt-WKSECS))
    fi
    # keep track of min date
    if (( sdtt < mintt ))
    then
        mintt=$sdtt
    fi
    gotone="False"
    while (((sdtt+2*WKSECS) < endtt ))
    do
        sstr=`date +%Y-%m-%d -d @$sdtt`
        estr=`date +%Y-%m-%d -d @$((sdtt+2*WKSECS))`
        sfo=`$TOP/shortfalls.py -c $country -t $INCSVFILE -d $TOP/country-pops.csv -rn -s $sstr -e $estr`
        sfr=`echo $sfo | awk -F, '{print $6}' | sed -e "s/'//g" | sed -e 's/ //g'`
        if [[ "$gotone" == "False" ]] 
        then
            if [[ "$sfr" == "" || "$sfr" == "-" ]]
            then
                echo "Breaking out of $country"
                break
            fi
            gotone="True"
        fi
        if [[ "$sfr" == "" || "$sfr" == "-" ]]
        then
            # expected something, got nohting => 100% shortfall
            echo "$country,$sstr,$estr,100.0" >>$csvbase-2w.csv
        else
            echo "$country,$sstr,$estr,$sfr" >>$csvbase-2w.csv
        fi
        sdtt=$((sdtt+2*WKSECS))
    done
    # do a bit of plotting
    ccnt=`grep -c "$country," $csvbase-2w.csv`
    if [[ "$ccnt" == "0" ]]
    then
        echo "Not plotting $country - nothing there"
    else
        echo "Plotting $country into $pngbase-2w-$country.png"
        grep "$country," $csvbase-2w.csv >$ctmp
        $TOP/plot-evol.py -i $ctmp -o $pngbase-2w-$country.png
    fi
done
# last - plot all at once
$TOP/plot-evol.py -i $csvbase-2w.csv -o $pngbase-2w.png

### 1 week at a time, but with start date of earliest TEK
### so not 1w or 2w but all weeks, so aw
for country in $COUNTRY_LIST
do
    sdate=`grep "$country," $INCSVFILE | grep -v ",0," | sort -t, -k2 | head -1 | awk -F, '{print $2}'`
    if [[ "$sdate" == "" ]]
    then
        echo "Skipping $country - no first TEK"
        continue
    fi
    sdtt=`date +%s -d $sdate`
    echo "Doing $country aw starting from $sdate"
    dow=`date +%u -d @$sdtt`
    # move back to the prev monday
    sdtt=$((sdtt-(dow-1)*(60*60*24)))
    # keep track of min date
    if (( sdtt < mintt ))
    then
        mintt=$sdtt
    fi
    gotone="False"
    while (((sdtt+WKSECS) < endtt ))
    do
        sstr=`date +%Y-%m-%d -d @$sdtt`
        estr=`date +%Y-%m-%d -d @$((sdtt+WKSECS))`
        sfo=`$TOP/shortfalls.py -c $country -t $INCSVFILE -d $TOP/country-pops.csv -rn -s $sdate -e $estr`
        sfr=`echo $sfo | awk -F, '{print $6}' | sed -e "s/'//g" | sed -e 's/ //g'`
        if [[ "$gotone" == "False" ]] 
        then
            if [[ "$sfr" == "" || "$sfr" == "-" ]]
            then
                echo "Breaking out of $country"
                break
            fi
            gotone="True"
        fi
        if [[ "$sfr" == "" || "$sfr" == "-" ]]
        then
            # expected something, got nohting => 100% shortfall
            echo "$country,$sstr,$estr,100.0" >>$csvbase-aw.csv
        else
            echo "$country,$sstr,$estr,$sfr" >>$csvbase-aw.csv
        fi
        sdtt=$((sdtt+WKSECS))
    done
    # do a bit of plotting
    ccnt=`grep -c "$country," $csvbase-aw.csv`
    if [[ "$ccnt" == "0" ]]
    then
        echo "Not plotting $country - nothing there"
    else
        echo "Plotting $country into $pngbase-aw-$country.png"
        grep "$country," $csvbase-aw.csv >$ctmp
        $TOP/plot-evol.py -i $ctmp -o $pngbase-aw-$country.png
    fi
done
# last - plot all at once
$TOP/plot-evol.py -i $csvbase-aw.csv -o $pngbase-aw.png

# clean up
rm -f $ctmp

