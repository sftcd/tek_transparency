#!/bin/bash

#set -x

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR="$HOME/data/teks/tek_transparency"}
x=${OUTDIR="`/bin/pwd`"}
x=${DOCROOT:='/var/www/tact/tek-counts/'}


# script to count each day's TEKs for each country/region

# Our definition of that day's TEKs is the number of TEKs
# that were first seen on that day for that country/region

# The input here is the run-directory for the run at 
# UTC midnight each day (currently, 1am Irish Summer Time)

# countries to do by default, or just one if given on command line
COUNTRY_LIST="ie ukni ch at dk de it pl ee fi lv es usva usal ca"

# default values for parameters
verbose="no"
OUTFILE="country-counts.csv"
RUNHOUR="00"
START=`date +%s -d 2020-06-01T$RUNHOUR:00:00Z`
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
    echo "  -r specifies the hour of thr run to use, between 00 and 23 (default: $RUNHOUR)"
    echo "  -s specifies the start time, in secs since UNIX epoch (default: $START)"
    echo "  -v means be verbose"
    exit 99
}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o c:d:e:ho:O:r:s:v -l countries:,dir:,end:,help,outdir:,outfile:,runhour:,start:,verbose -- "$@")
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
        -r|--runhour) RUNHOUR=$2; START=`date +%s -d 2020-06-01T$RUNHOUR:00:00Z`; shift;;
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

#START_STR=`date -d @$START`
#END_STR=`date -d @$END`
#echo "Going to count daily TEKS from $START_STR ($START) to $END_STR ($END) in $COUNTRY_LIST"

DAYSECS=$((60*60*24))

# And also when REDUCEing we need to keep track of what
# TEKs are from .ie and which from ukni
IETEKS="$OUTDIR/iefirstteks"
UKNITEKS="$OUTDIR/uknifirstteks"
if [[ ! -f $IETEKS || ! -f $UKNITEKS ]]
then
    echo "Reducing ie/unki prep..."
    $TOP/ie-ukni-sort.sh $IETEKS $UKNITEKS
else
    iemtime=`date -r $IETEKS +%s`
    uknimtime=`date -r $UKNITEKS +%s`
    now=`date +%s`
    if [ "$((now-iemtime))" -gt "86400" -o "$((now-uknimtime))" -gt "86400" ]
    then
        # make a wee backup
        mv $IETEKS $IETEKS.backup.$NOW
        mv $UKNITEKS $UKNITEKS.backup.$NOW
        echo "Reducing ie/unki prep as files older than 24 hours..."
        $TOP/ie-ukni-sort.sh $IETEKS $UKNITEKS
    fi
fi

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
    runlist4day="`ls -d $DATADIR/$year$month$day-*`"

    for run in $runlist4day
    do
        if [[ ! -d $run ]]
        then
            #echo -e "\tSkipping $run"
            continue
        fi 
        # if run time is before $mn then also skip it
        rtstr=`basename $run`
        rtyear=${rtstr:0:4}
        rtmonth=${rtstr:4:2}
        rtday=${rtstr:6:2}
        rthour=${rtstr:9:2}
        rtmin=${rtstr:11:2}
        rtsec=${rtstr:13:2}
        rt=`date +%s -d "$rtyear-$rtmonth-$rtday"T"$rthour:$rtmin:$rtsec"Z`
        if [[ $rt -lt $mn ]]
        then
           echo "$rt is less than $mn (for $run)"
           continue
        fi 
        echo "$rt is not less than $mn (for $run)"

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
                    llc=`echo "$ll" | awk -F, '{print $1}'` 
                    llday=`echo "$ll" | awk -F, '{print $2}'` 
                    lltime_t=`date -d "$llday" +%s`
                    lltek=`echo "$ll" | awk -F, '{print $3}'` 
                    llcnt=`echo "$ll" | awk -F, '{print $4}'` 
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
rm -f $TMPF $TMPF1

