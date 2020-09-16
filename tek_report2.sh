#!/bin/bash

# set -x

# turn the CSVs into a HTML page to be nicer to readers
# modified quite a bit now our survey does more

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${DOCROOT:='/var/www/tact/tek-counts/'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$TOP"}
x=${ARCHIVE:="$DATADIR/all-zips"}
x=${DAILYDIR:="$TOP/dailies2"}

TARGET_DIR="$DOCROOT"
TARGET="$TARGET_DIR/index2.html"
COUNTRY_LIST="ie ukni uksc ch at dk de it pl ee fi lv es usva usal usde ca"

function whenisitagain()
{
	date -u +%Y%m%d-%H%M%S
}
NOW=$(whenisitagain)

if [ ! -d $TARGET_DIR ]
then
    TARGET="tek-index2.html"
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
the Irish, Northern Irish, Scots, Italian, German, Swiss, Polish, Danish, Austrian,
Estonian, Latvian, Spanish, Canadian (Ontario?) and United States (Virigina, Alabama, Delaware) apps. </p>  

<p>We hope to expand the list of countries over
time (help welcome!) as more public health authorities adopt the Google/Apple
Exposure Notification (GAEN) API (if they do!). The code that produces this is
<a href="https://github.com/sftcd/tek_transparency/">here</a>.  This is
produced as part of our <a href="https://down.dsg.cs.tcd.ie/tact/">TACT</a>
project.</p>

<p>This file is updated every hour while we figure out the behaviour. This update is from $NOW UTC. If
you manage one of these systems and would prefer we query less often please feel free to get in
touch.</p> 
EOF

# Check for canaries, these get dropped if bad happens
IE_CANARY="ie-canary"
UKNI_CANARY="ukni-canary"
USVA_CANARY="usva-canary"
USAL_CANARY="usal-canary"
for canary in $IE_CANARY $UKNI_CANARY $USVA_CANARY $USAL_CANARY
do
    if [ -f $ARCHIVE/$canary ]
    then
        cat $ARCHIVE/$canary >>$TARGET
    fi 
done

cat >>$TARGET <<EOF

<p>There are 3 bits to this page:
<ul>
<li><a href="#shortfalls">Shortfalls</a> - just below:-)</li>
<li><a href="#counts">Daily Counts</a> - the daily count tables that used be all the content here</li>
<li><a href="#changes">Changes</a> - notes about changes</p></li>
</ul>
</p>

<h2><a name="shortfalls">Shortfalls</a></h2>

<p>Our survey seems to show a shortfall between what we see and the number of uploads one would
expect, based on population, active-user and case counts. Ideally that figure ought be zero, 
but we see deployments where we see half (shortfall=50%) or less of the expected numbers.
<a href="survey.pdf">This report</a> describes how we measure the
shortfalls between uploads and expected uploads, based on population,
active users and case counts. The latest table is below.</p>

<table>
    <tr><td>
	Estimated Uploads since we started:

EOF

# add latest table
cat $DAILYDIR/shortfalls.html >>$TARGET
# add latest table
cat >>$TARGET <<EOF
        </td> <td>
	Estimated Uploads for the last two weeks:
EOF

cat $DAILYDIR/shortfalls2w.html >>$TARGET

cat >>$TARGET <<EOF
        </td><td>

<p>These images show our estimates of key uploads versus cases for each of the
countries in question. <br/>
Click through for a bigger image.<br/>
The <a href="country-counts.csv">CSV file</a> on which those are based.</p>

<table>
    <tr>
        <td><a href="ie.png"><img src="ie-small.png" alt=".ie"/></a></td>
        <td><a href="ukni.png"><img src="ukni-small.png" alt=".ukni"/></a></td>
        <td><a href="uksc.png"><img src="uksc-small.png" alt=".uksc"/></a></td>
    </tr>
    <tr>
        <td><a href="ch.png"><img src="ch-small.png" alt=".ch"/></a></td>
        <td><a href="at.png"><img src="at-small.png" alt=".at"/></a></td>
        <td><a href="de.png"><img src="de-small.png" alt=".de"/></a></td>
        <td><a href="dk.png"><img src="dk-small.png" alt=".dk"/></a></td>
    </tr>
    <tr>
        <td><a href="fi.png"><img src="fi-small.png" alt=".fi"/></a></td>
        <td><a href="ee.png"><img src="ee-small.png" alt=".ee"/></a></td>
        <td><a href="lv.png"><img src="lv-small.png" alt=".lv"/></a></td>
    </tr>
    <tr>
        <td><a href="it.png"><img src="it-small.png" alt=".it"/></a></td>
        <td><a href="pl.png"><img src="pl-small.png" alt=".pl"/></a></td>
        <td><a href="es.png"><img src="es-small.png" alt=".es"/></a></td>
    </tr>
    <tr>
        <td><a href="usva.png"><img src="usva-small.png" alt=".usva"/></a></td>
        <td><a href="usal.png"><img src="usal-small.png" alt=".usal"/></a></td>
        <td><a href="usde.png"><img src="usde-small.png" alt=".usde"/></a></td>
        <td><a href="ca.png"><img src="ca-small.png" alt=".ca"/></a></td>
    </tr>
    <tr>
</table>

        </td></tr>
        </table>
EOF

cat >>$TARGET <<EOF
<p>We can estimate the accuracy of a couple of the above estimates because
Germany and Switzerland publish data on the number of keys uploaded. The
bar charts below show our estimates and the source data.</p>

<table>
<tr>
    <td><a href="ch-ground.png"><img src="ch-ground-small.png" alt=".ch-ground"/></a></td>
    <td><a href="de-ground.png"><img src="de-ground-small.png" alt=".de-ground"/></a></td>
