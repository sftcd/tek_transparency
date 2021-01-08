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

# The sorts for some of these are getting too big for the space
# left on the main disk, so I'm gonna try re-set TMPDIR to a
# place where I have more space. Let's see if that works...

export TMPDIR=/tmp
export TMP=/tmp
if [ -d /data1/tmp ]
then
	export TMPDIR=/data1/tmp
	export TMP=/data1/tmp
fi

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

# Ensure that only one of these runs at a time...
# This from https://unix.stackexchange.com/questions/48505/how-to-make-sure-only-one-instance-of-a-bash-script-runs
# Check if another instance of script is running
pidof -o %PPID -x $0 >/dev/null && echo "TEK_TIMES ERROR: Script $0 already running at $NOW" && exit 18

. $TOP/country_list.sh

DATADIR="`/bin/pwd`"
OUTDIR="`/bin/pwd`"

# Whether to report raw (e.g. Austria) counts ("no") or to 
# reduce those by not counting TEKs that were only ever
# seen in one zip file ("yes")
REDUCE="no"

# When REDUCEing...
# there are some special cases with dates associated:
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

# And also when REDUCEing we need to keep track of what
# TEKs are from .ie and which from ukni
IETEKS="$DATADIR/iefirstteks"
UKNITEKS="$DATADIR/uknifirstteks"

# whether to do a full re-count or not
dofull="False"

if [[ "$REDUCE" == "yes" ]]
then 
    if [[ ! -f $IETEKS || ! -f $UKNITEKS ]]
    then
        echo "Reducing ie/unki prep..."
        $TOP/ie-ukni-sort.sh $IETEKS $UKNITEKS
    else
        iemtime=`date -r $IETEKS +%s`
        uknimtime=`date -r $UKNITEKS +%s`
        now=`date +%s`
        if [ "$((now-iemtime))" -gt "86400" || "$((now-uknimtime))" -gt "86400" ]
        then
            echo "Reducing ie/unki prep as files older than 24 hours..."
            $TOP/ie-ukni-sort.sh $IETEKS $UKNITEKS
        fi
            
    fi
fi


