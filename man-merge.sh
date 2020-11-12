#!/bin/bash

# "manually" merge the files from a run with those in the all-zips
# directory 

# had a case where the machine running tek_survey.sh was offline for
# a bit and I manually did a run on a dev laptop to fill in that gap

# this script then ensures the zips in all-zips are added to or
# updated as would've happened had tek_survey.sh gotten these zips
# as usual

x=${TOP:="$HOME/code/tek_transparency"}

ARCHIVE="$TOP/all-zips"

for zipf in *.zip
do
	bn=`basename $zipf`
	if [ ! -s $zipf ]
	then
		echo "empty $bn"
	elif [ ! -f $ARCHIVE/$bn ]
	then
		echo "will copy new $bn"
		cp $zipf $ARCHIVE
	elif ((`stat -c%s "$zipf"`>`stat -c%s "$ARCHIVE/$bn"`))
	then
		echo "will copy bigger $bn"
		cp $zipf $ARCHIVE
	else
		echo "nothing to do for $bn"
	fi
done
