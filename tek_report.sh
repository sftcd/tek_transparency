#!/bin/bash

# turn the CSVs into a HTML page to be nicer to readers

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${DOCROOT:='/var/www/tact/tek-counts/'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$TOP"}
x=${ARCHIVE:="$DATADIR/all-zips"}

TARGET_DIR="$DOCROOT"
TARGET="$TARGET_DIR/index.html"

. $TOP/country_list.sh

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
these regions running GAEN apps:
</p>  
<ol> 
EOF

for country in $COUNTRY_LIST
do
    echo "<li>${COUNTRY_NAMES[$country]}</li>" >>$TARGET
done

cat >>$TARGET <<EOF

</ol>

<p>As of 20201003, we see no keys from Hungary or Puerto Rico.</p>

<p>We hope to expand the list of countries over
time (help welcome!) as more public health authorities adopt the Google/Apple
Exposure Notification (GAEN) API (if they do!). The code that produces this is
<a href="https://github.com/sftcd/tek_transparency/">here</a>.  This is
produced as part of our <a href="https://down.dsg.cs.tcd.ie/tact/">TACT</a>
project.</p>

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
    <li>20200910: Added Spanish live data (thanks to 
        <a href="https://github.com/sftcd/tek_transparency/pull/12">github PR#12</a> from @Crazy-Projects).
        Data up to 20200727 was from a pilot.
    </li>
    <li>20200910: Added US/Alabama</li>
    <li>20200910: Added Estonia</li>
    <li>20200913: Added Finland</li>
    <li>20200916: Added Scotland and US/Delaware</li>
    <li>20200916: Added Nevada</li>
    <li>20200916: Added Wyoming (and N. Dakota!). The same app (care19.app) is used for
    both states with the same endpoint for downloading the same set of TEKs. I've just
    put that in as Wyoming for now, both for population and case counts, which is wrong
    but will do for a bit.</li>
	<li>20200919: had a bug due to grep for de also matching usde, fixed now, and only
    affected presentation (not stored data); also need to investigate if it's correct that usde and uswy are
	the same - could be correct or maybe I mucked up a URL configuration</li>
    <li>20200929: fixed that issue with JHU records now and then having US-style dates (e.g. 9/28/20)
    rather than "normal" dates (e.g. 2020-09-28). (This fixes the issue noted on Aug 21st.)</li>
    <li>20201002: Just to note that the same TEK publication endpoint is used
    for (at least) these US states: Delaware, North Carolina, Wyoming, North Dakota, Pennsylvania</li>
    <li>20201002: Added a pile more regions: Belgium, Brazil, England-and-Wales, Malta, Portugal, Ecuador</li>
    <li>20201002: Added Gibraltar even though we've never seen a TEK from there too.</li>
    <li>20201002: Added Czechia, South Africa, Hungary, Netherlands</li>
    <li>20201003: Turns out the California, New York and New Jersey apps also use the same source for TEKs</li>
    <li>20201003: Added Guam and Puerto Rico (the latter has no TEKs yet)</li>
    <li>20201009: Added Slovenia.</li>
    <li>20201011: I changed the process so that we still download hourly, but only update this page
        every two hours - we're seeing more than 0.5M TEKs per download (note: those are far from all
        new ones) and the "counting" code is pretty
        inefficient. Recently, this page is being updated about 50 mins past the hour which could cause
        issues if that goes over 60 and the next download and count happens. I'll re-implement sometime
        but this should be ok for now - while some counts, e.g. of South Africa (.za being the 
        last on the list) might reflect an hour later than those for Austria (.at, first on
        the list), that's ok, and we won't end up with loads of counting processes running on
        this quite ancient server:-).</li>

</ul>

</p>

<p>This file is updated every two hours while we figure out the behaviour. This update is from $NOW UTC. If
you manage one of these systems and would prefer we query less often please feel free to get in
touch.</p> 

<p>For an explanation of what this means, read <a href="https://down.dsg.cs.tcd.ie/tact/transp.pdf">this</a>.</p>

EOF

# Check for canaries, these get dropped if bad happens
for canary in $ARCHIVE/*-canary
do
    cat $ARCHIVE/$canary >>$TARGET
done

# table of tables with 1 row only 
echo '<table ><tr>' >>$TARGET
for country in $COUNTRY_LIST
do
	cfile="$ARCHIVE/$country-tek-times.csv"
	echo '<td valign="top">' >>$TARGET
	echo '<p>'${COUNTRY_NAMES[$country]} '<a href="'$country'-tek-times.csv">csv file</a></p>' >>$TARGET
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