# now make HTML fragment with shortfalls
if [ -f $OUTDIR/shortfalls.html ]
then
    mv $OUTDIR/shortfalls.html $OUTDIR/shortfalls.$NOW.html
    # also make a more machine readable version, not quite json but feck it:-)
    $TOP/shortfalls.py -rn -t $OUTDIR/$OUTFILE -d $TOP/country-pops.csv >>$OUTDIR/shortfalls.$NOW.json
fi

cat >$OUTDIR/shortfalls.html <<EOF
<table border="1">
    <tr><td>Country/<br/>Region</td><td>Pop<br/>millions</td><td>Actives<br/>millions</td><td>Uploads</td><td>Cases</td><td>Shortfall<br/>percent</td><td>First TEK seen</td></tr>

EOF
for country in $COUNTRY_LIST
do
    $TOP/shortfalls.py -rH -t $OUTDIR/$OUTFILE -d $TOP/country-pops.csv -c $country >>$OUTDIR/shortfalls.html
done
cat >>$OUTDIR/shortfalls.html <<EOF
</table>

EOF

if [ -d $DOCROOT ]
then
    cp $OUTDIR/shortfalls.html $DOCROOT
	# put the csv in place too
	cp $OUTDIR/$OUTFILE $DOCROOT
fi

# same again but just for last 2 weeks, 'till yesterday:  make HTML fragment with shortfalls
endy=`date -d "$RUNHOUR:00Z" +%s`
endy=$((endy-86400))
starty=$((endy-14*86400))
eday=`date -d @$endy +"%d"`
emonth=`date -d @$endy +"%m"`
eyear=`date -d @$endy +"%Y"`
sday=`date -d @$starty +"%d"`
smonth=`date -d @$starty +"%m"`
syear=`date -d @$starty +"%Y"`
estr="$eyear-$emonth-$eday"
sstr="$syear-$smonth-$sday"

if [ -f $OUTDIR/shortfalls2w.html ]
then
    mv $OUTDIR/shortfalls2w.html $OUTDIR/shortfalls2w.$NOW.html
    # also make a more machine readable version, not quite json but feck it:-)
    $TOP/shortfalls.py -rn -t $OUTDIR/$OUTFILE -d $TOP/country-pops.csv -s $sstr -e $estr >>$OUTDIR/shortfalls2w.$NOW.json
fi

cat >$OUTDIR/shortfalls2w.html <<EOF
<table border="1">
    <tr><td>Country/<br/>Region</td><td>Pop<br/>millions</td><td>Actives<br/>millions</td><td>Uploads</td><td>Cases</td><td>Shortfall<br/>percent</td><td>First TEK seen</td></tr>

EOF
for country in $COUNTRY_LIST
do
    $TOP/shortfalls.py -rH -t $OUTDIR/$OUTFILE -d $TOP/country-pops.csv -c $country -s $sstr -e $estr  >>$OUTDIR/shortfalls2w.html
done
cat >>$OUTDIR/shortfalls2w.html <<EOF
</table>

EOF

if [ -d $DOCROOT ]
then
    cp $OUTDIR/shortfalls2w.html $DOCROOT
fi

# and finally some pictures
cdate_list=`$TOP/shortfalls.py -rn -t $OUTDIR/$OUTFILE -d $TOP/country-pops.csv | \
                awk -F, '{print $1$7}' | \
                sed -e 's/\[//' | \
                sed -e 's/]//' | \
                sed -e "s/'//g" | \
                sed -e 's/ /,/'`
for cdate in $cdate_list
do
    country=`echo $cdate | awk -F, '{print $1}'`
    sdate=`echo $cdate | awk -F, '{print $2}'`
    $TOP/plot-dailies.py -c $country -1 -i $OUTDIR/$OUTFILE -s $sdate -o $OUTDIR/$country.png
    convert $OUTDIR/$country.png -resize 115x71 $OUTDIR/$country-small.png
    if [ -d $DOCROOT ]
    then
        cp $OUTDIR/$country.png $OUTDIR/$country-small.png $DOCROOT
    fi
done