</tr>
</table>

EOF

cat >>$TARGET <<EOF
<h2><a name="counts">Daily Counts</a></h2>

<p>The tables below show the counts of TEK valid on each of the days listed. Where
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

<p>The count of cases declared is the number of COVID-19 cases for that
day according to the <a href="https://github.com/CSSEGISandData/COVID-19">Johns Hopkins</a>
data set. 
</p>

<p>Comparing the TEKs and Cases columns, it is clear that some more explanation
for those numbers is required. We are trying to find good answers for that.
(And welcome inputs!)

</p>

<p>For an explanation of what this means, read <a href="https://down.dsg.cs.tcd.ie/tact/transp.pdf">this</a>.</p>

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
<h2><a name="changes">Changes</a></h2>

<p>
<ul>
	<li>On 20200702 we learned (from Paul-Olivier Dehaye <paulolivier@personaldata.io>) that the Swiss 
key server always emits 10 "synthetic" TEKs per
day as a method of exercising the client code (a fine idea), so the number
of "real" uploads is what is shown less 10. We also learned that the
Swiss server-side can update the numbers post-facto, so each time our
script is run we download the last two weeks worth of information. It
may take a while to get a full picture of what's going on there.</li>
	<li>For some reason the German server publishes 10 keys for every
one really uploaded. (See this <a href="https://github.com/corona-warn-app/cwa-server/pull/609">github issue</a>.)
I don't really buy that as a privacy win TBH - just rounding up to a 
multiple of 10 would be fine, but at least I think I now understand
the numbers.</li>
    <li>On 20200704 we found out about the .de hourly API endpoint so we've
added grabbing those zips where they're available. Not clear if that's
using the same random-key-padding-multiplier or not, or maybe they
changed it down to 5 or something.</li> 
	<li>On 20200709 added Austria. I'm currently unclear what those
numbers mean but did check 'em and they do seem to relate to unique
TEK values. We'll see how it goes for a day or two before worrying.</li>
    <li>On 20200709 added Latvia as there are now a few TEKs.</li>
    <li>Added Ireland on 20200710</li>
    <li>20200711: Took a look at the <a href="https://github.com/austrianredcross/RCA-CoronaApp-Backend.git">Austrian server code</a>
and it does have a configured minimum and jitter and randomly pads - search for ensureMinNumExposures(). No idea why they've picked such big numbers though.</li>
	<li>20200713: started collecting numbers for Spain, where they're
running a trial apparently, but not clear that
the server for their trial will be used when it goes live so we'll not 
yet show the trial numbers.</li>
    <li>20200714: fixed a script bug that affected Swiss (and Spanish
in future) TEK retrieval logic (thanks again to Paul-Olivier Dehaye!). 
That did affect older Swiss counts displayed on this page but (assuming fix is
correct) the numbers below should now be correct.</li>
    <li>20200716: Just to note that the Irish case numbers (at least) are
offset by a day from what's reported in local media. That's ok though
because any use of those numbers will likely be based on 7 or 14 day
running averages.</li>
   <li>20200718 via Paul-Olivier Dehaye, on the Swiss system: On 20200716
around 2pm, UTC 144 debugging TEKs were introduced in the Swiss database. On
20200717 around noon UTC, 11 of those were removed. Half an hour later the
practice of adding 10 dummy TEKs each day was dropped, with the bundles still
available on the server being purged retroactively. The counts below reflect
the maximum number of keys that were released on any given day. For some (at
least 07.13 and after), the counts below reflects the post-purge count, since
new keys added after the purge caught up with the pre-purge record. For others
(at least 07.05 and before), the counts below reflects the pre-purge count,
since no new keys will be added in the future in order to make up for those
purged. We will clarify what happens between 07.06 and 07.12 later.</li>
    <li>20200719: the German ratio of fake/real TEKs changed from 9:1 to 4:1 on
July 2nd according to the nice dashboard <a
href="https://micb25.github.io/dka/">here</a>.</li> 
    <li>20200806: Added Northern Ireland. Initially, NI and IE were not sharing TEKs.</li>
    <li>20200807: Added check whether US Virginia TEK download still has content-length: 0.
Once we see some, we'll start counting those TEKs.</li>
	<li>20200807: Ireland and Northern Ireland are now sharing (at least some) TEKs.</li>
    <li>20200808: Switched from using ECDC case counts to JHU, so we can get regions such as NI.</li>
    <li>20200814: Now showing some TEKs from Virginia in the US, so added those.</li>
    <li>20200820: Added Canada (or maybe it's just Ontario? We'll see)</li>
	<li>20200821: Some JHU data for 20200819 had a date format issue so my script missed that. The
counts for 20200820 in those cases show 2 days worth of cases. If that keeps happening I can fix
it, but if it's a one-off, no need.</li>
    <li>20200826: It seems that the Austrian fake TEKs might (TBC) be randomly generated
and so only published once in one zip file, whereas the real TEKs continue to be published
for multiple days. I've collated the set of one-off TEKs and so now scan for those and
(for now) no longer accumulate them in Austrian counts.</li> 
    <li>20200830: started refactorying tek_report.sh to make this new page</li>
    <li>20200910: Added Spanish live data (thanks to 
        <a href="https://github.com/sftcd/tek_transparency/pull/12">github PR#12</a> from @Crazy-Projects).
        Data up to 20200727 was from a pilot.
    </li>
    <li>20200910: Added US/Alabama</li>
    <li>20200910: Added Estonia</li>
    <li>20200913: Added Finland</li>
    <li>20200916: Added Scotland and US/Delaware</li>

</ul>
</p>
</html>

EOF
