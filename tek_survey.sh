#!/bin/bash

# set -x

# script to grab TEKs for various places, and stash 'em

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${DOCROOT:='/var/www/tact/tek-counts/'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$TOP"}
x=${ARCHIVE:="$DATADIR/all-zips"}
x=${DAILIES:="$DATADIR/dailies"}
x=${DAILIES2:="$DATADIR/dailies2"}

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
			    iebname=`basename $iefile`
			    $CURL -s -L "$IE_BASE/data/$iefile" --output ie-$iebname -H "Authorization: Bearer $newtoken"
			    if [[ $? == 0 ]]
			    then
                    # we should be good now, so remove canary
                    rm -f $IE_CANARY
			        echo "Got ie-$iebname"
			        if [ ! -f $ARCHIVE/ie-$iebname ]
			        then
			            cp ie-$iebname $ARCHIVE
			        fi
			        # try unzip and decode
                    if [[ "$DODECODE" == "yes" ]]
                    then
                        $UNZIP "ie-$iebname" >/dev/null 2>&1
                        if [[ $? == 0 ]]
                        then
                            tderr=`mktemp /tmp/tderrXXXX`
                            $TEK_DECODE >/dev/null 2>$tderr 
                            new_keys=$?
                            total_keys=$((total_keys+new_keys))
                            tderrsize=`stat -c%s $tderr`
                            if [[ "$tderrsize" != '0' ]] 
                            then
                                echo "tek-decode error processing ie-$iebname"
                            fi
                            rm -f $tderr
                        fi
                        rm -f export.bin export.sig
                        chunks_down=$((chunks_down+1))
                    fi
			    else
			        echo "Error decoding ie-$iebname"
			    fi
			done
	
		fi
	fi
fi

# Northern Ireland

# Same setup as Ireland app-wise

# NI is a region of the UK, so for now, we'll use the
# prefix "uk-ni" and I don't yet have a source for the
# numbers of cases for the region, which is TBD

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
			    nibname=`basename $nifile`
			    $CURL -s -L "$NI_BASE/data/$nifile" --output ukni-$nibname -H "Authorization: Bearer $newtoken"
			    if [[ $? == 0 ]]
			    then
                    # we should be good now, so remove canary
                    rm -f $NI_CANARY
			        echo "Got ukni-$nibname"
			        if [ ! -f $ARCHIVE/ukni-$nibname ]
			        then
			            cp ukni-$nibname $ARCHIVE
			        fi
			        # try unzip and decode
                    if [[ "$DODECODE" == "yes" ]]
                    then
                        $UNZIP "ukni-$nibname" >/dev/null 2>&1
                        if [[ $? == 0 ]]
                        then
                            $TEK_DECODE >/dev/null
                            new_keys=$?
                            total_keys=$((total_keys+new_keys))
                        fi
                        rm -f export.bin export.sig
                        chunks_down=$((chunks_down+1))
                    fi
			    else
			        echo "Error decoding ukni-$nibname"
			    fi
			done
	
		fi
	fi
fi

# italy

IT_BASE="https://get.immuni.gov.it/v1/keys"
IT_INDEX="$IT_BASE/index"
IT_CONFIG="https://get.immuni.gov.it/v1/settings?platform=android&build=1"

index_str=`$CURL -L $IT_INDEX`
bottom_chunk_no=`echo $index_str | awk '{print $2}' | sed -e 's/,//'`
top_chunk_no=`echo $index_str | awk '{print $4}' | sed -e 's/}//'`

echo "Bottom: $bottom_chunk_no, Top: $top_chunk_no"

echo "======================"
echo ".it TEKs"
total_keys=0
chunks_down=0
chunk_no=$bottom_chunk_no
while [ $chunk_no -le $top_chunk_no ]
do
    $CURL -L "$IT_BASE/{$chunk_no}" --output it-$chunk_no.zip
    if [[ $? == 0 ]]
    then
        if [ ! -f $ARCHIVE/it-$chunk_no.zip ]
        then
            cp it-$chunk_no.zip $ARCHIVE
        fi
        # try unzip and decode
        if [[ "$DODECODE" == "yes" ]]
        then
            $UNZIP "it-$chunk_no.zip" >/dev/null 2>&1
            if [[ $? == 0 ]]
            then
                $TEK_DECODE >/dev/null
                new_keys=$?
                total_keys=$((total_keys+new_keys))
            fi
            rm -f export.bin export.sig
        fi
    else
        echo "Error decoding it-$chunk_no.zip"
    fi
    chunk_no=$((chunk_no+1))
    chunks_down=$((chunks_down+1))
done
$CURL -L $IT_CONFIG --output it-cfg.json
echo "======================"
echo ".it config:"
cat it-cfg.json

echo "======================"
echo "======================"
# Germany 

# not yet but, do stuff once this is non-empty 
# $CURL -L https://svc90.main.px.t-online.de/version/v1/diagnosis-keys/country/DE/date -i

DE_BASE="https://svc90.main.px.t-online.de/version/v1/diagnosis-keys/country/DE"
DE_INDEX="$DE_BASE/date"

# .de index format so far: ["2020-06-23"]
# let's home tomorrow will be ["2020-06-23","2020-06-24"]
echo "======================"
echo ".de TEKs"
index_str=`$CURL -L $DE_INDEX` 
echo "German index string: $index_str"
dedates=`echo $index_str \
                | sed -e 's/\[//' \
                | sed -e 's/]//' \
                | sed -e 's/"//g' \
                | sed -e 's/,/ /g' `
for dedate in $dedates
do

    $CURL -L "$DE_BASE/date/$dedate" --output de-$dedate.zip
    if [[ $? == 0 ]]
    then
        echo "Got de-$dedate.zip"
        if [ ! -f $ARCHIVE/de-$dedate.zip ]
        then
            cp de-$dedate.zip $ARCHIVE
        fi
        # try unzip and decode
        if [[ "$DODECODE" == "yes" ]]
        then
            $UNZIP "de-$dedate.zip" >/dev/null 2>&1
            if [[ $? == 0 ]]
            then
                $TEK_DECODE >/dev/null
                new_keys=$?
                total_keys=$((total_keys+new_keys))
            fi
            rm -f export.bin export.sig
            chunks_down=$((chunks_down+1))
        fi
    else
        echo "Error decoding de-$dedate.zip"
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
        $CURL -L "$DE_BASE/date/$dedate/hour/$dehour" --output de-$dedate-$dehour.zip
        if [[ $? == 0 ]]
        then
            echo "Got de-$dedate-$dehour.zip"
            if [ ! -f $ARCHIVE/de-$dedate-$dehour.zip ]
            then
                cp de-$dedate-$dehour.zip $ARCHIVE
            fi
            # try unzip and decode
            if [[ "$DODECODE" == "yes" ]]
            then
                $UNZIP "de-$dedate-$dehour.zip" >/dev/null 2>&1
                if [[ $? == 0 ]]
                then
                    $TEK_DECODE >/dev/null
                    new_keys=$?
                    total_keys=$((total_keys+new_keys))
                fi
                rm -f export.bin export.sig
                chunks_down=$((chunks_down+1))
            fi
        else
            echo "Error decoding de-$dedate-$dehour.zip"
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
    $CURL -L "$DE_BASE/date/$today/hour/$dehour" --output de-$today-$dehour.zip
    if [[ $? == 0 ]]
    then
        echo "Got de-$today-$dehour.zip"
        if [ ! -f $ARCHIVE/de-$today-$dehour.zip ]
        then
            cp de-$today-$dehour.zip $ARCHIVE
        fi
        # try unzip and decode
        if [[ "$DODECODE" == "yes" ]]
        then
            $UNZIP "de-$today-$dehour.zip" >/dev/null 2>&1
            if [[ $? == 0 ]]
            then
                $TEK_DECODE >/dev/null
                new_keys=$?
                total_keys=$((total_keys+new_keys))
            fi
            rm -f export.bin export.sig
            chunks_down=$((chunks_down+1))
        fi
    else
        echo "Error decoding de-$today-$dehour.zip"
    fi
done


DE_CONFIG="https://svc90.main.px.t-online.de/version/v1/configuration/country/DE/app_config"
$CURL -L $DE_CONFIG --output de-cfg.zip
if [ -f de-cfg.zip ]
then
    $UNZIP de-cfg.zip
    if [[ $? == 0 ]]
    then
        echo ".de config:"
        $DE_CFG_DECODE 
        rm -f export.bin export.sig
    fi 
fi
DE_KEYS="https://github.com/micb25/dka/raw/master/data_CWA/diagnosis_keys_statistics.csv"
$CURL -L $DE_KEYS --output de-keys.csv

echo "======================"
echo "======================"

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

echo "======================"
echo ".ch TEKs"
for fno in {0..15}
do
	echo "Doing .ch file $fno" 
	midnight=$((today_midnight-fno*day))
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
            if [[ "$DODECODE" == "yes" ]]
            then
    		    $UNZIP "ch-$midnight.zip" >/dev/null 2>&1
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
    	echo "curl - error downloading ch-$midnight.zip (file $fno)"
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

# Poland

# yes - we end up with two slashes between hostname and path for some reason!
PL_BASE="https://exp.safesafe.app/" 
PL_CONFIG="dunno; get later"


echo "======================"
echo ".pl TEKs"
plzips=`$CURL -L "$PL_BASE/index.txt" | sed -e 's/\///g'`
for plzip in $plzips
do
    echo "Getting $plzip"
    $CURL -L "$PL_BASE/$plzip" --output pl-$plzip
    if [[ $? == 0 ]]
    then
	    if [ ! -s pl-$plzip ]
	    then
		    echo "Empty or non-existent Polish file: pl-$plzip"
	    else
    	    if [ ! -f $ARCHIVE/pl-$plzip ]
    	    then
        	    cp pl-$plzip $ARCHIVE
    	    fi
    	    # try unzip and decode
            if [[ "$DODECODE" == "yes" ]]
            then
    	        $UNZIP "pl-$plzip" >/dev/null 2>&1
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
        echo "Error downloading pl-$plzip"
    fi
done

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


# Denmark

DK_BASE="https://app.smittestop.dk/API/v1/diagnostickeys"
DK_CONFIG="$DK_BASE/exposureconfiguration"

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
fi

echo "======================"
echo ".dk TEKs"

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
                if [[ "$DODECODE" == "yes" ]]
                then
                    $UNZIP "$the_local_zip_name" >/dev/null 2>&1
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
            echo "Didn't get a $the_zip_name" 
            more_to_come=""
        fi
        # let's not be too insistent
        sleep 1

    done    
done
echo "======================"

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

zipnames=`cat at.index.json | sed -e 's/\["/\n/g' | sed -e 's/"\].*//g' | grep exposure`

for zipname in $zipnames
do
    echo $zipname
    zipurl=https://cdn.prod-rca-coronaapp-fd.net/$zipname
    the_zip_name=`basename $zipname`
    the_local_zip_name="at-$the_zip_name"
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
            if [[ "$DODECODE" == "yes" ]]
            then
                $UNZIP "$the_local_zip_name" >/dev/null 2>&1
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
        echo "Didn't get a $the_zip_name" 
        more_to_come=""
    fi
    # let's not be too insistent
    sleep 1

done

echo "======================"

# Latvia
echo "======================"
echo ".lv Teks"
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
            the_local_zip_name="lv-`basename $theurl`"
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
                    if [[ "$DODECODE" == "yes" ]]
                    then
                        $UNZIP "$the_local_zip_name" >/dev/null 2>&1
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
                echo "Didn't get a $the_zip_name" 
            fi
            # let's not be too insistent
            sleep 1
        done
    fi
fi
echo "======================"

# Spain

# This is still in test so we'll collect, but not yet report

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

echo "======================"
echo ".es TEKs"
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
            if [[ "$DODECODE" == "yes" ]]
            then
    		    $UNZIP "es-$midnight.zip" >/dev/null 2>&1
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
echo ".es config:"
cat es-cfg.json

# US Virginia

USVA_CANARY="$ARCHIVE/usva-canary"
USVA_BASE="https://storage.googleapis.com/prod-export-key"
USVA_INDEX="$USVA_BASE/exposureKeyExport-US/index.txt"
USVA_CONFIG="$USVA_BASE/settings/"

# USVA config is hardcoded in the app apparently (for now)
# $CURL --output usva-cfg.json -L $USVA_CONFIG

echo "======================"
echo "US Virginia TEKs"

response_headers=`$CURL -D - -o usva-index-headers.txt -L "$USVA_INDEX" -i`
clzero=`echo $response_headers | grep -ic "Content-Length: 0"`
if [[ "$clzero" != "0" ]]
then
    echo "Skipping US Virginia because content length still zero at $NOW." 
else
    # download again, without headers
    sleep 1
    $CURL -o usva-index.txt -L "$USVA_INDEX"
    # this may not be correct, will find out as we go...
    for path in `cat usva-index.txt`
    do
        sleep 1
        zname=`echo $path | sed -e 's/.*\///'`
        lpath=usva-$zname
        $CURL -D - -o $lpath -L "$USVA_BASE/$path" 
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
            if [[ "$DODECODE" == "yes" ]]
            then
                $UNZIP "$lpath" >/dev/null 2>&1
                if [[ $? == 0 ]]
                then
                    $TEK_DECODE >/dev/null
                    new_keys=$?
                    total_keys=$((total_keys+new_keys))
                fi
                rm -f export.bin export.sig
                chunks_down=$((chunks_down+1))
            fi
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
#THEN=`date -d "2020-08-19T14:00:00" +%s`
#timeStr=$((THEN/3600))
#MESSAGE="$MCC_CODE:$periodStr:$timeStr"
#THENCODE=`echo -n $MESSAGE | openssl sha256 -hmac "$HMAC_KEY" | awk '{print $2}'`
#CA_INDEX="$CA_BASE/retrieve/MCC_CODE/$periodStr/$THENCODE"
#echo "want cc0b17155fe1d642495dfc1dd0230c33573def6c35a33b61260306d797637e33"

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
            if [[ "$DODECODE" == "yes" ]]
            then
                $UNZIP "$lpath" >/dev/null 2>&1
                if [[ $? == 0 ]]
                then
                    $TEK_DECODE >/dev/null
                    new_keys=$?
                    total_keys=$((total_keys+new_keys))
                fi
                rm -f export.bin export.sig
                chunks_down=$((chunks_down+1))
            fi
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

USAL_CANARY="$ARCHIVE/usal-canary"
USAL_BASE="https://covidexposure-files-store.azureedge.net"
USAL_INDEX="$USAL_BASE/index.txt"
USAL_CONFIG="$USAL_BASE/settings/"

echo "======================"
echo "US Alabama TEKs"

response_headers=`$CURL -D - -o usal-index-headers.txt -L "$USAL_INDEX" -i`
clzero=`echo $response_headers | grep -ic "Content-Length: 0"`
if [[ "$clzero" != "0" ]]
then
    echo "Skipping US Alabama because content length still zero at $NOW." 
else
    # download again, without headers
    sleep 1
    $CURL -o usal-index.txt -L "$USAL_INDEX"
    # this may not be correct, will find out as we go...
    for url in `cat usal-index.txt | awk '{print $1}'`
    do
        sleep 1
        zname=`basename $url`
        lpath=usal-$zname
        $CURL -D - -o $lpath -L "$url"
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
            if [[ "$DODECODE" == "yes" ]]
            then
                $UNZIP "$lpath" >/dev/null 2>&1
                if [[ $? == 0 ]]
                then
                    $TEK_DECODE >/dev/null
                    new_keys=$?
                    total_keys=$((total_keys+new_keys))
                fi
                rm -f export.bin export.sig
                chunks_down=$((chunks_down+1))
            fi
        else
            echo "Failed to download $lpath"
            echo "Failed to download $lpath at $NOW" >$USAL_CANARY
        fi
    done
fi

# Estonia

EE_BASE="https://enapi.sm.ee/authorization/v1/gaen/exposed"
now=`date +%s`
toay_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

echo "======================"
echo ".ee TEKs"
for fno in {0..14}
do
	echo "Doing .ee file $fno" 
	midnight=$((toay_midnight-fno*day))
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
            if [[ "$DODECODE" == "yes" ]]
            then
    		    $UNZIP "ee-$midnight.zip" >/dev/null 2>&1
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
    	echo "curl - error downloading ee-$midnight.zip (file $fno)"
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

# Finland

CANARY="$ARCHIVE/fi-canary"
FI_BASE="https://taustajarjestelma.koronavilkku.fi/diagnosis"
FI_CONFIG="https://taustajarjestelma.koronavilkku.fi/exposure/configuration/v1"
FI_CONFIG2="https://repo.thl.fi/sites/koronavilkku/yhteystiedot.json"

# Server needs crazy user agent for some reason
FI_UA="-A Koronavilkku/1.0.0.174"


$CURL -o fi-cfg.json -L $FI_CONFIG $FI_UA
$CURL -o fi-cfg2.json -L $FI_CONFIG2 $FI_UA

if [ ! -f $CANARY ]
then
	fi_index=`$CURL -L "$FI_BASE/v1/list?previous=0" $FI_UA`
	if [[ "$?" == "0" ]]
	then
        echo "Finnish index: $fi_index"
        batches=`echo $fi_index |  sed -e 's/","/ /g' | sed -e 's/"]}//' | sed -e 's/.*"//'`
        for batch in $batches
        do
            $CURL -o fi-$batch.zip -L "$FI_BASE/v1/batch/$batch" $FI_UA
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
                    if [[ "$DODECODE" == "yes" ]]
                    then
                        $UNZIP "fi-$batch.zip" >/dev/null 2>&1
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
                echo "curl - error downloading fi-$batch.zip (file $fno)"
            fi
        done
	fi
fi

# Scotland

CANARY="$ARCHIVE/uksc-canary"
UKSC_INDEX="https://api-scot-prod.nearform-covid-services.com/api/exposures/?since=0&limit=1000"
UKSC_BASE="https://api-scot-prod.nearform-covid-services.com/api/data"
UKSC_REFRESH="https://api-scot-prod.nearform-covid-services.com/api/refresh"
UKSC_CONFIG="https://api-scot-prod.nearform-covid-services.com/api/settings/exposures"
UKSC_LANG="https://api-scot-prod.nearform-covid-services.com/api/settings/language"
UKSC_STATS="https://api-scot-prod.nearform-covid-services.com/api/stats"

# used to notify us that something went wrong
CANARY="$ARCHIVE/uksc-canary"
UKSC_RTFILE="$HOME/uksc-refreshToken.txt"

echo "======================"
echo "Scotland TEKs"

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
            # config now requires authz for some reason
            $CURL --output uksc-cfg.json -L $UKSC_CONFIG -H "Authorization: Bearer $newtoken"` 
            $CURL --output uksc-stats.json -L $UKSC_STATS -H "Authorization: Bearer $newtoken"` 

            index_str=`$CURL -L "$UKSC_INDEX" -H "Authorization: Bearer $newtoken"`  
            if [[ $? != 0 ]]
            then
                echo "Error getting index string: $index_str ($?)"
                exit 1
            fi
            echo "Scotland index string: $index_str"
			ukscfiles=""
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
            for ukscfile in $ukscfiles
            do
                echo "Getting $ukscfile"
                ukscname=`basename $ukscfile`
                $CURL -L "$UKSC_BASE/$ukscfile" --output uksc-$ukscname -H "Authorization: Bearer $newtoken"
                if [[ $? == 0 ]]
                then
                    # we should be good now, so remove canary
                    rm -f $CANARY
                    echo "Got uksc-$ukscname"
                    if [ ! -f $ARCHIVE/uksc-$ukscname ]
                    then
                        cp uksc-$ukscname $ARCHIVE
                    fi
                    # try unzip and decode
                    if [[ "$DODECODE" == "yes" ]]
                    then
                        $UNZIP "uksc-$ukscname" >/dev/null 2>&1
                        if [[ $? == 0 ]]
                        then
                            $TEK_DECODE >/dev/null
                            new_keys=$?
                            total_keys=$((total_keys+new_keys))
                        fi
                        rm -f export.bin export.sig
                        chunks_down=$((chunks_down+1))
                    fi
                else
                    echo "Error decoding uksc-$ukscname"
                fi
            done

        fi
    fi
fi

# Delaware

CANARY="$ARCHIVE/usde-canary"
USDE_INDEX="https://encdn.prod.exposurenotification.health/v1/index.txt"
USDE_BASE="https://encdn.prod.exposurenotification.health/"
USDE_REFRESH="https://api-dela-prod.nearform-covid-services.com/api/refresh"
USDE_CONFIG="https://api-dela-prod.nearform-covid-services.com/api/settings/exposures"
USDE_LANG="https://api-dela-prod.nearform-covid-services.com/api/settings/language"
USDE_STATS="https://api-dela-prod.nearform-covid-services.com/api/stats"

# used to notify us that something went wrong
CANARY="$ARCHIVE/usde-canary"
USDE_RTFILE="$HOME/usde-refreshToken.txt"

echo "======================"
echo "Delaware TEKs"

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
    exit 1
fi
echo "Delaware index string: $index_str"
for usdefile in $index_str
do
    echo "Getting $usdefile"
    usdename=`basename $usdefile`
    $CURL -s -L "$USDE_BASE/$usdefile" --output usde-$usdename 
    if [[ $? == 0 ]]
    then
        # we should be good now, so remove canary
        rm -f $CANARY
        echo "Got usde-$usdename"
        if [ ! -f $ARCHIVE/usde-$usdename ]
        then
            cp usde-$usdename $ARCHIVE
        fi
        # try unzip and decode
        if [[ "$DODECODE" == "yes" ]]
        then
            $UNZIP "usde-$usdename" >/dev/null 2>&1
            if [[ $? == 0 ]]
            then
                $TEK_DECODE >/dev/null
                new_keys=$?
                total_keys=$((total_keys+new_keys))
            fi
            rm -f export.bin export.sig
            chunks_down=$((chunks_down+1))
        fi
    else
        echo "Error decoding usde-$usdename"
    fi
done

# Nevada

# 20210204: looks like this has migrated to US national server
# TODO: update the output page to reflect which US states do the same, there's a map at:
# https://www.aphl.org/programs/preparedness/Crisis-Management/COVID-19-Response/Pages/exposure-notifications.aspx

USNV_INDEX="https://exposure-notification-export-cpmxr.storage.googleapis.com/exposure-keys/index.txt"
USNV_BASE="https://exposure-notification-export-cpmxr.storage.googleapis.com"
USNV_CONFIG="https://static.nvcovidtrace.com/remote.json"
CANARY="$ARCHIVE/usnv-canary"

echo "======================"
echo "Nevada TEKs"

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
    usnvname=`basename $usnvfile`
    $CURL -s -L "$USNV_BASE/$usnvfile" --output usnv-$usnvname 
    if [[ $? == 0 ]]
    then
        # we should be good now, so remove canary
        rm -f $CANARY
        echo "Got usnv-$usnvname"
        if [ ! -f $ARCHIVE/usnv-$usnvname ]
        then
            cp usnv-$usnvname $ARCHIVE
        fi
        # try unzip and decode
        if [[ "$DODECODE" == "yes" ]]
        then
            $UNZIP "usnv-$usnvname" >/dev/null 2>&1
            if [[ $? == 0 ]]
            then
                $TEK_DECODE >/dev/null
                new_keys=$?
                total_keys=$((total_keys+new_keys))
            fi
            rm -f export.bin export.sig
            chunks_down=$((chunks_down+1))
        fi
    else
        echo "Error decoding usnv-$usnvname"
        echo "Error decoding usnv-$usnvname at $NOW" >$CANARY
    fi
done

# Wyoming

CANARY="$ARCHIVE/uswy-canary"
USWY_INDEX="https://encdn.prod.exposurenotification.health/v1/index.txt"
USWY_BASE="https://encdn.prod.exposurenotification.health"
USWY_CONFIG="https://exposureapi.care19.app/api/v1/apps/2/devices/b640737e-aada-42c7-9bf5-0d453de1d084/exposureconfig?regionId=5"

# used to notify us that something went wrong
CANARY="$ARCHIVE/uswy-canary"

echo "======================"
echo "Wyoming TEKs"

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
    uswyname=`basename $uswyfile`
    $CURL -s -L "$USWY_BASE/$uswyfile" --output uswy-$uswyname 
    if [[ $? == 0 ]]
    then
        # we should be good now, so remove canary
        rm -f $CANARY
        echo "Got uswy-$uswyname"
        if [ ! -f $ARCHIVE/uswy-$uswyname ]
        then
            cp uswy-$uswyname $ARCHIVE
        fi
        # try unzip and decode
        if [[ "$DODECODE" == "yes" ]]
        then
            $UNZIP "uswy-$uswyname" >/dev/null 2>&1
            if [[ $? == 0 ]]
            then
                $TEK_DECODE >/dev/null
                new_keys=$?
                total_keys=$((total_keys+new_keys))
            fi
            rm -f export.bin export.sig
            chunks_down=$((chunks_down+1))
        fi
    else
        echo "Error decoding uswy-$uswyname"
    fi
done

# Brasil

CANARY="$ARCHIVE/br-canary"
BR_INDEX="https://exposure-notification.saude.gov.br/exposureKeyExport-BR/index.txt"
BR_BASE="https://exposure-notification.saude.gov.br"

# used to notify us that something went wrong
CANARY="$ARCHIVE/br-canary"

echo "======================"
echo "Brazil TEKs"

index_str=`$CURL -s -L "$BR_INDEX"` 
if [[ $? != 0 ]]
then
    echo "Error getting index string: $index_str ($?)"
    exit 1
fi
echo "Brazil index string: $index_str"
for brfile in $index_str
do
    echo "Getting $brfile"
    brname=`basename $brfile`
    $CURL -s -L "$BR_BASE/$brfile" --output br-$brname 
    if [[ $? == 0 ]]
    then
        # we should be good now, so remove canary
        rm -f $CANARY
        echo "Got br-$brname"
        if [ ! -f $ARCHIVE/br-$brname ]
        then
            cp br-$brname $ARCHIVE
        fi
        # try unzip and decode
        if [[ "$DODECODE" == "yes" ]]
        then
            $UNZIP "br-$brname" >/dev/null 2>&1
            if [[ $? == 0 ]]
            then
                $TEK_DECODE >/dev/null
                new_keys=$?
                total_keys=$((total_keys+new_keys))
            fi
            rm -f export.bin export.sig
            chunks_down=$((chunks_down+1))
        fi
    else
        echo "Error decoding br-$brname"
    fi
done

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

    $CURL -o ukenw-$batch.zip -L "$UKEN_BASE/$batch.zip"
    if [[ $? == 0 ]]
    then
        # we do see zero sized files from .es sometimes
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
            if [[ "$DODECODE" == "yes" ]]
            then
                $UNZIP "ukenw-$batch.zip" >/dev/null 2>&1
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
        echo "curl - error downloading ukenw-$batch.zip (file $fno)"
    fi

done


# Gibraltar

# used to notify us that something went wrong
CANARY="$ARCHIVE/ukgi-canary"
GI_RTFILE="$HOME/ukgi-refreshToken.txt"
GI_BASE="https://app.beatcovid19.gov.gi/api"
GI_CONFIG="$GI_BASE/settings/"

$CURL --output ukgi-cfg.json -L $GI_CONFIG

echo "======================"
echo "Gibraltar TEKs"

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
			    gibname=`basename $gifile`
			    $CURL -s -L "$GI_BASE/data/$gifile" --output ukgi-$gibname -H "Authorization: Bearer $newtoken"
			    if [[ $? == 0 ]]
			    then
                    # we should be good now, so remove canary
                    rm -f $CANARY
			        echo "Got ukgi-$gibname"
			        if [ ! -f $ARCHIVE/ukgi-$gibname ]
			        then
			            cp ukgi-$gibname $ARCHIVE
			        fi
			        # try unzip and decode
                    if [[ "$DODECODE" == "yes" ]]
                    then
			            $UNZIP "ukgi-$gibname" >/dev/null 2>&1
			            if [[ $? == 0 ]]
			            then
			                $TEK_DECODE >/dev/null
			                new_keys=$?
			                total_keys=$((total_keys+new_keys))
			            fi
			            rm -f export.bin export.sig
			            chunks_down=$((chunks_down+1))
                    fi
			    else
			        echo "Error decoding ukgi-$gibname"
			    fi
			done
	
		fi
	fi
fi

# Malta

MT_BASE="https://mt-dpppt-ws.azurewebsites.net/v1/gaen/exposed"
MT_CONFIG="https://mt-dpppt-config.azurewebsites.net/v1/config?appversion=android-1.2.8&osversion=android28&buildnr=1599138353411"
$CURL -L $MT_CONFIG --output mt-cfg.json

now=`date +%s`
today_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

echo "======================"
echo ".mt TEKs"
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
            if [[ "$DODECODE" == "yes" ]]
            then
    		    $UNZIP "mt-$midnight.zip" >/dev/null 2>&1
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
    	echo "curl - error downloading mt-$midnight.zip (file $fno)"
	fi
	# don't appear to be too keen:-)
	sleep 1
done

# Portugal

PT_BASE="https://stayaway.incm.pt/v1/gaen/exposed"
PT_CONFIG="https://stayaway.incm.pt/config/defaults.json"

$CURL -L $PT_CONFIG --output pt-cfg.json

now=`date +%s`
today_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

echo "======================"
echo ".pt TEKs"
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
            if [[ "$DODECODE" == "yes" ]]
            then
    		    $UNZIP "pt-$midnight.zip" >/dev/null 2>&1
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
    	echo "curl - error downloading pt-$midnight.zip (file $fno)"
	fi
	# don't appear to be too keen:-)
	sleep 1
done

# Ecuador

EC_BASE="https://contacttracing.covidanalytics.ai/v1/gaen/exposed"
EC_CONFIG="https://contacttracing.covidanalytics.ai/v1/config?appversion=android-0.0.12-pilot&osversion=android28&buildnr=1598659886251"

$CURL -L $EC_CONFIG --output ec-cfg.json

now=`date +%s`
today_midnight="`date -d "00:00:00Z" +%s`000"

# one day in milliseconds
day=$((60*60*24*1000))

echo "======================"
echo ".ec TEKs"
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
            if [[ "$DODECODE" == "yes" ]]
            then
    		    $UNZIP "ec-$midnight.zip" >/dev/null 2>&1
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
    	echo "curl - error downloading ec-$midnight.zip (file $fno)"
	fi
	# don't appear to be too keen:-)
	sleep 1
done

# Belgium

CANARY="$ARCHIVE/be-canary"
BE_BASE="https://c19distcdn-prd.ixor.be/version/v1/diagnosis-keys/country/BE/date"
BE_CONFIG="https://c19distcdn-prd.ixor.be/version/v1/configuration/country/BE/app_config"
BE_STATS="https://c19statcdn-prd.ixor.be/statistics/statistics.json"

$CURL -L $BE_CONFIG --output be-cfg.json
$CURL -L $BE_STATS --output be-stats.json

if [ ! -f $CANARY ]
then
	be_index=`$CURL -L "$BE_BASE"`
	if [[ "$?" == "0" ]]
	then
        echo "Belgian index: $be_index"
        batches=`echo $be_index | sed -e 's/\[//' | sed -e 's/]//' | sed -e 's/"//g' | sed -e 's/,/ /g'`
        for batch in $batches
        do
            $CURL -o be-$batch.zip -L "$BE_BASE/$batch"
            if [[ $? == 0 ]]
            then
                # we do see zero sized files from .es sometimes
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
                    if [[ "$DODECODE" == "yes" ]]
                    then
                        $UNZIP "be-$batch.zip" >/dev/null 2>&1
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
                echo "curl - error downloading be-$batch.zip (file $fno)"
            fi
        done
	fi
fi

# Czechia

CZ_BASE="https://storage.googleapis.com/exposure-notification-export-qhqcx"

echo "======================"
echo ".cz TEKs"
cz_index=`$CURL -L "$CZ_BASE/erouska/index.txt"`
echo "CZ index at $NOW: $cz_index"
for fno in $cz_index
do
	echo "Doing .cz file $fno" 
    bfno=`basename $fno`
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
            if [[ "$DODECODE" == "yes" ]]
            then
    		    $UNZIP "cz-$bfno" >/dev/null 2>&1
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
    	echo "curl - error downloading cz-$bfno"
	fi
	# don't appear to be too keen:-)
	sleep 1
done

# South Africa

ZA_BASE="https://files.ens.connect.sacoronavirus.co.za"

echo "======================"
echo ".za TEKs"
za_index=`$CURL -L "$ZA_BASE/exposureKeyExport-ZA/index.txt"`
echo "ZA index at $NOW: $za_index"
for fno in $za_index
do
	echo "Doing .za file $fno" 
    bfno=`basename $fno`
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

# Hungary

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

# Netherlands

echo "======================"
echo ".NL TEKs"
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

	for key in $nl_keys
	do
		echo "Getting .nl file $key" 
		$CURL -L "$NL_BASE/exposurekeyset/$key" --output nl-$key.zip
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
                if [[ "$DODECODE" == "yes" ]]
                then
	                rm -f content.bin content.sig export.bin export.sig
	    		    $UNZIP "nl-$key.zip" >/dev/null 2>&1
	    		    if [[ $? == 0 ]]
	    		    then
	        		    $TEK_DECODE >/dev/null
	        		    new_keys=$?
	                    total_keys=$((total_keys+new_keys))
	    		    fi
	                rm -f content.bin content.sig export.bin export.sig
	    		    chunks_down=$((chunks_down+1))
                fi
			fi
		else
	    	echo "error downloading nl-$key.zip"
		fi
        # permission granted to be speedy:-)
		# sleep 1
	done
	
fi

# Guam

GU_BASE="https://cdn.projectaurora.cloud"

echo "======================"
echo ".gu TEKs"
gu_index=`$CURL -L "$GU_BASE/guam/teks/index.txt"`
echo "GU index at $NOW: $gu_index"
for fno in $gu_index
do
	echo "Doing .gu file $fno" 
    bfno=`basename $fno`
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
            if [[ "$DODECODE" == "yes" ]]
            then
    		    $UNZIP "gu-$bfno" >/dev/null 2>&1
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
    	echo "curl - error downloading gu-$bfno"
	fi
	# don't appear to be too keen:-)
	sleep 1
done

# Slovenia

CANARY="$ARCHIVE/si-canary"
SI_BASE="https://svc90.cwa.gov.si/version/v1/diagnosis-keys/country/SI/date"
SI_CONFIG="https://svc90.cwa.gov.si/version/v1/configuration/country/SI/app_config"
# endpoing doesn't seem to exist in .si
#SI_STATS=""

$CURL -L $SI_CONFIG --output si-cfg.json
#$CURL -L $SI_STATS --output si-stats.json

if [ ! -f $CANARY ]
then
	si_index=`$CURL -L "$SI_BASE"`
	if [[ "$?" == "0" ]]
	then
        echo "Slovenian index: $si_index"
        batches=`echo $si_index | sed -e 's/\[//' | sed -e 's/]//' | sed -e 's/"//g' | sed -e 's/,/ /g'`
        for batch in $batches
        do
            $CURL -o si-$batch.zip -L "$SI_BASE/$batch"
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
                    if [[ "$DODECODE" == "yes" ]]
                    then
                        $UNZIP "si-$batch.zip" >/dev/null 2>&1
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
                echo "curl - error downloading si-$batch.zip (file $fno)"
            fi
        done
	fi
fi


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
    bn=`basename $path`
    $CURL $FR_BASE/$path --output fr-$bn
done

## Croatia

HR_INDEX="https://en.apis-it.hr/submission/diagnosis-key-file-urls"
HR_INDEX_EU="https://en.apis-it.hr/submission/diagnosis-key-file-urls?all=true"

echo "======================"
echo ".hr TEKs"
zips=`$CURL -L "$HR_INDEX" | jq ".urlList" | grep \" | sed -e 's/"//g' | sed -e 's/,//g'` 
zips_eu=`$CURL -L "$HR_INDEX_EU" | jq ".urlList" | grep \" | sed -e 's/"//g' | sed -e 's/,//g'` 
echo "HR index at $NOW: $zips $zips_eu"
for fname in $zips $zips_eu
do
    bfname=`basename $fname`
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
