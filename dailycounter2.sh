#!/bin/bash

# Same goal as dailycounter.sh, but with a different alg

# set -x

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${JHU_TOP:="$HOME/code/covid/jhu/COVID-19"}
x=${DATADIR="$HOME/data/teks/tek_transparency"}
x=${OUTDIR="`/bin/pwd`"}
x=${DOCROOT:='/var/www/tact/tek-counts/'}

TEK_DECODE="$TOP/tek_file_decode.py"

# script to count each day's TEKs for each country/region

# Our definition of that day's TEKs is the number of TEKs
# that were first seen on that day for that country/region

# The input here is the run-directory for the run at 
# UTC midnight each day (currently, 1am Irish Summer Time)

. $TOP/country_list.sh


# default values for parameters
verbose="no"
OUTFILE="country-counts.csv"
RUNHOUR="02"
START=`date +%s -d 2020-06-25T$RUNHOUR:00:00Z`
STARTGIVEN="no"
END=`date +%s`

function usage()
{
    echo "$0 [-cdhoOrsv] - estimate uploads/day from TEKS"
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

DAYSECS=$((60*60*24))

# We create this file from JHU data
JHU_WORLD_CASES="$OUTDIR/jhu.csv"
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

# Plan:
# for each country:
#   iterate from run after start to run after end...
#       establish epoch starts and ends and new TEKs between
#       epoch start = time of run where epoch first seen
#       epoch end = earliest of epoch-start + 24 hours, runtime later epoch seen
#           (noting any oddities)

runlist="$DATADIR/202*"
for run in $runlist
do
    if [ ! -d $run ]
    then
        # can happen if datadir and outdir are the same
        continue
    fi
    ofile="$OUTDIR/`basename $run`.csv"
    if [ ! -f $ofile ]
    then
        # map from zips to csv
        # TODO: we may still need to remove some .at batch files first
        $TOP/teks2csv.py -R -i $run -o $ofile.allteks
        if [ -f $ofile.allteks ]
        then
            ntek=`wc -l $ofile.allteks | awk '{print $1}'`
            echo "Collected $ntek TEKs from $run in $ofile.allteks"
            if [[ "$ntek" == "0" ]]
            then
                rm -f $ofile.allteks
            fi
        else
            # can happen if no events that day (mostly on subsets of data though)
            echo "No TEKs in $run!"
        fi
    else
		# wc is a bit slow for so many largish CSVs and
		# the info's not that interesting so we'll skip
        # ntek=`wc -l $ofile | awk '{print $1}'`
		#echo "Re-using $ntek TEKs from $run in $ofile"
        echo "Re-using TEKs from $run in $ofile"
    fi
done

# Now apply special processing for crazy AT fake TEK removal 
# We *really* don't want to do this often - it's slooooowwww
# Other fake TEKs are handled later

if [[ $COUNTRY_LIST = *at* ]]
then
	for run in $runlist
	do
	    ifile="$OUTDIR/`basename $run`.csv.allteks"
	    if [ ! -s $ifile ]
	    then
	        # will often happen due to caching
	        continue
	    fi
	    # just in case other countries do similarly odd things later...
        CRAZY_LIST="at"
	    for c in $CRAZY_LIST
	    do
	        # do country-specifics
	        icnt=`wc -l $ifile | awk '{print $1}'`
	        echo -n "Removing $c fakes from $ifile: (started with $icnt"
	        tmpf=`mktemp /tmp/dc2XXXX`
	        if [[ "$c" == "at" ]]
	        then
	            atstoppedfakes=$((`date -d "2020-08-12" +%s`))
	            rtstr=`basename $run`
	            rtyear=${rtstr:0:4}
	            rtmonth=${rtstr:4:2}
	            rtday=${rtstr:6:2}
	            rtimet=`date +%s -d"$rtyear-$rtmonth-$rtday"`
	            if (( rtimet > atstoppedfakes ))
	            then
	                icnt=`wc -l $ifile | awk '{print $1}'`
	                echo ", ended with $icnt)"
	                continue
	            fi
	            # another attempt to avoid the slow bit
	            atcnt=`grep -c ",at," $ifile`
	            if [[ "$atcnt" == "0" ]]
	            then
	                icnt=`wc -l $ifile | awk '{print $1}'`
	                echo ", ended with $icnt)"
	                continue
	            fi
	            # now the slow bit
	            if [ -f $HOME/at-one-off/one-off-at-index ]
	            then
	                # still faster but avoids grep using so much memory
	                # which is apparently needed on our ancient server:-)
	                for tfile in `cat $HOME/at-one-off/one-off-at-index` 
	                do
	                    grep -v -f $HOME/at-one-off/$tfile $ifile >$tmpf
	                    mv $tmpf $ifile
	                done
	            elif [ -f $HOME/at-one-off/one-off-at-teks ]
	            then
	                # This is slower but requires memory 
	                grep -v -f $HOME/at-one-off/one-off-at-teks $ifile >$tmpf
	                mv $tmpf $ifile
	            else
	                # This is waaay slower but safer, as we don't need to
	                # distribute real TEKs. Mind you, when I say "safe"
	                # I've not tested it fully, because it's so slow;-)
	                for line in `cat $ifile` 
	                do 
	                    ltek=`echo $line | awk -F\' '{print $2}'`
	                    lhash=`echo -n $ltek | openssl sha256 | awk '{print $2}'`
	                    hit=`grep -c $lhash $TOP/at-one-off/one-off-at-hteks`
	                    if [[ "$hit" == "0" ]]
	                    then
	                        echo $line >>$tmpf
	                    fi
	                done
	                mv $tmpf $ifile
	            fi
	        elif [[ "$c" == "other-odd-country" ]]
	        then
	            echo "Something very weird and almost Austrian:-)"
	        fi
	        rm -f $tmpf
	        icnt=`wc -l $ifile | awk '{print $1}'`
	        echo ", ended with $icnt)"
	    done
	    ofile="$OUTDIR/`basename $run`.csv"
	    mv $ifile $ofile
	done
fi

# simply rename any remaining allteks files that exist
atlist="$OUTDIR/*.allteks"
if [[ "$atlist" != "" ]]
then
    echo "Renaming non-crazy CSVs."
    for at in $atlist
    do
        if [ -s $at ]
        then
            mv $at "$OUTDIR/`basename $at .csv.allteks`.csv"
        fi
    done
fi

#IETEKS="$OUTDIR/iefirstteks"
#UKNITEKS="$OUTDIR/uknifirstteks"
IETEKS="$OUTDIR/new-iefirsts"
UKNITEKS="$OUTDIR/new-uknifirsts"
IETEKFREQ="3600"

# When REDUCEing we need to keep track of what
# TEKs are from .ie and which from ukni
do_ieukni=False
if [[ $COUNTRY_LIST = *ie* ]]
then
    do_ieukni=True
fi
if [[ $COUNTRY_LIST = *ukni* ]]
then
    do_ieukni=True
fi

if [[ "$do_ieukni" == "True" ]]
then
    # $IETEKS $UKNITEKS are hard-coded names within the new sript for now
	if [[ ! -f $IETEKS || ! -f $UKNITEKS ]]
	then
	    echo "Reducing ie/unki prep..."
	    $TOP/new-ie-ukni-sort.sh 
	else
	    iemtime=`date -r $IETEKS +%s`
	    uknimtime=`date -r $UKNITEKS +%s`
	    now=`date +%s`
	    # change from before - do it hourly now, which allows quicker tests
	    # but more accurate counts (once we get it right)
	    if [ "$((now-iemtime))" -gt $IETEKFREQ -o "$((now-uknimtime))" -gt $IETEKFREQ ]
	    then
	        # make a wee backup
	        cp $IETEKS $IETEKS.backup.$NOW
	        cp $UKNITEKS $UKNITEKS.backup.$NOW
	        echo "Re-checking ie/unki prep as files older than $IETEKFREQ seconds..."
	        $TOP/new-ie-ukni-sort.sh 
	    fi
	fi
fi

# From here on, we usen't cache but re-calculate always
# but that's v. v. slow on down (for some reason) so we
# can instead only take our cue from the output file and
# reduce the work

# we'll check the latest date in the output, then go
# back 48 hours before that and go from there - we do
# that by adjusting the START date (unless one was
# given on the command line)


CCMINUS3=""
if [[ "$STARTGIVEN" == "no" ]]
then
    if [ -f $OUTDIR/$OUTFILE ]
    then
        ldate_str=`cat $OUTDIR/$OUTFILE | awk -F, '{print $2}' | sort | tail -1`
        ldate_str="$ldate_str"Z
        ldate=`date +%s -d $ldate_str`
        ldate=$((ldate-3*DAYSECS))
        START=$ldate
        # Make a version of output that omits those days
        thed=$START
        thedfile=`mktemp /tmp/thedXXXX`
        while ((thed < END ))
        do
            yminus=`date -d@$((thed)) +%Y`
            mminus=`date -d@$((thed)) +%m`
            dminus=`date -d@$((thed)) +%d`
            echo "$yminus-$mminus-$dminus" >>$thedfile
            thed=$((thed+DAYSECS))
        done
        CCMINUS3=`mktemp /tmp/ccm3XXXX`
        grep -v -f $thedfile $OUTDIR/$OUTFILE >$CCMINUS3
        rm -f $thedfile
    fi
fi

TMPF=`mktemp $OUTDIR/dctekXXXX`
TMPF1=`mktemp $OUTDIR/dctekXXXX`
for c in $COUNTRY_LIST
do
    latest_epoch=0
    mn=$START
    while ((mn < END))
    do
        year=`date -d @$mn +%Y`
        month=`date -d @$mn +%m`
        day=`date -d @$mn +%d`
        yminus1=`date -d@$((mn-DAYSECS)) +%Y`
        mminus1=`date -d@$((mn-DAYSECS)) +%m`
        dminus1=`date -d@$((mn-DAYSECS)) +%d`
        yplus1=`date -d@$((mn+DAYSECS)) +%Y`
        mplus1=`date -d@$((mn+DAYSECS)) +%m`
        dplus1=`date -d@$((mn+DAYSECS)) +%d`

        # check if CSVs exist for that day
        tek_files=$OUTDIR/$year$month$day-*.csv 
        index_file_m1="$OUTDIR/$yplus1$mplus1$dplus1-00*.csv"
        index_file="$OUTDIR/$yplus1$mplus1$dplus1-01*.csv"
        all_files="$tek_files $index_file_m1 $index_file"
        fileexists=True
        for tf in $all_files
        do
            if [ ! -s $tf ]
            then
                fileexists=False
                echo "Missing or empty $tf"
            fi
        done
        if [[ "$filesexist" == "False" ]]
        then
            echo "Skipping $year-$month-$day"
            mn=$((mn+DAYSECS))
            continue
        fi
        # CSVs are produced by loop above

        # we detect the latest epoch from the index file and then count
        # the number of TEKs matching that epoch from the previous 25 
        # hours (24 would be tidier but doesn't matter:-)
        tekepoch=`grep ",$c," $index_file | awk -F, '{print $10}' | sort -n | uniq | tail -1`
        if [[ "$tekepoch" == "" ]]
        then
            # this can happen as services are introduced
            teksofepochcnt=0
            tekepoch=0
        else
            theepochteks=`mktemp /tmp/theteksXXXX`
            grep ",$c," $all_files | grep ",$tekepoch," >$theepochteks
            teksofepochcnt=`cat $theepochteks | awk -F, '{print $9}' | sort | uniq | wc -l`
        fi
        dstr=`date -d@$((tekepoch*600))`
        echo "Unique TEK count for $c,$year-$month-$day is $teksofepochcnt, latest epoch: $tekepoch"

        # eliminate any IE/UKNI duplicates at this point
        if [[ "$c" == "ie" ]]
        then
            before=$teksofepochcnt
            if (( before > 0 ))
            then
                teksofepochcnt=`grep -v -f $UKNITEKS $theepochteks | awk -F, '{print $9}' | sort | uniq | wc -l`
            fi
            echo "Fake ie TEKs removal: from $before to $teksofepochcnt on $dstr"
        elif [[ "$c" == "ukni" ]]
        then
            before=$teksofepochcnt
            if (( before > 0 ))
            then
                teksofepochcnt=`grep -v -f $IETEKS $theepochteks | awk -F, '{print $9}' | sort | uniq | wc -l`
            fi
            echo "Fake ukni TEKs removal: from $before to $teksofepochcnt on $dstr"
        fi
        if [[ "$c" == "de" ]]
        then
            before=$teksofepochcnt
            # divide by 10 or 5, depending on date
            de10xtill=$((`date -d "2020-07-04" +%s`/600))
            if (( tekepoch < de10xtill ))
            then
                teksofepochcnt=$((teksofepochcnt/10))
            else
                teksofepochcnt=$((teksofepochcnt/5))
            fi
            echo "Fake de TEKs removal: from $before to $teksofepochcnt on $dstr"
        fi
        if [[ "$c" == "ch" ]]
        then
            # subtract 10, depending on date
            chstoppedfakes=$((`date -d "2020-07-19" +%s`/600))
            before=$teksofepochcnt
            if (( before >=10 && tekepoch < chstoppedfakes ))
            then
                teksofepochcnt=$((teksofepochcnt-10))
                echo "Fake ch TEKs removal: from $before to $teksofepochcnt on $dstr"
            fi
        fi

        if (( tekepoch > latest_epoch ))
        then
            latest_epoch=$tekepoch
            echo "Changed Epoch,$dstr,$c,$latest_epoch,$tekepoch"
            lday=`date +%Y-%m-%d -d@$((tekepoch*600))`
            ccnt=`grep "^$c,$lday" $JHU_WORLD_CASES | awk -F, '{print $4}'`
            echo "$c,$lday,$teksofepochcnt,$ccnt" >>$TMPF
        else
            echo "No epoch change,$dstr,$c,$latest_epoch,$tekepoch"
        fi
        #rm -f $theteks $theepochteks $thefirstteks
        #rm -f $theteks $theepochteks 
        rm -f $theepochteks 

        mn=$((mn+DAYSECS))
    done
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
        alreadythere=`grep -c "^$country,$year-$month-$day" $TMPF`
        if [[ "$alreadythere" == "0" ]]
        then
            allcases=`grep "^$country,$year-$month-$day" $JHU_WORLD_CASES | awk -F, '{print $4}'`
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
# CCMINUS3 may be empty or might have the previous output minus
# the last 3 days
cat $CCMINUS3 $TMPF $TMPF1 | sort | tac | sort -u -t, -r -k1,2 |tac > $OUTDIR/$OUTFILE
rm -f $TMPF $TMPF1 $CCMINUS3

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
    if [[ "$sdate" == "" ]]
    then
        echo "No sign of start date for $country"
    else
        $TOP/plot-dailies.py -c $country -1 -i $OUTDIR/$OUTFILE -s $sdate -o $OUTDIR/$country.png
        convert $OUTDIR/$country.png -resize 115x71 $OUTDIR/$country-small.png
        if [ -d $DOCROOT ]
        then
            cp $OUTDIR/$country.png $OUTDIR/$country-small.png $DOCROOT
        fi
    fi
done


NOW=$(whenisitagain)

echo "At $NOW: Finished running $0 $*"

