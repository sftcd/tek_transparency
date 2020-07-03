#!/bin/bash

# turn the CSVs into a HTML page to be nicer to readers

TARGET_DIR="/var/www/tact/tek-counts"
TARGET="$TARGET_DIR/index.html"
COUNTRY_LIST="it de ch pl"
DATADIR=/home/stephen/code/tek_transparency
ARCHIVE=$DATADIR/all-zips

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

if [ ! -d $TARGET_DIR ]
then
    TARGET="tek-index.html"
    echo "Can't see $TARGET_DIR, writing to $TARGET"
fi

# do the file header
cat >$TARGET <<EOF
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>Testing Apps for COVID-19 Tracing (TACT) - TEK Survey </title>
</head>
<!-- Background white, links blue (unvisited), navy (visited), red
(active) -->
<body bgcolor="#FFFFFF" text="#000000" link="#0000FF"
vlink="#000080" alink="#FF0000">
<h1>Testing Apps for COVID-19 Tracing (TACT) - TEK Survey </h1>

<p>This page displays the current counts of Temporary Exposure Keys (TEKs)
that are visible on the Internet, to allow for comparisons for each day, for
the Italian, German, Swiss and Polish apps.  We hope to expand that list over
time (help welcome!) as more public health authorities adopt the Google/Apple
Exposure Notification (GAEN) API (if they do!). The code that produces this is
<a href="https://github.com/sftcd/tek_transparency/">here</a>.  This is
produced as part of our <a href="https://down.dsg.cs.tcd.ie/tact/">TACT</a>
project.</p>

<p>The tables below show the counts of TEK for each of the days listed. Where
there were no TEKs for a given day, there is no row in the file. The TEK column
reports the number of TEKs that were published, being considered useful for
contact tracing on that day, so do not represent the number of positive cases
seen on that day (except perhaps for the most recent day).  In other words, on
the latest day reported, the number of TEKs should (in theory) match the number
of people using the app that test positive and subsequently upload their TEKs.
Each such person will upload usually 14 TEKs (one for each day in the previous
two weeks), though the public health authority might decide not to publish the
full set for medical reasons (e.g. not being infectious for some days). That
means that for example the number of TEKs on the 2nd most recent day may
be the sum of the number of people who uploaded on that and the most recent
day. </p>

<p>The count of cases declared is the number of COVID-19 cases declared by that
country to the WHO, either based on a manually downloaded file from the WHO
(rarely) or else on a file from the ECDC that can be downloaded from <a
href="https://opendata.ecdc.europa.eu/covid19/casedistribution/csv">here</a>.
</p>

<p>Comparing the TEKs and Cases columns, it is clear that some more explanation
for those numbers is required. We are trying to find good answers for that.
(And welcome inputs!)

<ul>
	<li>On 20200702 we learned (via personal communication) that the Swiss 
key server always emits 10 "synthetic" TEKs per
day as a method of exercising the client code (a fine idea), so the number
of "real" uploads is what is shown less 10. We also learned that the
Swiss server-side can update the numbers post-facto, so each time our
script is run we download the last two weeks worth of information. It
may take a while to get a full picture of what's going on there.</li>
	<li>We're not at all clear what the German numbers mean. Given there
are days where the number of TEKs are more than double the number of
cases declared to the WHO, our current (20200703) guess is that represents some
form of ongoing testing, but we await confirmation of that.</li>

</ul>

</p>




<p>This file is updated every 6 hours. This update is from $NOW UTC. For
an explanation of what this means, read <a href="https://down.dsg.cs.tcd.ie/tact/transp.pdf">this</a>.</p>

EOF

# table of tables with 1 row only 
echo '<table ><tr>' >>$TARGET
for country in $COUNTRY_LIST
do
	cfile="$ARCHIVE/$country-tek-times.csv"
	echo '<td valign="top">' >>$TARGET
	echo '<p><a href="'$country'-tek-times.csv">csv file</a></p>' >>$TARGET
	echo '<table border="1">' >>$TARGET
	awk -F, '{print "<TR>"; for(i=1;i<=NF;i++) {print "<TD>"$i"</TD>"} print "</TR>"}' $cfile >>$TARGET
	echo '</table>' >>$TARGET
	echo '</td>' >>$TARGET
done
echo "</tr></table>" >>$TARGET

# do the footer
cat >>$TARGET <<EOF
</html>

EOF
