#!/bin/bash

# set -x

# script to grab TEKs for various places, and stash 'em

CURL=/usr/bin/curl
UNZIP=/usr/bin/unzip
TEK_DECODE=/home/stephen/code/tek_transparency/tek_file_decode.py
TEK_TIMES=/home/stephen/code/tek_transparency/tek_times.sh
DOCROOT=/var/www/tact/tek-counts/
DE_CFG_DECODE=/home/stephen/code/tek_transparency/de_tek_cfg_decode.py
DATADIR=/home/stephen/code/tek_transparency
ARCHIVE=$DATADIR/all-zips

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

# italy

IT_BASE="https://get.immuni.gov.it/v1/keys"
IT_INDEX="$IT_BASE/index"
IT_CONFIG="https://get.immuni.gov.it/v1/settings?platform=android&build=1"

index_str=`$CURL -L $IT_INDEX`
bottom_chunk_no=`echo $index_str | awk '{print $2}' | sed -e 's/,//'`
top_chunk_no=`echo $index_str | awk '{print $4}' | sed -e 's/}//'`

echo "Bottom: $bottom_chunk_no, Top: $top_chunk_no"

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
        $UNZIP "it-$chunk_no.zip" >/dev/null 2>&1
        if [[ $? == 0 ]]
        then
            echo "======================"
            echo ".it TEKs"
            $TEK_DECODE
            new_keys=$?
            total_keys=$((total_keys+new_keys))
        fi
        rm -f export.bin export.sig
    else
        echo "Error decoding it-$chunk_no.zip"
    fi
    chunk_no=$((chunk_no+1))
    chunks_down=$((chunks_down+1))
done
curl -L $IT_CONFIG --output it-cfg.json
echo "======================"
echo ".it config:"
cat it-cfg.json

echo "======================"
echo "======================"
# Germany 

# not yet but, do stuff once this is non-empty 
# curl -L https://svc90.main.px.t-online.de/version/v1/diagnosis-keys/country/DE/date -i

DE_BASE="https://svc90.main.px.t-online.de/version/v1/diagnosis-keys/country/DE"
DE_INDEX="$DE_BASE/date"
# .de index format so far: ["2020-06-23"]
# let's home tomorrow will be ["2020-06-23","2020-06-24"]
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
        if [ ! -f $ARCHIVE/de-$dedate.zip ]
        then
            cp de-$dedate.zip $ARCHIVE
        fi
        # try unzip and decode
        $UNZIP "de-$dedate.zip" >/dev/null 2>&1
        if [[ $? == 0 ]]
        then
            echo "======================"
            echo ".de TEKs"
            $TEK_DECODE
            new_keys=$?
            total_keys=$((total_keys+new_keys))
        fi
        rm -f export.bin export.sig
    else
        echo "Error decoding de-$dedate.zip"
    fi
    chunks_down=$((chunks_down+1))
done

DE_CONFIG="https://svc90.main.px.t-online.de/version/v1/configuration/country/DE/app_config"
curl -L $DE_CONFIG --output de-cfg.zip
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
midnight="`date -d "00:00:00Z" +%s`000"

$CURL -L "$CH_BASE/$midnight" --output ch-$midnight.zip
if [[ $? == 0 ]]
then
    if [ ! -f $ARCHIVE/ch-$midnight.zip ]
    then
        cp ch-$midnight.zip $ARCHIVE
    fi
    # try unzip and decode
    $UNZIP "ch-$midnight.zip" >/dev/null 2>&1
    if [[ $? == 0 ]]
    then
        echo "======================"
        echo ".ch TEKs"
        $TEK_DECODE
        new_keys=$?
        total_keys=$((total_keys+new_keys))
    fi
    rm -f export.bin export.sig
    chunks_down=$((chunks_down+1))
else
    echo "Error decoding ch-$midnight.zip"
fi

CH_CONFIG="https://www.pt-a.bfs.admin.ch/v1/config?appversion=1&osversion=ios&buildnr=1"
curl -L $CH_CONFIG --output ch-cfg.json
echo ".ch config:"
cat ch-cfg.json

## now count 'em and push to web DocRoot

echo "Counting 'em..."
cd $ARCHIVE
$TEK_TIMES
if [ -d  $DOCROOT ]
then
    cp *.csv $DOCROOT
fi

END=$(whenisitagain)
echo "Finished IT at $END, got $chunks_down chunks, totalling $total_keys"
echo "======================"
echo "======================"
echo "======================"
