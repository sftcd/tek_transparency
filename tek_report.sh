#!/bin/bash

# turn the CSVs into a HTML page to be nicer to readers

TARGET="/var/www/tact/tek-counts/index.html"
COUNTRY_LIST="it de ch"
DATADIR=/home/stephen/code/tek_transparency
ARCHIVE=$DATADIR/all-zips

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

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

<p>
This page displays the current counts of Temporary Exposure Keys (TEKs)
that are visible on the Internet for the Italian, German and Swiss apps.
We hope to expand this list over time (help welcome!). The code that
produces this is <a href="https://github.com/sftcd/tek_transparency/">here</a>.
This is produced as part of our <a href="https://down.dsg.cs.tcd.ie/tact/">TACT</a>
project.
</p>

<p>The tables below show the counts of TEK for each of the days listed. Where
there were no TEKs for a given day, there is no row in the file. The count of
cases declared is either based on a manually downloaded file from the WHO
(rarely) or else on a file from the ECDC that can be downloaded from 
<a href="https://opendata.ecdc.europa.eu/covid19/casedistribution/csv">here</a>.
</p>

<p>This file is updated every 6 hours. This update is from $NOW UTC.</p>

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
