#!/bin/bash

# set -x

# script to grab TEKs for various places, and stash 'em

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${DOCROOT:='/var/www/tact/tek-counts/'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$TOP/data"}
x=${ARCHIVE:="$DATADIR/all-zips"}
x=${DAILIES:="$DATADIR/dailies"}
x=${DAILIES2:="$DATADIR/dailies2"}

TEK_DECODE="$TOP/tek_file_decode.py"
TEK_TIMES="$TOP/tek_times.sh"
TEK_REPORT="$TOP/tek_report.sh"
DE_CFG_DECODE="$TOP/de_tek_cfg_decode.py"

CURL="/usr/bin/curl -s"
UNZIP="/usr/bin/unzip"

# The services here could generally be trusted to not provide (or
# cause us to derive) "bad" file names (e.g. "/etc/passwd" or 
# "../../tek_survey.sh") that might do damage. However, now that
# a number of those services are being decommissioned, we should
# consider what'd happen if a domain name were in future snagged
# by a bad actor, or were just re-used for something that caused
# us a problem. So we'll sanitise all file names we create down 
# to just alphanumerics plus "-", "_" and "." which seems to be all we 
# need for the real services.
# We should call this anytime we create a file based on a string
# we've downloaded from a service.
function sanitise_filename()
{
    fname=$1
    echo ${fname//[^a-zA-Z0-9_\-.]/}
}

# same for what we want to be a decimal number string
function sanitise_decimal()
{
    num=$1
    echo ${num//[^0-9]/}
}


function whenisitagain()
{
    date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)


# For the log

echo "======================"
echo "======================"
echo "======================"
echo "Running $0 at $NOW"

mkdir -p $DATADIR/$NOW 

if [ ! -d $DATADIR/$NOW ]
then
    echo "Failed to create $DATADIR/$NOW"
    # maybe try get data in /tmp  
    cd /tmp
else
    cd $DATADIR/$NOW
fi

# Ireland

# used to notify us that something went wrong
IE_CANARY="$ARCHIVE/ie-canary"
IE_BASE="https://app.covidtracker.ie/api"
IE_CONFIG="$IE_BASE/settings/"
IE_RTFILE="$HOME/ie-refreshToken.txt"

$CURL --output ie-cfg.json -L $IE_CONFIG

echo "======================"
echo ".ie TEKs"

if [ ! -f $IE_RTFILE ]
then
    if [ ! -f $IE_CANARY ]
    then
        echo "<p>Skipping .ie because refreshToken access failed at $NOW.</p>" >$IE_CANARY
    fi
    echo "Skipping .ie because refreshToken access failed at $NOW.</p>" 
else 

    refreshToken=`cat $IE_RTFILE`
    tok_json=`$CURL -s -L $IE_BASE/refresh -H "Authorization: Bearer $refreshToken" -d "{}"`
    if [[ "$?" != 0 ]]
    then
        if [ ! -f $IE_CANARY ]
        then
            echo "<p>Skipping .ie because refreshToken use failed at $NOW.</p>" >$IE_CANARY
        fi
        echo "Skipping .ie because refreshToken use failed at $NOW."
    else
    
        newtoken=`echo $tok_json | awk -F: '{print $2}' | sed -e 's/"//g' | sed -e 's/}//'`
        if [[ "$newtoken" == "" ]]
        then
            echo "No sign of an authToken, sorry - Skipping .ie"
        else
            # get stats
            $CURL -s -L "$IE_BASE/stats" -o ie-stats.json -H "Authorization: Bearer $newtoken"

            index_str=`$CURL -s -L "$IE_BASE/exposures/?since=0&limit=1000" -H "Authorization: Bearer $newtoken"` 
            echo "Irish index string: $index_str"
            iefiles=""
            for row in $(echo "${index_str}" | jq -r '.[] | @base64'); 
            do
                _jq() {
                         echo ${row} | base64 --decode | jq -r ${1}
                }
                iefiles="$iefiles $(_jq '.path')"
            done
            for iefile in $iefiles
            do
                echo "Getting $iefile"
                iebname_raw=`basename $iefile`
                iebname=$(sanitise_filename $iebname_raw)
                $CURL -s -L "$IE_BASE/data/$iefile" --output ie-$iebname -H "Authorization: Bearer $newtoken"
                if [[ $? == 0 ]]
                then
                    # we should be good now, so remove canary
                    rm -f $IE_CANARY
                    if [ ! -f $ARCHIVE/ie-$iebname ]
                    then
                        cp ie-$iebname $ARCHIVE
                    fi
                    # try unzip and decode
                    #if [[ "$DODECODE" == "yes" ]]
                    #then
                        #$UNZIP "ie-$iebname" >/dev/null 2>&1
                        #if [[ $? == 0 ]]
                        #then
                            #tderr=`mktemp /tmp/tderrXXXX`
                            #$TEK_DECODE >/dev/null 2>$tderr 
                            #new_keys=$?
                            #total_keys=$((total_keys+new_keys))
                            #tderrsize=`stat -c%s $tderr`
                            #if [[ "$tderrsize" != '0' ]] 
                            #then
                                #echo "tek-decode error processing ie-$iebname"
                            #fi
                            #rm -f $tderr
                        #fi
                        #rm -f export.bin export.sig
                        #chunks_down=$((chunks_down+1))
                    #fi
                else
                    echo "Error fetching ie-$iebname"
                fi
            done
    
        fi
    fi
fi

# Northern Ireland

# Same setup as Ireland app-wise

# NI is a region of the UK, so we'll use the prefix "ukni-" 

NI_BASE="https://app.stopcovidni.hscni.net/api"
NI_CONFIG="$NI_BASE/settings/"

# Northern Ireland

# used to notify us that something went wrong
NI_CANARY="$ARCHIVE/ukni-canary"
NI_RTFILE="$HOME/ukni-refreshToken.txt"

$CURL --output ukni-cfg.json -L $NI_CONFIG

echo "======================"
echo "Northern Ireland TEKs"

if [ ! -f $NI_RTFILE ]
then
    if [ ! -f $NI_CANARY ]
    then
        echo "<p>Skipping Northern Ireland because refreshToken access failed at $NOW.</p>" >$NI_CANARY
    fi
    echo "Skipping Northern Ireland because refreshToken access failed at $NOW.</p>" 
else 

    refreshToken=`cat $NI_RTFILE`
    tok_json=`$CURL -s -L $NI_BASE/refresh -H "Authorization: Bearer $refreshToken" -d "{}"`
    if [[ "$?" != 0 ]]
    then
        if [ ! -f $NI_CANARY ]
        then
            echo "<p>Skipping Northern Ireland because refreshToken use failed at $NOW.</p>" >$NI_CANARY
        fi
        echo "Skipping Northern Ireland because refreshToken use failed at $NOW."
    else
    
        newtoken=`echo $tok_json | awk -F: '{print $2}' | sed -e 's/"//g' | sed -e 's/}//'`
        if [[ "$newtoken" == "" ]]
        then
            echo "No sign of an authToken, sorry - Skipping Northern Ireland"
        else
            # grab stats
            $CURL -s -L "$NI_BASE/stats" -o ukni-stats.json -H "Authorization: Bearer $newtoken"

            index_str=`$CURL -s -L "$NI_BASE/exposures/?since=0&limit=1000" -H "Authorization: Bearer $newtoken"` 
            echo "Northern Irish index string: $index_str"
            nifiles=""
            for row in $(echo "${index_str}" | jq -r '.[] | @base64'); 
            do
                check401=`echo ${row} | base64 --decode`
                if [[ "$check401" == "401" ]]
                then
                    echo "401 detected in JSON answer - oops"
                    break
                fi
                _jq() {
                         echo ${row} | base64 --decode | jq -r ${1}
                }
                nifiles="$nifiles $(_jq '.path')"
            done
            for nifile in $nifiles
            do
                echo "Getting $nifile"
                nibname_raw=`basename $nifile`
                nibname=$(sanitise_filename $nibname_raw)
                $CURL -s -L "$NI_BASE/data/$nifile" --output ukni-$nibname -H "Authorization: Bearer $newtoken"
                if [[ $? == 0 ]]
                then
                    # we should be good now, so remove canary
                    rm -f $NI_CANARY
                    if [ ! -f $ARCHIVE/ukni-$nibname ]
                    then
                        cp ukni-$nibname $ARCHIVE
                    fi
                    # try unzip and decode
                    #if [[ "$DODECODE" == "yes" ]]
                    #then
                        #$UNZIP "ukni-$nibname" >/dev/null 2>&1
                        #if [[ $? == 0 ]]
                        #then
                            #$TEK_DECODE >/dev/null
                            #new_keys=$?
                            #total_keys=$((total_keys+new_keys))
                        #fi
                        #rm -f export.bin export.sig
                        #chunks_down=$((chunks_down+1))
                    #fi
                else
                    echo "Error fetching ukni-$nibname"
                fi
            done
    
        fi
    fi
fi

# italy
echo "======================"
echo ".it TEKs"

IT_BASE="https://get.immuni.gov.it/v1/keys"
IT_INDEX="$IT_BASE/index"
IT_CONFIG="https://get.immuni.gov.it/v1/settings?platform=android&build=1"

index_str=`$CURL -L $IT_INDEX`
raw_bottom_chunk_no=`echo $index_str | awk '{print $2}' | sed -e 's/,//'`
raw_top_chunk_no=`echo $index_str | awk '{print $4}' | sed -e 's/}//'`

bottom_chunk_no=$(sanitise_decimal $raw_bottom_chunk_no)
top_chunk_no=$(sanitise_decimal $raw_top_chunk_no)

echo "Bottom: $bottom_chunk_no, Top: $top_chunk_no"

if [[ "$bottom_chunk_no" != "" && "$top_chunk_no" != "" && $((top_chunk_no > bottom_chunk_no)) ]]
then
    total_keys=0
    chunks_down=0
    chunk_no=$bottom_chunk_no
    while [ $chunk_no -le $top_chunk_no ]
    do
        echo "Getting it-$chunk_no.zip"
        $CURL -L "$IT_BASE/{$chunk_no}" --output it-$chunk_no.zip
        if [[ $? == 0 ]]
        then
            if [ ! -f $ARCHIVE/it-$chunk_no.zip ]
            then
                cp it-$chunk_no.zip $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "it-$chunk_no.zip" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
            #fi
        else
            echo "Error fetching it-$chunk_no.zip"
        fi
        chunk_no=$((chunk_no+1))
        chunks_down=$((chunks_down+1))
    done
else
    echo "Skipping Italy TEKS due to malformed chunk nos"
fi

$CURL -L $IT_CONFIG --output it-cfg.json

echo "======================"
echo ".de TEKs"
# Germany 

DE_BASE="https://svc90.main.px.t-online.de/version/v1/diagnosis-keys/country/DE"
DE_INDEX="$DE_BASE/date"

# .de index format is like: ["2020-06-23","2020-06-24"]
index_str=`$CURL -L $DE_INDEX` 
echo "German index string: $index_str"
dedates=`echo $index_str \
                | sed -e 's/\[//' \
                | sed -e 's/]//' \
                | sed -e 's/"//g' \
                | sed -e 's/,/ /g' `
for dedate in $dedates
do
    sane_dedate=$(sanitise_filename $dedate)
    $CURL -L "$DE_BASE/date/$dedate" --output de-$sane_dedate.zip
    if [[ $? == 0 ]]
    then
        echo "Got de-$sane_dedate.zip"
        if [ ! -f $ARCHIVE/de-$sane_dedate.zip ]
        then
            cp de-$sane_dedate.zip $ARCHIVE
        fi
        # try unzip and decode
        #if [[ "$DODECODE" == "yes" ]]
        #then
            #$UNZIP "de-$sane_dedate.zip" >/dev/null 2>&1
            #if [[ $? == 0 ]]
            #then
                #$TEK_DECODE >/dev/null
                #new_keys=$?
                #total_keys=$((total_keys+new_keys))
            #fi
            #rm -f export.bin export.sig
            #chunks_down=$((chunks_down+1))
        #fi
    else
        echo "Error fetching de-$sane_dedate.zip"
    fi

    # Now check for hourly zips - it's ok that we have dups as we 
    # will use "sort|uniq" before counting and it's nice to have
    # all the zips even if we have >1 copy
    hours_str=`$CURL -L "$DE_BASE/date/$dedate/hour"`
    dehours=`echo $hours_str \
                    | sed -e 's/\[//' \
                    | sed -e 's/]//' \
                    | sed -e 's/"//g' \
                    | sed -e 's/,/ /g' `
    if [[ "$dehours" != "" ]]
    then
        echo ".de on $dedate has hours: $dehours"
    fi
    for dehour in $dehours
    do
        sane_dehour=$(sanitise_filename $dehour)
        $CURL -L "$DE_BASE/date/$dedate/hour/$dehour" --output de-$sane_dedate-$sane_dehour.zip
        if [[ $? == 0 ]]
        then
            echo "Got de-$sane_dedate-$sane_dehour.zip"
            if [ ! -f $ARCHIVE/de-$sane_dedate-$sane_dehour.zip ]
            then
                cp de-$sane_dedate-$sane_dehour.zip $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "de-$sane_dedate-$sane_dehour.zip" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        else
            echo "Error fetching de-$sane_dedate-$sane_dehour.zip"
        fi
    done
done

# lastly, check for today in case there are hourlies already
# that are not in the date index
# when is today? that's in UTC, so I may be a TZ off for an hour 
# or two
today=`date -u +%Y-%m-%d`
echo "today: Checking .de for today's hourlies $today"
# Now check for hourly zips - it's ok that we have dups as we 
# will use "sort|uniq" before counting and it's nice to have
# all the zips even if we have >1 copy
hours_str=`$CURL -L "$DE_BASE/date/$today/hour"`
dehours=`echo $hours_str \
                | sed -e 's/\[//' \
                | sed -e 's/]//' \
                | sed -e 's/"//g' \
                | sed -e 's/,/ /g' `
echo "today: Checking .de for today's hourlies dehours: $dehours"
if [[ "$dehours" != "" ]]
then
    echo ".de on $today has hours: $dehours"
fi
for dehour in $dehours
do
    sane_dehour=$(sanitise_filename $dehour)
    $CURL -L "$DE_BASE/date/$today/hour/$dehour" --output de-$today-$sane_dehour.zip
    if [[ $? == 0 ]]
    then
        echo "Got de-$today-$sane_dehour.zip"
        if [ ! -f $ARCHIVE/de-$today-$sane_dehour.zip ]
        then
            cp de-$today-$sane_dehour.zip $ARCHIVE
        fi
        # try unzip and decode
        #if [[ "$DODECODE" == "yes" ]]
        #then
            #$UNZIP "de-$today-$sane_dehour.zip" >/dev/null 2>&1
            #if [[ $? == 0 ]]
            #then
                #$TEK_DECODE >/dev/null
                #new_keys=$?
                #total_keys=$((total_keys+new_keys))
            #fi
            #rm -f export.bin export.sig
            #chunks_down=$((chunks_down+1))
        #fi
    else
        echo "Error fetching de-$today-$sane_dehour.zip"
    fi
done


DE_CONFIG="https://svc90.main.px.t-online.de/version/v1/configuration/country/DE/app_config"
$CURL -L $DE_CONFIG --output de-cfg.zip

# not that interesting to decode these each time now
#if [ -f de-cfg.zip ]
#then
    #$UNZIP de-cfg.zip
    #if [[ $? == 0 ]]
    #then
        #echo ".de config:"
        #$DE_CFG_DECODE 
        #rm -f export.bin export.sig
    #fi 
#fi
DE_KEYS="https://github.com/micb25/dka/raw/master/data_CWA/diagnosis_keys_statistics.csv"
$CURL -L $DE_KEYS --output de-keys.csv

echo "======================"
echo ".ch TEKs"

# Switzerland

# Apparently the .ch scheme is to use the base URL below with a filename
# of the milliseconds version of time_t for midnight on the day concerned
# (What? Baroque? Nah - just normal nerds:-)
# so https://www.pt.bfs.admin.ch/v1/gaen/exposed/1592611200000 works for
# june 20
CH_BASE="https://www.pt.bfs.admin.ch/v1/gaen/exposed"
now=`date +%s`
today_midnight="`date -d "00:00:00Z" +%s`000"

# Swiss cgs & stats
# The GAEN config
CH_CONFIG="https://www.pt-a.bfs.admin.ch/v1/config?appversion=1&osversion=ios&buildnr=1"
# The count of active users 
CH_ACTIVES="https://www.bfs.admin.ch/bfsstatic/dam/assets/orderNr:ds-q-14.01-SwissCovidApp-01.2/master"
# The count of covidcodes uploaded
CH_CODES="https://www.bfs.admin.ch/bfsstatic/dam/assets/orderNr:ds-q-14.01-SwissCovidApp-03/master"
# Same but weekly - we don't get this now, just still here 'cause I accidentally grabbed it for
# a day or two;-)
CH_WEEKLY_CODES="https://www.bfs.admin.ch/bfsstatic/dam/assets/orderNr:ds-q-14.01-SwissCovidApp-04/master"

# it turns out (personal communication) that the .ch scheme is to change
# the content of files but re-use the file name. I think that means that
# files that are less than 14 days old may be updated, with newly uploaded
# TEKs, so for each run, we'll download all 14 files. 
# (Feck it, we'll go for 15:-)

# one day in milliseconds
day=$((60*60*24*1000))

for fno in {0..15}
do
    echo "Doing .ch file $fno" 
    midnight=$((today_midnight-fno*day))
    # CH started returning ascii errors on 2022-06-04
    chhttpcode=`$CURL -L "$CH_BASE/$midnight" -s -w "%{http_code}" -o ch-$midnight.txt`
    if [[ "$http_code" != "200" ]]
    then
        echo "CH error http response code: $http_code for ch-$midnight"
        continue;
    fi
    $CURL -L "$CH_BASE/$midnight" --output ch-$midnight.zip
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .ch sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s ch-$midnight.zip ]
        then
            echo "Empty or non-existent downloaded Swiss file: ch-$midnight.zip ($fno)"
        else
            if [ ! -f $ARCHIVE/ch-$midnight.zip ]
            then
                echo "New .ch file $fno ch-$midnight" 
                cp ch-$midnight.zip $ARCHIVE
            elif ((`stat -c%s "ch-$midnight.zip"`>`stat -c%s "$ARCHIVE/ch-$midnight.zip"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .ch file $fno ch-$midnight" 
                cp ch-$midnight.zip $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "ch-$midnight.zip" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        fi
    else
        echo "Error fetching ch-$midnight.zip (file $fno)"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

$CURL -L $CH_CONFIG --output ch-cfg.json
$CURL -L $CH_ACTIVES --output ch-actives.json
$CURL -L $CH_CODES --output ch-codes.json

# This URL has the number of active users of the app
ACTIVES_URL="https://www.bfs.admin.ch/bfsstatic/dam/assets/orderNr:ds-q-14.01-SwissCovidApp-01/master"
$CURL -L $ACTIVES_URL -o ch-actives.json
# This URL contains text that says how many people uploaded codes (presumably after a positive test)
# Very oddly, the TLS server cert for that uses some oddball CA unknown to curl or wget 
# (that's CN=QuoVadis Global SSL ICA G3,O=QuoVadis Limited,C=BM) so we'll ignore cert checks
# just this once;-)
CODES_URL="https://www.experimental.bfs.admin.ch/expstat/en/home/innovative-methods/swisscovid-app-monitoring.html"
$CURL --insecure -L $CODES_URL -o ch-codes.html

echo "======================"
echo ".pl TEKs"

# Poland

# yes - we end up with two slashes between hostname and path for some reason!
PL_BASE="https://exp.safesafe.app/" 
PL_CONFIG="dunno; get later"

plzips=`$CURL -L "$PL_BASE/index.txt" | sed -e 's/\///g'`
plhttpcode=`$CURL -L "$PL_BASE/index.txt" -s -w "%{http_code}" -o pl-index.txt`
if [[ "$plhttpcode" != "200" ]]
then
    echo "PL index failure, HTTP response $plhttpcode"
else
    for plzip in $plzips
    do
        echo "Getting $plzip"
        sane_plzip=$(sanitise_filename $plzip)
        $CURL -L "$PL_BASE/$plzip" --output pl-$sane_plzip
        if [[ $? == 0 ]]
        then
            if [ ! -s pl-$sane_plzip ]
            then
                echo "Empty or non-existent Polish file: pl-$sane_plzip"
            else
                if [ ! -f $ARCHIVE/pl-$sane_plzip ]
                then
                    cp pl-$sane_plzip $ARCHIVE
                fi
                # try unzip and decode
                #if [[ "$DODECODE" == "yes" ]]
                #then
                    #$UNZIP "pl-$sane_plzip" >/dev/null 2>&1
                    #if [[ $? == 0 ]]
                    #then
                        #$TEK_DECODE >/dev/null
                        #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                    #fi
                    #rm -f export.bin export.sig
                    #chunks_down=$((chunks_down+1))
                #fi
            fi
        else
            echo "Error fetching pl-$sane_plzip"
        fi
    done
fi

# PL config, still don't have a good URL but...
# to get config needs a post to firebaseremoteconfig.googleapis.com with a ton of ids/authentication.  response is 
#   {
#       "appName": "pl.gov.mc.protegosafe",
#       "entries": {
#           "diagnosisKeyDownloadConfiguration": "{\"timeoutMobileSeconds\":120,\"timeoutWifiSeconds\":60,\"retryCount\":2}",
#           "exposureConfiguration": "{\"minimumRiskScore\":4,\"attenuationScores\":[2,5,6,7,8,8,8,8],\"attenuationWeigh\":50,\"daysSinceLastExposureScores\":[7,8,8,8,8,8,8,8],\"daysSinceLastExposureWeight\":50,\"durationScores\":[0,5,6,7,8,8,8,8],\"durationWeight\":50,\"transmissionRiskScores\":[8,8,8,8,8,8,8,8],\"transmissionRiskWeight\":50,\"durationAtAttenuationThresholds\":[48,58]}",
#           "provideDiagnosisKeysWorkerConfiguration": "{\"repeatIntervalInMinutes\":360,\"backoffDelayInMinutes\":10}",
#           "riskLevelConfiguration": "{\"maxNoRiskScore\":0,\"maxLowRiskScore\":1499,\"maxMiddleRiskScore\":2999}"
#       },
#       "state": "UPDATE"
#   }


echo "======================"
echo ".dk TEKs"

# Denmark

DK_HOST="app.smittedtop.dk"
DK_BASE="https://$DK_HOST/API/v1/diagnostickeys"
DK_CONFIG="$DK_BASE/exposureconfiguration"

try_dk="yes"
# The DK_HOST for now gives NXDOMAIN so check for that
nxd=`dig $DK_HOST | grep status | grep NXDOMAIN`
if [[ "$nxd" != "" ]]
then
    echo "$DK_HOST gives NXDOMAIN now"
    try_dk="no"
else
    # the DK config needs a weird authorization header
    $CURL -o dk-cfg.json -D - -L $DK_CONFIG -H "Authorization_Mobile: 68iXQyxZOy"
    dkcfg_res=$?
    if [[ "$dkcfg_res" != "0" ]]
    then
        # since there's a version number in the DK_BASE that'll
        # presumably change sometime so check to see if that or
        # some other failure happened
        # my guess is I might notice this easier than the
        # absence of the config file
        echo "Failed to get DK config - curl returned $dkcfg_res"
        # we only do the zip files if the above worked - in fact they've
        # turned this one off now (20220403)
        try_dk="no"
    fi
fi

if [[ "$try_dk" == "no" ]]
then
    echo "No sign of dk-cfg so won't go for TEKs"
else

# For DK, we grab $DK_Base/<date>.0.zip and there's an HTTP header
# ("FinalForTheDay: False") in the response to us if we still need 
# to get $DK_BASE/<date>.1.zip
# we'll do that for the last 14 days then archive any zips that are
# new or bigger than before
oneday=$((60*60*24))
end_time_t=`date -d 00:00 +%s`
start_time_t=$((`date -d 00:00 +%s`-14*oneday))
the_time_t=$start_time_t
while [ $the_time_t -lt $end_time_t ]
do
    the_time_t=$((the_time_t+oneday))
    the_day=`date -d @$the_time_t +%Y-%m-%d`
    echo "Doing $the_day"
    more_to_come="True"
    dk_chunk=0
    while [[ "$more_to_come" != "" ]]
    do
        the_zip_name="$the_day:$dk_chunk.zip"
        # colons in file names is a bad plan for some OSes
        the_local_zip_name="dk-$the_day.$dk_chunk.zip"
        echo "Fetching $the_zip_name" 
        response_headers=`$CURL -o $the_local_zip_name -D - -L "$DK_BASE/$the_zip_name" -H "Authorization_Mobile: 68iXQyxZOy"`

        dkzip_res=$?
        if [[ "$dkzip_res" == "0" ]]
        then
            if [ ! -s $the_local_zip_name ]
            then
                # for june 28th we seem to get an endless stream of zero-sized non-final files
                echo "Got empty file for $the_zip_name" 
                more_to_come=""
            else
                echo "Got $the_zip_name" 
                echo "RH: $response_headers"
                more_to_come=`echo $response_headers | grep "FinalForTheDay: False"`
                if [[ "$more_to_come" != "" ]]
                then
                    # check in case of a 404 - for today's :0 file we do get FinalForTheDay: False
                    # but then a 404 for chunk :1 - I guess they're not sure that the :0 is is
                    # final 'till the day's over, but that's a bit iccky
                    more_to_come=`echo $response_headers | grep "HTTP/1.1 404 Not Found"`
                fi
                dk_chunk=$((dk_chunk+1))
                if [ ! -f $ARCHIVE/$the_local_zip_name ]
                then
                    echo "New .dk file $the_local_zip_name"
                    cp $the_local_zip_name $ARCHIVE
                elif ((`stat -c%s "$the_local_zip_name"`>`stat -c%s "$ARCHIVE/$the_local_zip_name"`));then
                    # if the new one is bigger than archived, then archive new one
                    echo "Updated/bigger .dk file $the_local_zip_name"
                    cp $the_local_zip_name $ARCHIVE
                fi
                # try unzip and decode
                #if [[ "$DODECODE" == "yes" ]]
                #then
                    #$UNZIP "$the_local_zip_name" >/dev/null 2>&1
                    #if [[ $? == 0 ]]
                    #then
                        #$TEK_DECODE >/dev/null
                        #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                    #fi
                    #rm -f export.bin export.sig
                    #chunks_down=$((chunks_down+1))
                #fi
            fi
        else
            echo "Didn't get a $the_zip_name" 
            more_to_come=""
        fi
        # let's not be too insistent
        sleep 1

    done    
done

fi

echo "======================"
echo ".at Teks"

AT_SOURCE="https://github.com/austrianredcross/stopp-corona-android"
AT_CONFIG="https://app.prod-rca-coronaapp-fd.net/Rest/v8/configuration"
AT_BASE="https://cdn.prod-rca-coronaapp-fd.net/"
AT_INDEX="$AT_BASE/exposures/at/index.json"

$CURL -L $AT_CONFIG \
    -H "authorizationkey: 64165cfc5a984bb09e185b6258392ecb" \
    -H "x-appid: at.roteskreuz.stopcorona" \
    -o at.config.json
$CURL -L $AT_INDEX \
    -H "authorizationkey: 64165cfc5a984bb09e185b6258392ecb" \
    -H "x-appid: at.roteskreuz.stopcorona" \
    -o at.index.json

if [ -f at.index.json ]
then

    zipnames=`cat at.index.json | sed -e 's/\["/\n/g' | sed -e 's/"\].*//g' | grep exposure`
    for zipname in $zipnames
    do
        echo "Fetching .at $zipname"
        zipurl=https://cdn.prod-rca-coronaapp-fd.net/$zipname
        the_zip_name=`basename $zipname`
        the_local_zip_name=$(sanitise_filename "at-$the_zip_name")
        $CURL -L $zipurl \
            -H "authorizationkey: 64165cfc5a984bb09e185b6258392ecb" \
            -H "x-appid: at.roteskreuz.stopcorona" \
            -o $the_local_zip_name
    
        atzip_res=$?
        if [[ "$atzip_res" == "0" ]]
        then
            if [ ! -s $the_local_zip_name ]
            then
                echo "Got empty file for $the_zip_name" 
                more_to_come=""
            else
                echo "Got $the_zip_name" 
                at_chunk=$((at_chunk+1))
                if [ ! -f $ARCHIVE/$the_local_zip_name ]
                then
                    echo "New .at file $the_local_zip_name"
                    cp $the_local_zip_name $ARCHIVE
                elif ((`stat -c%s "$the_local_zip_name"`>`stat -c%s "$ARCHIVE/$the_local_zip_name"`));then
                    # if the new one is bigger than archived, then archive new one
                    echo "Updated/bigger .at file $the_local_zip_name"
                    cp $the_local_zip_name $ARCHIVE
                fi
                # try unzip and decode
                #if [[ "$DODECODE" == "yes" ]]
                #then
                    #$UNZIP "$the_local_zip_name" >/dev/null 2>&1
                    #if [[ $? == 0 ]]
                    #then
                        #$TEK_DECODE >/dev/null
                        #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                    #fi
                    #rm -f export.bin export.sig
                    #chunks_down=$((chunks_down+1))
                #fi
            fi
        else
            echo "Didn't get a $the_zip_name" 
            more_to_come=""
        fi
        # let's not be too insistent
        sleep 1

    done
fi

echo "======================"
echo ".lv Teks"

# Latvia

LV_BASE="https://apturicovid-files.spkc.gov.lv"
LV_CONFIG="$LV_BASE/exposure_configurations/v1/android.json"
LV_INDEX="$LV_BASE/dkfs/v1/index.txt"
$CURL -o lv-cfg.json -L "$LV_CONFIG"
if [[ "$?" != 0 ]]
then
    echo "Error grabbing .lv config: $LV_CONFIG"
fi
response_headers=`$CURL -D - -o lv-index.txt -L "$LV_INDEX" -i`
if [[ "$?" == 0 ]]
then
    clzero=`echo $response_headers | grep -c "Content-Length: 0"`
    if [[ "$clzero" == "1" ]]
    then
        echo "no .lv TEKs at $NOW"
    else
        urls2get=`cat lv-index.txt | grep https`
        for theurl in $urls2get
        do
            the_zip_name=$theurl
            the_local_zip_name=$(sanitise_filename "lv-`basename $theurl`")
            $CURL -L $theurl -o $the_local_zip_name
            lvzip_res=$?
            if [[ "$lvzip_res" == "0" ]]
            then
                if [ ! -s $the_local_zip_name ]
                then
                    echo "Got empty file for $the_zip_name" 
                else
                    echo "Got $the_zip_name" 
                    lv_chunk=$((lv_chunk+1))
                    if [ ! -f $ARCHIVE/$the_local_zip_name ]
                    then
                        echo "New .lv file $the_local_zip_name"
                        cp $the_local_zip_name $ARCHIVE
                    elif ((`stat -c%s "$the_local_zip_name"`>`stat -c%s "$ARCHIVE/$the_local_zip_name"`));then
                        # if the new one is bigger than archived, then archive new one
                        echo "Updated/bigger .lv file $the_local_zip_name"
                        cp $the_local_zip_name $ARCHIVE
                    fi
                    # try unzip and decode
                    #if [[ "$DODECODE" == "yes" ]]
                    #then
                        #$UNZIP "$the_local_zip_name" >/dev/null 2>&1
                        #if [[ $? == 0 ]]
                        #then
                            #$TEK_DECODE >/dev/null
                            #new_keys=$?
                            #total_keys=$((total_keys+new_keys))
                        #fi
                        #rm -f export.bin export.sig
                        #chunks_down=$((chunks_down+1))
                    #fi
                fi
            else
                echo "Didn't get a $the_zip_name" 
            fi
            # let's not be too insistent
            sleep 1
        done
    fi
fi

echo "======================"
echo ".es TEKs"

# Spain

# a friend sent me the apk for the spanish app that's being tested just now (in
# the canaries i think).  to get the config settings use GET
# https://dqarr2dc0prei.cloudfront.net/configuration/settings to get TEKs use GET
# https://dqarr2dc0prei.cloudfront.net/dp3t/v1/gaen/exposed/1594512000000 (which
# responds with 204 No Content) and GET
# https://dqarr2dc0prei.cloudfront.net/dp3t/v1/gaen/exposed/1594425600000 which
# gives a TEK file (signed as a demo i think)

# Seems to be same as .ch scheme, see the comments there
# (Yeah, we should make a function, can do it later, but
# we should also start to use a real DB maybe so TBD)

ES_BASE="https://radarcovid.covid19.gob.es/dp3t/v1/gaen/exposed"
now=`date +%s`
today_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

for fno in {0..14}
do
    echo "Doing .es file $fno" 
    midnight=$((today_midnight-fno*day))
    $CURL -L "$ES_BASE/$midnight" --output es-$midnight.zip
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .es sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s es-$midnight.zip ]
        then
            echo "Empty or non-existent downloaded Spanish file: es-$midnight.zip ($fno)"
        else
            if [ ! -f $ARCHIVE/es-$midnight.zip ]
            then
                echo "New .es file $fno es-$midnight" 
                cp es-$midnight.zip $ARCHIVE
            elif ((`stat -c%s "es-$midnight.zip"`>`stat -c%s "$ARCHIVE/es-$midnight.zip"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .es file $fno es-$midnight" 
                cp es-$midnight.zip $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "es-$midnight.zip" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        fi
    else
        echo "curl - error downloading es-$midnight.zip (file $fno)"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

ES_CONFIG="https://radarcovid.covid19.gob.es/configuration/settings"
ES_LOCALES="https://radarcovid.covid19.gob.es/configuration/masterData/locales?locale=es-ES"
ES_CCAA="https://radarcovid.covid19.gob.es/configuration/masterData/ccaa?locale=es-ES&additionalInfo=true"
$CURL -L $ES_CONFIG --output es-cfg.json
$CURL -L $ES_LOCALES --output es-locales.json
$CURL -L $ES_CCAA --output es-ccaa.json
#echo ".es config:"
#cat es-cfg.json

echo "======================"
echo "US Virginia TEKs"

# US Virginia

USVA_CANARY="$ARCHIVE/usva-canary"
USVA_BASE="https://storage.googleapis.com/prod-export-key"
USVA_INDEX="$USVA_BASE/exposureKeyExport-US/index.txt"
USVA_CONFIG="$USVA_BASE/settings/"

# USVA config is hardcoded in the app apparently (for now)
# $CURL --output usva-cfg.json -L $USVA_CONFIG

response_headers=`$CURL -D - -o usva-index-headers.txt -L "$USVA_INDEX" -i`
clzero=`echo $response_headers | grep -ic "Content-Length: 0"`
if [[ "$clzero" != "0" ]]
then
    echo "Skipping US Virginia because content length is zero at $NOW." 
else
    # download again, without headers
    sleep 1
    $CURL -o usva-index.txt -L "$USVA_INDEX"
    # this may not be correct, will find out as we go...
    for path in `cat usva-index.txt`
    do
        sleep 1
        zname=`echo $path | sed -e 's/.*\///'`
        lpath=$(sanitise_filename "usva-$zname")
        $CURL -o $lpath -L "$USVA_BASE/$path" 
        if [ -f $lpath ]
        then
            # we should be good now, so remove canary
            rm -f $USVA_CANARY
            if [ ! -f $ARCHIVE/$lpath ]
            then
                echo "New usva file $lpath"
                cp $lpath $ARCHIVE
            elif ((`stat -c%s "$lpath"`>`stat -c%s "$ARCHIVE/$lpath"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger usva file $lpath"
                cp $lpath $ARCHIVE
            else
                echo "A smaller or same $lpath already archived"
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "$lpath" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        else
            echo "Failed to download $lpath"
            echo "Failed to download $lpath at $NOW" >$USVA_CANARY
        fi
    done
fi

echo "======================"
echo "Canadian TEKs"

CA_CANARY="$ARCHIVE/ca-canary"
CA_BASE="https://retrieval.covid-notification.alpha.canada.ca"
CA_CONFIG="$CA_BASE/exposure-configuration/CA.json"

# Grab config
$CURL --output ca-cfg.json -L $CA_CONFIG

# From Doug:
# Code from app that generates TEK URL:
#  async retrieveDiagnosisKeys(period: number) {
#    const periodStr = `${period > 0 ? period : LAST_14_DAYS_PERIOD}`;
#    const message = `${MCC_CODE}:${periodStr}:${Math.floor(getMillisSinceUTCEpoch() / 1000 / 3600)}`;
#    const hmac = hmac256(message, encHex.parse(this.hmacKey)).toString(encHex);
#    const url = `${this.retrieveUrl}/retrieve/${MCC_CODE}/${periodStr}/${hmac}`;
#    captureMessage('retrieveDiagnosisKeys', {period, url});
#    return downloadDiagnosisKeysFile(url);
#  }
#
# MCC_CODE is “302”, LAST_14_DAYS_PERIOD = ‘00000’.   looks like the nasty 
# long string in the url is hmac encrypted form of message string.  fortunately the key is hardwired into the app:
#
#.field public static final HMAC_KEY:Ljava/lang/String; = “3631313045444b345742464633504e44524a3457494855505639593136464a3846584d4c59334d30"
#
#(why do they even bother with this shitty “security”).

# I note that that hmac key is an ascii hex encoding:
# $ echo 3631313045444b345742464633504e44524a3457494855505639593136464a3846584d4c59334d30 | xxd -r -p
# 6110EDK4WBFF3PNDRJ4WIHUPV9Y16FJ8FXMLY3M0

HMAC_KEY="6110EDK4WBFF3PNDRJ4WIHUPV9Y16FJ8FXMLY3M0"
MCC_CODE="302"
periodStr="00000"

# Demo re-calculation of HMAC
# URL at approx 20200819-140000Z
# https://retrieval.covid-notification.alpha.canada.ca/retrieve/302/00000/cc0b17155fe1d642495dfc1dd0230c33573def6c35a33b61260306d797637e33
# And to re-calc...
# THEN=`date -d "2020-08-19T14:00:00" +%s`
# timeStr=$((THEN/3600))
# MESSAGE="$MCC_CODE:$periodStr:$timeStr"
# THENCODE=`echo -n $MESSAGE | openssl sha256 -hmac "$HMAC_KEY" | awk '{print $2}'`
# CA_INDEX="$CA_BASE/retrieve/MCC_CODE/$periodStr/$THENCODE"
# echo "want cc0b17155fe1d642495dfc1dd0230c33573def6c35a33b61260306d797637e33"

# Try for various top of the hour values and keep those that work
# It looks like the server actually only offers files named for
# the two hours before now, this hour and the next hour, but we'll
# check 25 hours worth just in case, as that might change
nowStr=`date +%s` 
nowTimeStr=$((nowStr/3600))
for houroff in {-12..12}
do
    thenStr=$((nowTimeStr+houroff))
    MESSAGE="$MCC_CODE:$periodStr:$thenStr"
    THENCODE=`echo -n $MESSAGE | openssl sha256 -hmac "$HMAC_KEY" | awk '{print $2}'`
    CA_INDEX="$CA_BASE/retrieve/$MCC_CODE/$periodStr/$THENCODE"
    echo "Trying `date -d @$((thenStr*3600))` $houroff hours off from $CA_INDEX"
    response_headers=`$CURL -D - -o ca-$thenStr-headers.txt -L "$CA_INDEX" -i`
    unauth=`echo $response_headers | grep -c "HTTP/2 401"`
    if [[ "$unauth" == "0" ]]
    then
        # try get actual zip
        $CURL -o ca-$thenStr.zip -L "$CA_INDEX"
        lpath=ca-$thenStr.zip
        # canada turned off on 2022-06-22 (or so) so we'll check if we're
        # really getting a zip or not (since they turned off we get some 
        # XML with an error message)
        iszip=`file $lpath | grep Zip`
        if [[ "$iszip" == "" ]]
        then
            echo "Canada fail: not a zip $lpath"
            continue
        fi
        if [ -f $lpath ]
        then
            # we should be good now, so remove canary
            if [ ! -f $ARCHIVE/$lpath ]
            then
                echo "New ca file $lpath"
                cp $lpath $ARCHIVE
            elif ((`stat -c%s "$lpath"`>`stat -c%s "$ARCHIVE/$lpath"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger ca file $lpath"
                cp $lpath $ARCHIVE
            else
                echo "A smaller or same $lpath already archived"
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "$lpath" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        else
            echo "Failed to download $lpath"
            echo "Failed to download $lpath at $NOW" >$CA_CANARY
        fi
    else
        echo "401'd"
    fi
    # be a little nice to 'em
    sleep 1
done

# US Alabama

echo "======================"
echo "US Alabama TEKs"

USAL_CANARY="$ARCHIVE/usal-canary"
USAL_BASE="https://covidexposure-files-store.azureedge.net"
USAL_INDEX="$USAL_BASE/index.txt"
USAL_CONFIG="$USAL_BASE/settings/"

response_headers=`$CURL -D - -o usal-index-headers.txt -L "$USAL_INDEX" -i`
clzero=`echo $response_headers | grep -ic "Content-Length: 0"`
if [[ "$clzero" != "0" ]]
then
    echo "Skipping US Alabama because content length is zero at $NOW." 
else
    # download again, without headers
    sleep 1
    $CURL -o usal-index.txt -L "$USAL_INDEX"
    # this may not be correct, will find out as we go...
    for url in `cat usal-index.txt | awk '{print $1}'`
    do
        sleep 1
        zname=`basename $url`
        lpath=$(sanitise_filename "usal-$zname")
        $CURL -o $lpath -L "$url"
        if [ -f $lpath ]
        then
            # we should be good now, so remove canary
            rm -f $USAL_CANARY
            if [ ! -f $ARCHIVE/$lpath ]
            then
                echo "New usal file $lpath"
                cp $lpath $ARCHIVE
            elif ((`stat -c%s "$lpath"`>`stat -c%s "$ARCHIVE/$lpath"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger usal file $lpath"
                cp $lpath $ARCHIVE
            else
                echo "A smaller or same $lpath already archived"
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "$lpath" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        else
            echo "Failed to download $lpath"
            echo "Failed to download $lpath at $NOW" >$USAL_CANARY
        fi
    done
fi

echo "======================"
echo ".ee TEKs"

# Estonia
EE_BASE="https://enapi.sm.ee/authorization/v1/gaen/exposed"
now=`date +%s`
toay_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

for fno in {0..14}
do
    echo "Doing .ee file $fno" 
    midnight=$((toay_midnight-fno*day))
    eehttpcode=`$CURL -L "$EE_BASE/$midnight" -s -w "%{http_code}" -o ee-$midnight.txt`
    if [[ "$eehttpcode" != "200" ]]
    then
        echo "Estonia fail: Got $eehttpcode for $EE_BASE/$midnight"
        if [[ "$eehttpcode" == "500" ]]
        then
            # querying this guy is now VERY slow so if we get one 500 then 
            # we'll bail for this hour
            echo "Estonia fail: breaking loop after $fno"
            break
        fi
    else
        # estonia changed to returning HTML with a 200 reponse on June 1st 2022
        # so we'll check if the relevant file is a zip or not - looks like it's
        # a 302 redirect to https://tekik.ee sending back generic HTML likely
        # for a hoster or similar (there's no English button visible)
        iszip=`file ee-$midnight.txt | grep Zip`
        if [[ "$iszip" == "" ]]
        then
            echo "Estonia fail: not a zip ee-$midnight.txt"
            break
        fi
        $CURL -L "$EE_BASE/$midnight" --output ee-$midnight.zip
        if [[ $? == 0 ]]
        then
            # we do see zero sized files from .ee sometimes
            # which is odd but whatever (could be their f/w
            # doing that but what'd be the effect on the 
            # app?) 
            if [ ! -s ee-$midnight.zip ]
            then
                echo "Empty or non-existent downloaded Estonian file: ee-$midnight.zip ($fno)"
            else
                if [ ! -f $ARCHIVE/ee-$midnight.zip ]
                then
                    echo "New .ee file $fno ee-$midnight" 
                    cp ee-$midnight.zip $ARCHIVE
                elif ((`stat -c%s "ee-$midnight.zip"`>`stat -c%s "$ARCHIVE/ee-$midnight.zip"`));then
                    # if the new one is bigger than archived, then archive new one
                    echo "Updated/bigger .ee file $fno ee-$midnight" 
                    cp ee-$midnight.zip $ARCHIVE
                fi
                # try unzip and decode
                #if [[ "$DODECODE" == "yes" ]]
                #then
                    #$UNZIP "ee-$midnight.zip" >/dev/null 2>&1
                    #if [[ $? == 0 ]]
                    #then
                        #$TEK_DECODE >/dev/null
                        #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                    #fi
                    #rm -f export.bin export.sig
                    #chunks_down=$((chunks_down+1))
                #fi
            fi
        else
            echo "curl - error downloading ee-$midnight.zip (file $fno)"
        fi
    fi
    # don't appear to be too keen:-)
    sleep 1
done

# Don't know config URL yet
#EE_CONFIG="https://enapi.sm.ee/authorization/configuration/settings"
#EE_LOCALES="https://radarcovid.covid19.gob.ee/configuration/masterData/locales?locale=ee-EE"
#EE_CCAA="https://radarcovid.covid19.gob.ee/configuration/masterData/ccaa?locale=ee-ES&additionalInfo=true"
#$CURL -L $EE_CONFIG --output ee-cfg.json
#$CURL -L $EE_LOCALES --output ee-locales.json
#$CURL -L $EE_CCAA --output ee-ccaa.json
#echo ".ee config:"
#cat ee-cfg.json

echo "======================"
echo ".fi TEKs"

# Finland

FI_BASE="https://taustajarjestelma.koronavilkku.fi/diagnosis"
FI_CONFIG="https://taustajarjestelma.koronavilkku.fi/exposure/configuration/v1"
FI_CONFIG2="https://repo.thl.fi/sites/koronavilkku/yhteystiedot.json"

# Server needs crazy user agent for some reason
FI_UA="-A Koronavilkku/1.0.0.174"

$CURL -o fi-cfg.json -L $FI_CONFIG $FI_UA
$CURL -o fi-cfg2.json -L $FI_CONFIG2 $FI_UA

fi_index=`$CURL -L "$FI_BASE/v1/list?previous=0" $FI_UA`
if [[ "$?" == "0" ]]
then
    echo "Finnish index: $fi_index"
    batches=`echo $fi_index |  sed -e 's/","/ /g' | sed -e 's/"]}//' | sed -e 's/.*"//'`
    for rbatch in $batches
    do
        batch=$(sanitise_filename $rbatch)
        $CURL -o fi-$batch.zip -L "$FI_BASE/v1/batch/$rbatch" $FI_UA
        if [[ $? == 0 ]]
        then
            # we do see zero sized files from .es sometimes
            # which is odd but whatever (could be their f/w
            # doing that but what'd be the effect on the 
            # app?) 
            if [ ! -s fi-$batch.zip ]
            then
                echo "Empty or non-existent downloaded Finnish file: fi-$batch.zip"
            else
                if [ ! -f $ARCHIVE/fi-$batch.zip ]
                then
                    echo "New .fi file fi-$batch" 
                    cp fi-$batch.zip $ARCHIVE
                elif ((`stat -c%s "fi-$batch.zip"`>`stat -c%s "$ARCHIVE/fi-$batch.zip"`));then
                    # if the new one is bigger than archived, then archive new one
                    echo "Updated/bigger .fi file fi-$batch" 
                    cp fi-$batch.zip $ARCHIVE
                fi
                # try unzip and decode
                #if [[ "$DODECODE" == "yes" ]]
                #then
                    #$UNZIP "fi-$batch.zip" >/dev/null 2>&1
                    #if [[ $? == 0 ]]
                    #then
                        #$TEK_DECODE >/dev/null
                        #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                    #fi
                    #rm -f export.bin export.sig
                    #chunks_down=$((chunks_down+1))
                #fi
            fi
        else
            echo "curl - error downloading fi-$batch.zip (file $fno)"
        fi
    done
fi

echo "======================"
echo "Scotland TEKs"

# Scotland

UKSC_INDEX="https://api-scot-prod.nearform-covid-services.com/api/exposures/?since=0&limit=1000"
UKSC_BASE="https://api-scot-prod.nearform-covid-services.com/api/data"
UKSC_REFRESH="https://api-scot-prod.nearform-covid-services.com/api/refresh"
UKSC_CONFIG="https://api-scot-prod.nearform-covid-services.com/api/settings/exposures"
UKSC_LANG="https://api-scot-prod.nearform-covid-services.com/api/settings/language"
UKSC_STATS="https://api-scot-prod.nearform-covid-services.com/api/stats"

# used to notify us that something went wrong
CANARY="$ARCHIVE/uksc-canary"
UKSC_RTFILE="$HOME/uksc-refreshToken.txt"

$CURL --output uksc-lang.json -L $UKSC_LANG

if [ ! -f $UKSC_RTFILE ]
then
    if [ ! -f $CANARY ]
    then
        echo "<p>Skipping Scotland stats/cfg because refreshToken access failed at $NOW.</p>" >$CANARY
    fi
    echo "Skipping Scotland stats/cfg because refreshToken access failed at $NOW.</p>" 
else 

    refreshToken=`cat $UKSC_RTFILE`
    tok_json=`$CURL -s -L $UKSC_REFRESH -H "Authorization: Bearer $refreshToken" -d "{}"`
    if [[ "$?" != 0 ]]
    then
        if [ ! -f $CANARY ]
        then
            echo "<p>Skipping Scotland stats/cfg because refreshToken use failed at $NOW.</p>" >$CANARY
        fi
        echo "Skipping Scotland stats/cfg because refreshToken use failed at $NOW."
    else
        newtoken=`echo $tok_json | awk -F: '{print $2}' | sed -e 's/"//g' | sed -e 's/}//'`
        if [[ "$newtoken" == "" ]]
        then
            echo "No sign of an authToken, sorry - Skipping Scotland"
        else
            $CURL --output uksc-cfg.json -L $UKSC_CONFIG -H "Authorization: Bearer $newtoken"` 
            $CURL --output uksc-stats.json -L $UKSC_STATS -H "Authorization: Bearer $newtoken"` 

            index_str=`$CURL -L "$UKSC_INDEX" -H "Authorization: Bearer $newtoken"`  
            ukscfiles=""
            if [[ $? != 0 ]]
            then
                echo "Error getting index string: $index_str ($?)"
            else
                echo "Scotland index string: $index_str"
                for row in $(echo "${index_str}" | jq -r '.[] | @base64'); 
                do
                    check401=`echo ${row} | base64 --decode`
                    if [[ "$check401" == "401" ]]
                    then
                        echo "401 detected in JSON answer - oops"
                        break
                    fi
                    _jq() {
                            echo ${row} | base64 --decode | jq -r ${1}
                    }
                    ukscfiles="$ukscfiles $(_jq '.path')"
                done
            fi
            for ukscfile in $ukscfiles
            do
                echo "Getting $ukscfile"
                ukscname=$(sanitise_filename "`basename $ukscfile`")
                $CURL -L "$UKSC_BASE/$ukscfile" --output uksc-$ukscname -H "Authorization: Bearer $newtoken"
                if [[ $? == 0 ]]
                then
                    # we should be good now, so remove canary
                    rm -f $CANARY
                    if [ ! -f $ARCHIVE/uksc-$ukscname ]
                    then
                        cp uksc-$ukscname $ARCHIVE
                    fi
                    # try unzip and decode
                    #if [[ "$DODECODE" == "yes" ]]
                    #then
                        #$UNZIP "uksc-$ukscname" >/dev/null 2>&1
                        #if [[ $? == 0 ]]
                        #then
                            #$TEK_DECODE >/dev/null
                            #new_keys=$?
                            #total_keys=$((total_keys+new_keys))
                        #fi
                        #rm -f export.bin export.sig
                        #chunks_down=$((chunks_down+1))
                    #fi
                else
                    echo "Error downloading uksc-$ukscname"
                fi
            done

        fi
    fi
fi

echo "======================"
echo "US Delaware TEKs"

# Delaware

CANARY="$ARCHIVE/usde-canary"
USDE_INDEX="https://encdn.prod.exposurenotification.health/v1/index.txt"
USDE_BASE="https://encdn.prod.exposurenotification.health/"
USDE_REFRESH="https://api-dela-prod.nearform-covid-services.com/api/refresh"
USDE_CONFIG="https://api-dela-prod.nearform-covid-services.com/api/settings/exposures"
USDE_LANG="https://api-dela-prod.nearform-covid-services.com/api/settings/language"
USDE_STATS="https://api-dela-prod.nearform-covid-services.com/api/stats"

# used to notify us that something went wrong
USDE_RTFILE="$HOME/usde-refreshToken.txt"

$CURL --output usde-lang.json -L $USDE_LANG

if [ ! -f $USDE_RTFILE ]
then
    if [ ! -f $CANARY ]
    then
        echo "<p>Skipping Delaware stats/cfg because refreshToken access failed at $NOW.</p>" >$CANARY
    fi
    echo "Skipping Delaware stats/cfg because refreshToken access failed at $NOW.</p>" 
else 

    refreshToken=`cat $USDE_RTFILE`
    tok_json=`$CURL -s -L $USDE_REFRESH -H "Authorization: Bearer $refreshToken" -d "{}"`
    if [[ "$?" != 0 ]]
    then
        if [ ! -f $CANARY ]
        then
            echo "<p>Skipping Delaware stats/cfg because refreshToken use failed at $NOW.</p>" >$CANARY
        fi
        echo "Skipping Delaware stats/cfg because refreshToken use failed at $NOW."
    else
        newtoken=`echo $tok_json | awk -F: '{print $2}' | sed -e 's/"//g' | sed -e 's/}//'`
        if [[ "$newtoken" == "" ]]
        then
            echo "No sign of an authToken, sorry - Skipping Delaware"
        else
            # config now requires authz for some reason
            $CURL --output usde-cfg.json -L $USDE_CONFIG -H "Authorization: Bearer $newtoken"` 
            $CURL --output usde-stats.json -L $USDE_STATS -H "Authorization: Bearer $newtoken"` 

        fi
    fi
fi

index_str=`$CURL -s -L "$USDE_INDEX"` 
if [[ $? != 0 ]]
then
    echo "Error getting index string: $index_str ($?)"
else
    echo "Delaware index string: $index_str"
    for usdefile in $index_str
    do
        echo "Getting $usdefile"
        usdename=$(sanitise_filename "`basename $usdefile`")
        $CURL -s -L "$USDE_BASE/$usdefile" --output usde-$usdename 
        if [[ $? == 0 ]]
        then
            # we should be good now, so remove canary
            rm -f $CANARY
            if [ ! -f $ARCHIVE/usde-$usdename ]
            then
                cp usde-$usdename $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "usde-$usdename" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        else
            echo "Error decoding usde-$usdename"
        fi
    done
fi

echo "======================"
echo "Nevada TEKs"

# Nevada

# 20210204: this migrated to US national server
# I updated the output page to record which US states do the same, there's a map at:
# https://www.aphl.org/programs/preparedness/Crisis-Management/COVID-19-Response/Pages/exposure-notifications.aspx

USNV_INDEX="https://exposure-notification-export-cpmxr.storage.googleapis.com/exposure-keys/index.txt"
USNV_BASE="https://exposure-notification-export-cpmxr.storage.googleapis.com"
USNV_CONFIG="https://static.nvcovidtrace.com/remote.json"
CANARY="$ARCHIVE/usnv-canary"

$CURL --output usnv-cfg.json -L $USNV_CONFIG 

index_str=`$CURL -s -L "$USNV_INDEX"` 
if [[ $? != 0 ]]
then
    echo "Error getting index string: $index_str ($?)"
    echo "Error getting index string: $index_str ($?) at $NOW" >$CANARY
    exit 1
fi
echo "Nevada index string: $index_str"
for usnvfile in $index_str
do
    echo "Getting $usnvfile"
    usnvname=$(sanitise_filename "`basename $usnvfile`")
    $CURL -s -L "$USNV_BASE/$usnvfile" --output usnv-$usnvname 
    if [[ $? == 0 ]]
    then
        # we should be good now, so remove canary
        rm -f $CANARY
        if [ ! -f $ARCHIVE/usnv-$usnvname ]
        then
            cp usnv-$usnvname $ARCHIVE
        fi
        # try unzip and decode
        #if [[ "$DODECODE" == "yes" ]]
        #then
            #$UNZIP "usnv-$usnvname" >/dev/null 2>&1
            #if [[ $? == 0 ]]
            #then
                #$TEK_DECODE >/dev/null
                #new_keys=$?
                #total_keys=$((total_keys+new_keys))
            #fi
            #rm -f export.bin export.sig
            #chunks_down=$((chunks_down+1))
        #fi
    else
        echo "Error decoding usnv-$usnvname"
        echo "Error decoding usnv-$usnvname at $NOW" >$CANARY
    fi
done

echo "======================"
echo "Wyoming TEKs"

# Wyoming

CANARY="$ARCHIVE/uswy-canary"
USWY_INDEX="https://encdn.prod.exposurenotification.health/v1/index.txt"
USWY_BASE="https://encdn.prod.exposurenotification.health"
USWY_CONFIG="https://exposureapi.care19.app/api/v1/apps/2/devices/b640737e-aada-42c7-9bf5-0d453de1d084/exposureconfig?regionId=5"

# used to notify us that something went wrong
CANARY="$ARCHIVE/uswy-canary"

$CURL --output uswy-cfg.json -L $USWY_CONFIG 

index_str=`$CURL -s -L "$USWY_INDEX"` 
if [[ $? != 0 ]]
then
    echo "Error getting index string: $index_str ($?)"
    exit 1
fi
echo "Wyoming index string: $index_str"
for uswyfile in $index_str
do
    echo "Getting $uswyfile"
    uswyname=$(sanitise_filename "`basename $uswyfile`")
    $CURL -s -L "$USWY_BASE/$uswyfile" --output uswy-$uswyname 
    if [[ $? == 0 ]]
    then
        # we should be good now, so remove canary
        rm -f $CANARY
        if [ ! -f $ARCHIVE/uswy-$uswyname ]
        then
            cp uswy-$uswyname $ARCHIVE
        fi
        # try unzip and decode
        #if [[ "$DODECODE" == "yes" ]]
        #then
            #$UNZIP "uswy-$uswyname" >/dev/null 2>&1
            #if [[ $? == 0 ]]
            #then
                #$TEK_DECODE >/dev/null
                #new_keys=$?
                #total_keys=$((total_keys+new_keys))
            #fi
            #rm -f export.bin export.sig
            #chunks_down=$((chunks_down+1))
        #fi
    else
        echo "Error decoding uswy-$uswyname"
    fi
done

echo "======================"
echo "Brazil TEKs"

# Brasil

CANARY="$ARCHIVE/br-canary"
BR_INDEX="https://exposure-notification.saude.gov.br/exposureKeyExport-BR/index.txt"
BR_BASE="https://exposure-notification.saude.gov.br"

# used to notify us that something went wrong
CANARY="$ARCHIVE/br-canary"

bad_brazil="no"
index_str=`$CURL -s -L "$BR_INDEX"` 
if [[ $? != 0 ]]
then
    echo "Error getting index string: $index_str ($?)"
    index_str=""
fi
echo "Brazil index string: $index_str"
for brfile in $index_str
do
    echo "Getting $brfile"
    brname=$(sanitise_filename "`basename $brfile`")
    $CURL -s -L "$BR_BASE/$brfile" --output br-$brname 
    if [[ $? == 0 ]]
    then
        # we should be good now, so remove canary
        rm -f $CANARY
        if [ ! -f $ARCHIVE/br-$brname ]
        then
            cp br-$brname $ARCHIVE
        fi
        # try unzip and decode
        #if [[ "$DODECODE" == "yes" ]]
        #then
            #$UNZIP "br-$brname" >/dev/null 2>&1
            #if [[ $? == 0 ]]
            #then
                #$TEK_DECODE >/dev/null
                #new_keys=$?
                #total_keys=$((total_keys+new_keys))
            #fi
            #rm -f export.bin export.sig
            ##chunks_down=$((chunks_down+1))
        #fi
    else
        echo "Error decoding br-$brname"
    fi
done

echo "======================"
echo "UK England and Wales TEKs"

CANARY="$ARCHIVE/ukenw-canary"
# There is also an hourly endpoint but we don't really need that I guess
UKEN_BASE="https://distribution-te-prod.prod.svc-test-trace.nhs.uk/distribution/daily"
UKEN_CONFIG="https://distribution-te-prod.prod.svc-test-trace.nhs.uk/distribution/exposure-configuration"
DAYSECS=$((24*60*60))

$CURL -o ukenw-cfg.json -L $UKEN_CONFIG 

# We'll download the last three days in case we miss some runs and/or
# get errors - hopefully that'll be enough to catch up on any misses

nowsecs=`date +%s`
# now less 3 days
nowdm3="`date +%Y%m%d -d@$((nowsecs-3*DAYSECS))`00"
nowdm2="`date +%Y%m%d -d@$((nowsecs-2*DAYSECS))`00"
nowdm1="`date +%Y%m%d -d@$((nowsecs-DAYSECS))`00"
nowd="`date +%Y%m%d -d@$nowsecs`00"
dlist="$nowd $nowdm1 $nowdm2 $nowdm3"

echo "Downloading UK (England/Wales) files for: $dlist"
for batch in $dlist
do
    echo "trying ukenw-$batch.zip"
    $CURL -o ukenw-$batch.zip -L "$UKEN_BASE/$batch.zip"
    if [[ $? == 0 ]]
    then
        # we do see zero sized files sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s ukenw-$batch.zip ]
        then
            echo "Empty or non-existent downloaded UK file: ukenw-$batch.zip"
        else
            if [ ! -f $ARCHIVE/ukenw-$batch.zip ]
            then
                echo "New ukenw file ukenw-$batch" 
                cp ukenw-$batch.zip $ARCHIVE
            elif ((`stat -c%s "ukenw-$batch.zip"`>`stat -c%s "$ARCHIVE/ukenw-$batch.zip"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger ukenw file ukenw-$batch" 
                cp ukenw-$batch.zip $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "ukenw-$batch.zip" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        fi
    else
        echo "curl - error downloading ukenw-$batch.zip"
    fi

done


echo "======================"
echo "UK Gibraltar TEKs"

# Gibraltar

# used to notify us that something went wrong
CANARY="$ARCHIVE/ukgi-canary"
GI_RTFILE="$HOME/ukgi-refreshToken.txt"
GI_BASE="https://app.beatcovid19.gov.gi/api"
GI_CONFIG="$GI_BASE/settings/"

$CURL --output ukgi-cfg.json -L $GI_CONFIG

if [ ! -f $GI_RTFILE ]
then
    if [ ! -f $CANARY ]
    then
        echo "<p>Skipping Gibraltar because refreshToken access failed at $NOW.</p>" >$CANARY
    fi
    echo "Skipping Gibraltar because refreshToken access failed at $NOW.</p>" 
else 

    refreshToken=`cat $GI_RTFILE`
    tok_json=`$CURL -s -L $GI_BASE/refresh -H "Authorization: Bearer $refreshToken" -d "{}"`
    if [[ "$?" != 0 ]]
    then
        if [ ! -f $CANARY ]
        then
            echo "<p>Skipping Gibraltar because refreshToken use failed at $NOW.</p>" >$CANARY
        fi
        echo "Skipping Gibraltar because refreshToken use failed at $NOW."
    else
        newtoken=`echo $tok_json | awk -F: '{print $2}' | sed -e 's/"//g' | sed -e 's/}//'`
        if [[ "$newtoken" == "" ]]
        then
            echo "No sign of an authToken, sorry - Skipping Gibraltar"
        else
            index_str=`$CURL -s -L "$GI_BASE/exposures/?since=0&limit=1000" -H "Authorization: Bearer $newtoken"` 
            echo "Gibraltar index string: $index_str"
            gifiles=""
            for row in $(echo "${index_str}" | jq -r '.[] | @base64'); 
            do
                check401=`echo ${row} | base64 --decode`
                if [[ "$check401" == "401" ]]
                then
                    echo "401 detected in JSON answer - oops"
                    break
                fi
                _jq() {
                         echo ${row} | base64 --decode | jq -r ${1}
                }
                gifiles="$gifiles $(_jq '.path')"
            done
            for gifile in $gifiles
            do
                echo "Getting $gifile"
                gibname=$(sanitise_filename "`basename $gifile`")
                $CURL -s -L "$GI_BASE/data/$gifile" --output ukgi-$gibname -H "Authorization: Bearer $newtoken"
                if [[ $? == 0 ]]
                then
                    # we should be good now, so remove canary
                    rm -f $CANARY
                    if [ ! -f $ARCHIVE/ukgi-$gibname ]
                    then
                        cp ukgi-$gibname $ARCHIVE
                    fi
                    # try unzip and decode
                    #if [[ "$DODECODE" == "yes" ]]
                    #then
                        #$UNZIP "ukgi-$gibname" >/dev/null 2>&1
                        #if [[ $? == 0 ]]
                        #then
                            #$TEK_DECODE >/dev/null
                            #new_keys=$?
                            #total_keys=$((total_keys+new_keys))
                        #fi
                        #rm -f export.bin export.sig
                        #chunks_down=$((chunks_down+1))
                    #fi
                else
                    echo "Error downloading ukgi-$gibname"
                fi
            done
    
        fi
    fi
fi

echo "======================"
echo ".mt TEKs"

# Malta

MT_BASE="https://mt-dpppt-ws.azurewebsites.net/v1/gaen/exposed"
MT_CONFIG="https://mt-dpppt-config.azurewebsites.net/v1/config?appversion=android-1.2.8&osversion=android28&buildnr=1599138353411"
$CURL -L $MT_CONFIG --output mt-cfg.json

now=`date +%s`
today_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

for fno in {0..14}
do
    echo "Doing .mt file $fno" 
    midnight=$((today_midnight-fno*day))
    $CURL -L "$MT_BASE/$midnight" --output mt-$midnight.zip
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .mt sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s mt-$midnight.zip ]
        then
            echo "Empty or non-existent downloaded Maltese file: mt-$midnight.zip ($fno)"
        else
            if [ ! -f $ARCHIVE/mt-$midnight.zip ]
            then
                echo "New .mt file $fno mt-$midnight" 
                cp mt-$midnight.zip $ARCHIVE
            elif ((`stat -c%s "mt-$midnight.zip"`>`stat -c%s "$ARCHIVE/mt-$midnight.zip"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .mt file $fno mt-$midnight" 
                cp mt-$midnight.zip $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "mt-$midnight.zip" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        fi
    else
        echo "curl - error downloading mt-$midnight.zip (file $fno)"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

echo "======================"
echo ".pt TEKs"

# Portugal

PT_BASE="https://stayaway.incm.pt/v1/gaen/exposed"
PT_CONFIG="https://stayaway.incm.pt/config/defaults.json"

$CURL -L $PT_CONFIG --output pt-cfg.json

now=`date +%s`
today_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

for fno in {0..14}
do
    echo "Doing .pt file $fno" 
    midnight=$((today_midnight-fno*day))
    $CURL -L "$PT_BASE/$midnight" --output pt-$midnight.zip
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .pt sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s pt-$midnight.zip ]
        then
            echo "Empty or non-existent downloaded Portugese file: pt-$midnight.zip ($fno)"
        else
            if [ ! -f $ARCHIVE/pt-$midnight.zip ]
            then
                echo "New .pt file $fno pt-$midnight" 
                cp pt-$midnight.zip $ARCHIVE
            elif ((`stat -c%s "pt-$midnight.zip"`>`stat -c%s "$ARCHIVE/pt-$midnight.zip"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .pt file $fno pt-$midnight" 
                cp pt-$midnight.zip $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "pt-$midnight.zip" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        fi
    else
        echo "curl - error downloading pt-$midnight.zip (file $fno)"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

echo "======================"
echo ".ec TEKs"

# Ecuador

EC_BASE="https://contacttracing.covidanalytics.ai/v1/gaen/exposed"
EC_CONFIG="https://contacttracing.covidanalytics.ai/v1/config?appversion=android-0.0.12-pilot&osversion=android28&buildnr=1598659886251"

$CURL -L $EC_CONFIG --output ec-cfg.json

now=`date +%s`
today_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

for fno in {0..14}
do
    echo "Doing .ec file $fno" 
    midnight=$((today_midnight-fno*day))
    $CURL -L "$EC_BASE/$midnight" --output ec-$midnight.zip
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .ec sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s ec-$midnight.zip ]
        then
            echo "Empty or non-existent downloaded Ecuadorian file: ec-$midnight.zip ($fno)"
        else
            if [ ! -f $ARCHIVE/ec-$midnight.zip ]
            then
                echo "New .ec file $fno ec-$midnight" 
                cp ec-$midnight.zip $ARCHIVE
            elif ((`stat -c%s "ec-$midnight.zip"`>`stat -c%s "$ARCHIVE/ec-$midnight.zip"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .ec file $fno ec-$midnight" 
                cp ec-$midnight.zip $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "ec-$midnight.zip" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        fi
    else
        echo "curl - error downloading ec-$midnight.zip (file $fno)"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

echo "======================"
echo ".be TEKs"

# Belgium

CANARY="$ARCHIVE/be-canary"
BE_BASE="https://c19distcdn-prd.ixor.be/version/v1/diagnosis-keys/country/BE/date"
BE_CONFIG="https://c19distcdn-prd.ixor.be/version/v1/configuration/country/BE/app_config"
BE_STATS="https://c19statcdn-prd.ixor.be/statistics/statistics.json"

$CURL -L $BE_CONFIG --output be-cfg.json
$CURL -L $BE_STATS --output be-stats.json

be_index=`$CURL -L "$BE_BASE"`
if [[ "$?" == "0" ]]
then
    echo "Belgian index: $be_index"
    batches=`echo $be_index | sed -e 's/\[//' | sed -e 's/]//' | sed -e 's/"//g' | sed -e 's/,/ /g'`
    for rbatch in $batches
    do
        batch=$(sanitise_filename $rbatch)
        echo "Fetching be-$batch.zip"
        $CURL -o be-$batch.zip -L "$BE_BASE/$rbatch"
        if [[ $? == 0 ]]
        then
            # we do see zero sized files from .be sometimes
            # which is odd but whatever (could be their f/w
            # doing that but what'd be the effect on the 
            # app?) 
            if [ ! -s be-$batch.zip ]
            then
                echo "Empty or non-existent downloaded Belgian file: be-$batch.zip"
            else
                if [ ! -f $ARCHIVE/be-$batch.zip ]
                then
                    echo "New .be file be-$batch" 
                    cp be-$batch.zip $ARCHIVE
                elif ((`stat -c%s "be-$batch.zip"`>`stat -c%s "$ARCHIVE/be-$batch.zip"`));then
                    # if the new one is bigger than archived, then archive new one
                    echo "Updated/bigger .be file be-$batch" 
                    cp be-$batch.zip $ARCHIVE
                fi
                # try unzip and decode
                #if [[ "$DODECODE" == "yes" ]]
                #then
                    #$UNZIP "be-$batch.zip" >/dev/null 2>&1
                    #if [[ $? == 0 ]]
                    #then
                        #$TEK_DECODE >/dev/null
                        #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                    #fi
                    #rm -f export.bin export.sig
                    #chunks_down=$((chunks_down+1))
                #fi
            fi
        else
            echo "curl - error downloading be-$batch.zip (file $fno)"
        fi
    done
fi

echo "======================"
echo ".cz TEKs"

# Czechia

CZ_BASE="https://storage.googleapis.com/exposure-notification-export-qhqcx"

cz_index=`$CURL -L "$CZ_BASE/erouska/index.txt"`
echo "CZ index at $NOW: $cz_index"
for fno in $cz_index
do
    if [ "$fno" != "*.zip" ]
    then
        echo "Skipping .cz non-file $fno" 
        continue
    fi
    echo "Doing .cz file $fno" 
    bfno=$(sanitise_filename "`basename $fno`")
    $CURL -L "$CZ_BASE/$fno" --output cz-$bfno
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .cz sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s cz-$bfno ]
        then
            echo "Empty or non-existent downloaded Czech file: cz-$bfno"
        else
            if [ ! -f $ARCHIVE/cz-$bfno ]
            then
                echo "New .cz file cz-$bfno" 
                cp cz-$bfno $ARCHIVE
            elif ((`stat -c%s "cz-$bfno"`>`stat -c%s "$ARCHIVE/cz-$bfno"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .cz file cz-$bfno" 
                cp cz-$bfno $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "cz-$bfno" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        fi
    else
        echo "curl - error downloading cz-$bfno"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

echo "======================"
echo ".za TEKs"

# South Africa

ZA_BASE="https://files.ens.connect.sacoronavirus.co.za"

za_index=`$CURL -L "$ZA_BASE/exposureKeyExport-ZA/index.txt"`
echo "ZA index at $NOW: $za_index"
for fno in $za_index
do
    echo "Doing .za file $fno" 
    bfno=$(sanitise_filename "`basename $fno`")
    $CURL -L "$ZA_BASE/$fno" --output za-$bfno
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .za sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s za-$bfno ]
        then
            echo "Empty or non-existent downloaded South African file: za-$bfno"
        else
            if [ ! -f $ARCHIVE/za-$bfno ]
            then
                echo "New .za file za-$bfno" 
                cp za-$bfno $ARCHIVE
            elif ((`stat -c%s "za-$bfno"`>`stat -c%s "$ARCHIVE/za-$bfno"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .za file za-$bfno" 
                cp za-$bfno $ARCHIVE
            fi
            # try unzip and decode
            if [[ "$DODECODE" == "yes" ]]
            then
                $UNZIP "za-$bfno" >/dev/null 2>&1
                if [[ $? == 0 ]]
                then
                    $TEK_DECODE >/dev/null
                    new_keys=$?
                    total_keys=$((total_keys+new_keys))
                fi
                rm -f export.bin export.sig
                chunks_down=$((chunks_down+1))
            fi
        fi
    else
        echo "curl - error downloading za-$bfno"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

# Hungary - oops, these are really Croation (.hr) so we'll start skipping 'em now

DOHU="no"
if [[ "$DOHU" != "no" ]]
then

HU_BASE="https://en.apis-it.hr/submission/diagnosis-key-file-urls"
HU_BASE_EU="https://en.apis-it.hr/submission/diagnosis-key-file-urls?all=true"

echo "======================"
echo ".HU TEKs"
hu_urls=`$CURL -L "$HU_BASE" | json_pp | grep https | sed -e 's/"//g' | sed -e 's/,//g'`
hu_urls_eu=`$CURL -L "$HU_BASE_EU" | json_pp | grep https | sed -e 's/"//g' | sed -e 's/,//g'`
echo "HU URLs at $NOW: $hu_urls $hu_urls_eu"
for url in $hu_urls $hu_urls_eu
do
    echo "Doing .hu file $url" 
    burl=`basename $url`
    $CURL -L "$url" --output hu-$burl
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .hu sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s hu-$burl ]
        then
            echo "Empty or non-existent downloaded Hungarian file: hu-$burl"
        else
            if [ ! -f $ARCHIVE/hu-$burl ]
            then
                echo "New .hu file hu-$burl" 
                cp hu-$burl $ARCHIVE
            elif ((`stat -c%s "hu-$burl"`>`stat -c%s "$ARCHIVE/hu-$burl"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .hu file hu-$burl" 
                cp hu-$burl $ARCHIVE
            fi
            # try unzip and decode
            if [[ "$DODECODE" == "yes" ]]
            then
                $UNZIP "hu-$burl" >/dev/null 2>&1
                if [[ $? == 0 ]]
                then
                    $TEK_DECODE >/dev/null
                    new_keys=$?
                    total_keys=$((total_keys+new_keys))
                fi
                rm -f export.bin export.sig
                chunks_down=$((chunks_down+1))
            fi
        fi
    else
        echo "curl - error downloading hu-$burl"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

fi

echo "======================"
echo ".NL TEKs"

# Netherlands

# Change as per https://github.com/sftcd/tek_transparency/issues/16
# NL_BASE="https://productie.coronamelder-dist.nl/v1"
NL_BASE="https://productie.coronamelder-dist.nl/v2"
rm -f content.bin content.sig export.bin export.sig
$CURL -L "$NL_BASE/manifest" -o nl-mani.zip-but-dont-call-it-that
$UNZIP -u nl-mani.zip-but-dont-call-it-that 2>/dev/null
if [ ! -f content.bin ]
then
    echo "Failed to unzip nl-mani.zip"
else
    nl_keys=`cat content.bin | jq ".exposureKeySets?" | grep \" | sed -e 's/"//g' | sed -e 's/,//g'` 
    nl_cfg=`cat content.bin | jq ".appConfig?" | grep \" | sed -e 's/"//g' | sed -e 's/,//g'` 
    nl_rcp=`cat content.bin | jq ".riskCalculationParameters?" | grep \" | sed -e 's/"//g' | sed -e 's/,//g'` 

    $CURL -L "$NL_BASE/appconfig/$nl_cfg" -o nl-cfg.zip-but-dont-call-it-that
    $CURL -L "$NL_BASE/riskcalculationparameters/$nl_rcp" -o nl-rcp.zip-but-dont-call-it-that

    for rkey in $nl_keys
    do
        key=$(sanitise_filename $rkey)
        echo "Getting .nl file $key" 
        $CURL -L "$NL_BASE/exposurekeyset/$rkey" --output nl-$key.zip
        if [[ $? == 0 ]]
        then
            if [ ! -s nl-$key.zip ]
            then
                echo "Empty or non-existent downloaded Dutch file: nl-$key.zip"
            else
                if [ ! -f $ARCHIVE/nl-$key.zip ]
                then
                    echo "New .nl file nl-$key.zip" 
                    cp nl-$key.zip $ARCHIVE
                elif ((`stat -c%s "nl-$key.zip"`>`stat -c%s "$ARCHIVE/nl-$key.zip"`));then
                    # if the new one is bigger than archived, then archive new one
                    echo "Updated/bigger .nl file nl-$key.zip" 
                    cp nl-$key.zip $ARCHIVE
                fi
                # try unzip and decode
                #if [[ "$DODECODE" == "yes" ]]
                #then
                    #rm -f content.bin content.sig export.bin export.sig
                    #$UNZIP "nl-$key.zip" >/dev/null 2>&1
                    #if [[ $? == 0 ]]
                    #then
                        #$TEK_DECODE >/dev/null
                        #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                    #fi
                    #rm -f content.bin content.sig export.bin export.sig
                    #chunks_down=$((chunks_down+1))
                #fi
            fi
        else
            echo "error downloading nl-$key.zip"
        fi
        # permission granted to be speedy:-)
        # sleep 1
    done
    
fi

echo "======================"
echo ".gu TEKs"

# Guam

GU_BASE="https://cdn.projectaurora.cloud"

gu_index=`$CURL -L "$GU_BASE/guam/teks/index.txt"`
echo "GU index at $NOW: $gu_index"
for fno in $gu_index
do
    echo "Doing .gu file $fno" 
    bfno=$(sanitise_filename "`basename $fno`")
    $CURL -L "$GU_BASE/$fno" --output gu-$bfno
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .gu sometimes
        # which is odd but whatever (could be their f/w
        # doing that but what'd be the effect on the 
        # app?) 
        if [ ! -s gu-$bfno ]
        then
            echo "Empty or non-existent downloaded Guam file: gu-$bfno"
        else
            if [ ! -f $ARCHIVE/gu-$bfno ]
            then
                echo "New .gu file gu-$bfno" 
                cp gu-$bfno $ARCHIVE
            elif ((`stat -c%s "gu-$bfno"`>`stat -c%s "$ARCHIVE/gu-$bfno"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .gu file gu-$bfno" 
                cp gu-$bfno $ARCHIVE
            fi
            # try unzip and decode
            #if [[ "$DODECODE" == "yes" ]]
            #then
                #$UNZIP "gu-$bfno" >/dev/null 2>&1
                #if [[ $? == 0 ]]
                #then
                    #$TEK_DECODE >/dev/null
                    #new_keys=$?
                    #total_keys=$((total_keys+new_keys))
                #fi
                #rm -f export.bin export.sig
                #chunks_down=$((chunks_down+1))
            #fi
        fi
    else
        echo "curl - error downloading gu-$bfno"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

echo "======================"
echo ".si TEKs"

# Slovenia

CANARY="$ARCHIVE/si-canary"
SI_BASE="https://svc90.cwa.gov.si/version/v1/diagnosis-keys/country/SI/date"
SI_CONFIG="https://svc90.cwa.gov.si/version/v1/configuration/country/SI/app_config"
# endpoing doesn't seem to exist in .si
#SI_STATS=""

$CURL -L $SI_CONFIG --output si-cfg.json
#$CURL -L $SI_STATS --output si-stats.json

# use a 4s connection timeout as this isn't currently responsiive 
si_index=`$CURL --connect-timeout 4 -L "$SI_BASE"`
if [[ "$?" == "0" ]]
then
    echo "Slovenian index at $NOW: $si_index"
    batches=`echo $si_index | sed -e 's/\[//' | sed -e 's/]//' | sed -e 's/"//g' | sed -e 's/,/ /g'`
    for rbatch in $batches
    do
        batch=$(sanitise_filename "$rbatch")
        echo "Fetching si-$batch.zip"
        $CURL -o si-$batch.zip -L "$SI_BASE/$rbatch"
        if [[ $? == 0 ]]
        then
            # we do see zero sized files from .es sometimes
            # which is odd but whatever (could be their f/w
            # doing that but what'd be the effect on the 
            # app?) 
            if [ ! -s si-$batch.zip ]
            then
                echo "Empty or non-existent downloaded Slovenian file: si-$batch.zip"
            else
                if [ ! -f $ARCHIVE/si-$batch.zip ]
                then
                    echo "New .si file si-$batch" 
                    cp si-$batch.zip $ARCHIVE
                elif ((`stat -c%s "si-$batch.zip"`>`stat -c%s "$ARCHIVE/si-$batch.zip"`));then
                    # if the new one is bigger than archived, then archive new one
                    echo "Updated/bigger .si file si-$batch" 
                    cp si-$batch.zip $ARCHIVE
                fi
                # try unzip and decode
                #if [[ "$DODECODE" == "yes" ]]
                #then
                    #$UNZIP "si-$batch.zip" >/dev/null 2>&1
                    #if [[ $? == 0 ]]
                    #then
                        #$TEK_DECODE >/dev/null
                        #new_keys=$?
                        #total_keys=$((total_keys+new_keys))
                    #fi
                    #rm -f export.bin export.sig
                    #chunks_down=$((chunks_down+1))
                #fi
            fi
        else
            echo "curl - error downloading si-$batch.zip (file $fno)"
        fi
    done
fi

echo "======================"
echo ".fr stuff (not TEKs)"

# France
# France isn't a GAEN app, but they do produce some configs and stats we can grab

FR_BASE="https://app.stopcovid.gouv.fr"

FR_PATHS=(
    "infos/key-figures.json"
    "maintenance/info-maintenance-v2.json"
    "json/version-25//Attestations/form.json"
    "json/version-25/config.json"
    "json/version-25/InfoCenter/info-center.json"
    "json/version-25/InfoCenter/info-center-lastupdate.json"
    "json/version-25/InfoCenter/info-labels-en.json"
    "json/version-25/InfoCenter/info-tags.json"
    "json/version-25/Links/links-en.json"
    "json/version-25/MoreKeyFigures/morekeyfigures-en.json"
    "json/version-25/privacy-en.json"
    "json/version-25/strings-en.json"
    )


for path in "${FR_PATHS[@]}"
do
    bn=$(sanitise_filename "`basename $path`")
    $CURL $FR_BASE/$path --output fr-$bn
done

echo "======================"
echo ".hr TEKs"

## Croatia

HR_INDEX="https://en.apis-it.hr/submission/diagnosis-key-file-urls"
HR_INDEX_EU="https://en.apis-it.hr/submission/diagnosis-key-file-urls?all=true"

zips=`$CURL -L "$HR_INDEX" | jq ".urlList" | grep \" | sed -e 's/"//g' | sed -e 's/,//g'` 
zips_eu=`$CURL -L "$HR_INDEX_EU" | jq ".urlList" | grep \" | sed -e 's/"//g' | sed -e 's/,//g'` 
echo "HR index at $NOW: $zips $zips_eu"
for fname in $zips $zips_eu
do
    bfname=$(sanitise_filename "`basename $fname`")
    echo "Getting .hr url $fname into hr-$bfname" 
    $CURL -L "$fname" --output hr-$bfname
    if [[ $? == 0 ]]
    then
        if [ ! -s hr-$bfname ]
        then
            echo "Empty or non-existent downloaded Croatian file: hr-$bfname"
        else
            if [ ! -f $ARCHIVE/hr-$bfname ]
            then
                echo "New .hr file hr-$bfname" 
                cp hr-$bfname $ARCHIVE
            elif ((`stat -c%s "hr-$bfname"`>`stat -c%s "$ARCHIVE/hr-$bfname"`));then
                # if the new one is bigger than archived, then archive new one
                echo "Updated/bigger .hr file hr-$bfname" 
                cp hr-$bfname $ARCHIVE
            fi
        fi
    else
        echo "curl - error downloading hr-$bfname"
    fi
    # don't appear to be too keen:-)
    sleep 1
done

## now count 'em and push to web DocRoot

# Now that we're hitting 0.5M or more TEKS per hour (i.e. downloading
# that many - they aren't all new though), the counting stuff takes
# hours. So rather than re-implement it now to be more
# efficient, I'll just do the count twice a day for now.
# We still collect data every hour (that takes <15 mins)

hour=`date +%H`
even=$((hour%12))
if [[ "$even" != "0" ]]
then
    echo "Will only count TEKS at noon/midnight - it's now $hour"
    exit 0
fi

echo "Counting 'em..."
cd $ARCHIVE
$TEK_TIMES -F
# Try the last-14-days approach again see how long it takes
#$TEK_TIMES 
res=$?
if [[ "$res" == "18" ]]
then
    echo "$TEK_TIMES exited as >1 running, so I'll also exit"
    echo "Finished $0 at $END, got $chunks_down chunks, totalling $total_keys"
    echo "======================"
    echo "======================"
    echo "======================"
    exit 0
fi
if [ -d  $DOCROOT ]
then
    cp *.csv $DOCROOT
fi

# temporarily do dailies - just testing this for now
#cd $DAILIES
#$TOP/dailycounter.sh -d $TOP
# almost but not quite ready to turn on next version of this
# but not at an hourly cadence! will add a new cron job
# (For some reason this takes a loooooong time on down - grep
# seems substantially slower than my laptop)
#cd $DAILIES2
#$TOP/dailycounter2.sh -d $TOP
#$TOP/ground-truth.sh
#$TOP/tek_report2.sh

cd $ARCHIVE

$TEK_REPORT

END=$(whenisitagain)
echo "Finished $0 at $END, got $chunks_down chunks, totalling $total_keys"
echo "======================"
echo "======================"
echo "======================"
