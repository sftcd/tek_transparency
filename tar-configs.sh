#!/bin/bash

# set -x

# script to get all the configs for a country and put 'em in a tarball
# we'll keep the output 'flat' by calling files e.g. ch-20201010-010001-ch-cfg.json

x=${HOME:='/home/stephen'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$HOME/data/teks/tek_transparency/data"}

COUNTRY="ie"
OUTFILE="$COUNTRY-configs.tgz"

function usage()
{
    echo "$0 [-cdho] - make a tarball of configs from runs"
    echo "  -c [country] specifies which country to process (defailt: $COUNTRY)"
    echo "  -d specifies the input data directory (default: $DATADIR)"
    echo "  -h means print this"
    echo "  -o specifies the output directory (default: $OUTFILE)"
    exit 99
}

# options may be followed by one colon to indicate they have a required argument
if ! options=$(/usr/bin/getopt -s bash -o c:d:ho: -l country:,datadir:,help,output: -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi
#echo "|$options|"
eval set -- "$options"
while [ $# -gt 0 ]
do
    case "$1" in
        -c|--country) COUNTRY=$2; shift;;
        -d|--dir) DATADIR=$2; shift;;
        -h|--help) usage;;
        -o|--output) OUTFILE=$2; shift;;
        (--) shift; break;;
        (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
        (*)  break;;
    esac
    shift
done

# country might have changed
OUTFILE="$COUNTRY-configs.tgz"

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

echo "At $NOW: Running $0 $*"

outfile=$PWD/$OUTFILE
if [[ "${OUTFILE:0:1}" == "/" ]]
then
    outfile=$OUTFILE
fi

flist=`find $DATADIR -name $COUNTRY'-cfg.*'`

aflist=($flist)
if [[ "${#aflist[@]}" == "0" ]]
then
    echo "Empty list of configs - exiting"
    exit 2
fi

tdir=`mktemp -d /tmp/tarcXXXX`
if [ ! -d $tdir ]
then
    echo "Failed to make temp dir - exiting"
    exit 1
fi

for file in $flist 
do
    bn=`basename $file`
    dn=`dirname $file`
    run=`basename $dn`
    echo "$run:$bn"
    cp $file $tdir/$COUNTRY-$run-$bn
done

cd $tdir
tar czvf $outfile $COUNTRY-*
cd -
rm -rf $tdir