function usage()
{
    echo "$0 [-chiovF] - test HPKE test vectors"
    echo "  -c [country-list] specifies which countries to process (defailt: all)"
    echo "      provide the country list as a space separatead lsit of 2-letter codes"
    echo "      e.g. '-c \"$COUNTRY_LIST\"'"
    echo "  -d specifies the input data directory (default: $DATADIR)"
    echo "  -h means print this"
    echo "  -o specifies the output directory (default: $OUTDIR)"
    echo "  -r means to reduce TEK numbers calculated based on known oddities (default: "no" - report raw numbers)"
    echo "  -F means to do a full count, not incremental"
    echo "  -v means be verbose"
    exit 99
}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o Fc:d:ho:rv -l full,countries:,dir:,help,outdir:,reduce,verbose -- "$@")
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
        -h|--help) usage;;
        -o|--outdir) OUTDIR=$2; shift;;
        -r|--reduce) REDUCE="yes";; 
        -F|--full) dofull="True";; 
        -v|--verbose) verbose="yes" ;;
        (--) shift; break;;
        (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
        (*)  break;;
    esac
    shift
done

# We'll work in $DATADIR
if [ ! -d $DATADIR ]
then
    echo "Can't see $DATADIR - exiting"
    exit 1
fi
cd $DATADIR
if [ ! -d $OUTDIR ]
then
    echo "Can't see $OUTDIR - exiting"
    exit 2
fi

# list of cases for all countries
# Now that we want UK regions (NI anyway) and US states, we'll change
# to using the JHU data.
do_jhu="yes"
do_who="no"
do_ecdc="no"

x=${JHU_TOP:="$HOME/code/covid/jhu/COVID-19"}
# We create this file from JHU data
JHU_WORLD_CASES="$OUTDIR/jhu.csv"

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
WHO_WORLD_CASES="$OUTDIR/WHO-COVID-19-global-data.csv"

# If not, we'll grab one that kinda works via curl 
CASES_URL="https://opendata.ecdc.europa.eu/covid19/casedistribution/csv"
# local copy - refreshed if > 1 day old
ECDC_WORLD_CASES="$OUTDIR/world-cases.csv"

# the (suffix of the) final outcome
TARGET="tek-times.csv"

# some temp files
T2="$TMPDIR/t2.tmp"
T2p5="$TMPDIR/t2.5.tmp"
T2p6="$TMPDIR/t2.6.tmp"
T3="$TMPDIR/t3.tmp"
T4="$TMPDIR/t4.tmp"
T5="$TMPDIR/t5.tmp"

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
        # we'll rebuild from scratch - if that takes too long we can
        # optimise later, meanwhile this works even if retrospective 
        # changes are made
        # We need to work with the daily files to get the regions (ukni, usva)
        # Those have the accumulated totals, so we'll need to subtract to get
        # the daily values
        for country in $COUNTRY_LIST
        do
            targfile=$OUTDIR/$country-$TARGET
            if [[ "$country" == "ukenw" ]]
            then
                # special case - we need to count England and Wales (and not Scotland/NI)
                tmpf2=`mktemp jhuXXXX`
                for cstring in England Wales
                do
                    tmpf=`mktemp jhuXXXX`
                    tmpf1=`mktemp jhuXXXX`
                    # the commas below in the grep input are important!
                    grep ",$cstring" $JHU_TOP/csse_covid_19_data/csse_covid_19_daily_reports/*.csv  | awk -F, '{print $5,$8}' >$tmpf
                    # handle cases with US dates like 09/8/20
                    grep ",$cstring" $JHU_TOP/csse_covid_19_data/csse_covid_19_daily_reports/*.csv  | awk -F, '{print $5,$8}' | grep '/' | awk -F'/' '{print "20"$3" "$2" "$1'}  | awk '{printf("%04d-%02d-%02d,%d\n",$1,$5,$4,$3)'} >>$tmpf
        
                    cat $tmpf | sort | grep "^202[01]-" | awk -F' ' '{print $1","$3}' >$tmpf1
                    cat $tmpf1 | awk -F, '{array[$1]+=$2} END { for (i in array) {print i"," array[i]}}' | sort  >$tmpf2.$cstring
                    rm -f $tmpf $tmpf1 
                done
                join -t, -1 1 -2 1 $tmpf2.England $tmpf2.Wales  | awk -F, '{print $1","$2+$3}' >$tmpf2
                cat $tmpf2 | awk -F, 'BEGIN {last=0} {print "'$country',"$1","$2","$2-last; last=$2}' >>$JHU_WORLD_CASES
                rm -f $tmpf2 $tmpf2.England $tmpf2.Wales
            else
                cstring=",${COUNTRY_NAMES[$country]}"
                tmpf=`mktemp jhuXXXX`
                tmpf1=`mktemp jhuXXXX`
                tmpf2=`mktemp jhuXXXX`
                grep "$cstring" $JHU_TOP/csse_covid_19_data/csse_covid_19_daily_reports/*.csv  | awk -F, '{print $5,$8}' >$tmpf
			    # handle cases with US dates like 09/8/20
                grep "$cstring" $JHU_TOP/csse_covid_19_data/csse_covid_19_daily_reports/*.csv  | awk -F, '{print $5,$8}' | grep '/' | awk -F'/' '{print "20"$3" "$2" "$1'}  | awk '{printf("%04d-%02d-%02d,%d\n",$1,$5,$4,$3)'} >>$tmpf
    
                cat $tmpf | sort | grep "^202[01]-" | awk -F' ' '{print $1","$3}' >$tmpf1
                cat $tmpf1 | awk -F, '{array[$1]+=$2} END { for (i in array) {print i"," array[i]}}' | sort  >$tmpf2
                cat $tmpf2 | awk -F, 'BEGIN {last=0} {print "'$country',"$1","$2","$2-last; last=$2}' >>$JHU_WORLD_CASES
                rm -f $tmpf $tmpf1 $tmpf2 
            fi

        done
    fi
fi

for country in $COUNTRY_LIST
do
    targfile=$OUTDIR/$country-$TARGET

    # did I do all zips or just the last few weeks worth? If the
    # latter I'll need to splice things together at the end so I
    # need to remember that
    dosplice="False"

    if [ -f $country-canary ]
    then
        echo "Normally Skipping $country"
        #continue
    fi
    # upper case variant
    ucountry=${country^^}
    if [[ "$REDUCE" != "yes" ]]
    then
        # be a bit quieter then:-)
		NOW=$(whenisitagain)
        echo "Doing $country at $NOW"
    fi


    # If a targfile output exists already we'll only process 
    # zips that post-date two weeks before the last date in that
    # targfile
    if [[ "$dofull" == "False" && -f $targfile ]]
    then
        ldatestr=`tail -1 $targfile | awk -F, '{print $2}'`
        if [[ "$ldatestr" != "Date" ]]
        then
            # backup
            dosplice="True"
            mv $targfile $targfile-b4-$NOW 
            echo "Country,Date,TEKs,Cases" >$targfile
            ldate=`date +%s -d $ldatestr`
            sdate=$((ldate-(14*24*60*60)))
            ziplist=""
            zcount=0
            skipcount=0
            for zipf in $country-*.zip 
            do
                ztime=`stat -c %Y $zipf`
            	if (( ztime >= sdate ))
                then
                    ziplist="$ziplist $zipf"
                    zcount=$((zcount+1))
                else
                    skipcount=$((skipcount+1))
                fi
            done
			if [[ "$ziplist" != "" ]]
			then
            	echo "Will do $zcount zips (skipping $skipcount) from $sdate (`date -d @$sdate`), which is two weeks before $ldatestr"
            	$TEK_COUNT $ziplist | sort | uniq >$T2
			else
				# skip this one, nothing to do this time
				echo "Skipping $country - nothing to do this time"
				continue
			fi
        else
            # do the lot
            echo "Country,Date,TEKs,Cases" >$targfile
            $TEK_COUNT $country-*.zip | sort | uniq >$T2
        fi
    else
        echo "Country,Date,TEKs,Cases" >$targfile
        $TEK_COUNT $country-*.zip | sort | uniq >$T2
    fi

    # TODO: figure out if this is correct or not! (Likely requires contact to .at)
    # experimental Austrian pruning - it seems that almost all TEKs from .at 
    # only exist in one zip file, that seems wrong. I've collected a pile of
    # the ones that occur in less than 24 files and put those and the sha256 
    # hashes of 'em in files. If any TEK here is in one of those files, we'll 
    # not bother counting it.
    if [[ "$REDUCE" == "yes" && "$country" == "at" ]]
    then
        rm -f $T2p5
        if [ -f $HOME/at-one-off/one-off-at-index ]
        then
            # still faster but avoids grep using so much memory
            # which is apparently needed on our ancient server:-)
            t2_l=`wc -l $T2`
            rm -f $T2p5
            for tfile in `cat $HOME/at-one-off/one-off-at-index` 
            do
                grep -v -f $HOME/at-one-off/$tfile $T2 >$T2p5
                cp $T2p5 $T2
            done
            t2p5_l=`wc -l $T2p5`
            echo "Started with $t2_l ended up with $t2p5_l"
        elif [ -f $HOME/at-one-off/one-off-at-teks ]
        then
            # This is quicker but requires access to plain TEKs
            t2_l=`wc -l $T2`
            grep -v -f $HOME/at-one-off/one-off-at-teks $T2 >$T2p5
            t2p5_l=`wc -l $T2p5`
            echo "Started with $t2_l ended up with $t2p5_l"
        else
            # This is waaay slower but safer, as we don't need to
            # distribute real TEKs. Mind you, when I say "safe"
            # I've not tested it fully, because it's so slow;-)
            for line in `cat $T2` 
            do 
                ltek=`echo $line | awk -F\' '{print $2}'`
                lhash=`echo -n $ltek | openssl sha256 | awk '{print $2}'`
                hit=`grep -c $lhash $TOP/at-one-off/one-off-at-hteks`
                if [[ "$hit" == "0" ]]
                then
                    echo $line >>$T2p5
                fi
           done
        fi
        mv $T2p5 $T2
    elif [[ "$REDUCE" == "yes" && "$country" == "ie" ]]
    then
        # for Ireland and NI, we re-analyse all TEKs from
        # the island, and end up with files that contain
        # only those first seen on the relevant side of
        # the border, so we'll grep away the rest of the
        # TEKs in $T2 based on that
        # first, we re-generate those files - the script
        # we're using is a bit slow, but can be optimsed
        # later
        if [[ ! -f $IETEKS || ! -f $UKNITEKS ]]
        then
            $TOP/ie-ukni-sort.sh $IETEKS $UKNITEKS
        fi
        rm -f $T2p5
        grep -v -f $UKNITEKS $T2 >$T2p5
        mv $T2p5 $T2
    elif [[ "$REDUCE" == "yes" && "$country" == "ukni" ]]
    then
        if [[ ! -f $IETEKS || ! -f $UKNITEKS ]]
        then
            $TOP/ie-ukni-sort.sh $IETEKS $UKNITEKS
        fi
        rm -f $T2p5
        grep -v -f $IETEKS $T2 >$T2p5
        mv $T2p5 $T2
    fi

    # Had to change the $1*600 below to ($1-$1%144)*600 below due to some epoch
    # values that are not 00:00Z for that day. May have seen that before but it
    # happened for sure for CZ on Oct 14 2020 where we had 7 odd epoch values.
    # I don't know if that's down to the server or to the odd values being 
    # uploaded by handsets there.
    #grep period $T2 | sort | uniq | awk -F\' '{print $3}' | awk -F, '{print 600*$1}' | sort -n | uniq -c | awk '{print $1","$2}' >$T3
    # This started to get verrrry slow for larger files
    #grep period $T2 | sort | uniq | awk -F\' '{print $3}' | awk -F, '{print 600*($1-$1%144)}' | sort -n | uniq -c | awk '{print $1","$2}' >$T3
    grep period $T2 | awk -F\' '{print $3}' | awk -F, '{print 600*($1-$1%144)}' | sort -n | uniq -c | awk '{print $1","$2}' >$T3
    # So tried this...
    # grep period $T2 | awk -F\' '{print $3}' | awk -F, '{print 600*($1-$1%144)}' >$T2p6
    # sort -n $T2p6 | uniq -c | awk '{print $1","$2}' >$T3
    rm -f $T2 $T2p6

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

        if [[ "$REDUCE" == "yes" ]]
        then
            # Handle our exceptions for weird counters, we need to decode for that
            if [[ "$country" == "ch" && $cnt -ge 10 && $tm -le $chstoppedfakes ]]
            then
                cnt=$((cnt-10))
            fi
            if [[ "$country" == "de" && $tm -lt $dex10till ]]
            then
                cnt=$((cnt/10))
            elif [[ "$country" == "de" && $tm -ge $dex10till ]]
            then
                cnt=$((cnt/5))
            fi
        fi

        # month and day can have leading zeros - the tricks below
        # zap those:-)
        if [[ "$do_who" == "yes" ]]
        then
            grep ",$ucountry," $WHO_WORLD_CASES | \
                grep "^$year-$month-$day" | \
                awk -F, '{print "'$country','$td','$cnt',"$5}' >>$targfile
        elif [[ "$do_ecdc" == "yes" ]]
        then
            grep ",$ucountry," $ECDC_WORLD_CASES | \
                grep ",$((10#$day)),$((10#$month)),$year" | \
                awk -F, '{print "'$country','$td','$cnt',"$5}' >>$targfile
        elif [[ "$do_jhu" == "yes" ]]
        then
            # some dates can be missing or malformed in the JHU data for some countries/regions
            gotJHU=`grep -c "^$country,$year-$month-$day" $JHU_WORLD_CASES` 
            if [[ "$gotJHU" != 0 ]]
            then
                grep "^$country,$year-$month-$day" $JHU_WORLD_CASES | \
                    awk -F, '{print "'$country','$td','$cnt',"$4}' >>$targfile
            else
                echo "$country,$td,$cnt,0" >>$targfile
            fi
        else
            echo "No idea what country count to use - exiting"
            exit 99
        fi
    done
    rm -f $T3
    # as the cases file can be 24 hours old, the TEKs can get
    # ahead of that, so we'll output an empty cases number in
    # that case, we won't see $td in $OUTDIR/$country-$TARGET yet so
    # add in a line in that case - that should only happend 
	# for the most recent day, so this can be outside the
	# loop
    if [[ "$td" != "" ]]
    then
        addedteks=`grep -c $td $targfile`
        if [[ "$addedteks" == "0" ]]
        then
        echo "$country,$td,$cnt," >>$targfile
        fi
    fi

    if [[ "$dosplice" == "True" ]]
    then
        # take the 14 last lines of new file and everything 
        # earlier from old file
        head -n -14 $targfile-b4-$NOW >$T4
        cp $targfile $targfile-aftr-$NOW
        tail -14 $targfile >$T5
        cat $T4 $T5 >$targfile
        rm -f $T4 $T5
    fi

done



