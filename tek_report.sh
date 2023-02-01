#!/bin/bash

# turn the CSVs into a HTML page to be nicer to readers

# For a cronjob set HOME as needed in the crontab
# and then the rest should be ok, but you can override
# any of these you want
x=${HOME:='/home/stephen'}
x=${DOCROOT:='/var/www/tact/tek-counts/'}
x=${TOP:="$HOME/code/tek_transparency"}
x=${DATADIR:="$TOP/data"}
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

FRESHHOURS=36
WORKINGSIZE=1024

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
that are visible on the Internet, to allow for comparisons for each day. 
For an explanation of what this means, read <a href="https://down.dsg.cs.tcd.ie/tact/survey10.pdf">this</a>. (Please also use that report if referencing this data.)</p>

<p>Now that these services are being turned off, we note the last time we
saw new key files published for each service. 
Those are coloured <strong><span style="color:red";">Red</span></strong>
if we haven't seen any new key files for more than $FRESHHOURS hours, 
<strong><span style="bold;color:#ffbf00;">Amber</span></strong> if we have
but the total size of zip files seen in the last 24 hours is less than $WORKINGSIZE bytes (indicating a lack of activity),
or 
<strong><span style="bold;color:green;">Green</span></strong> if things
look more operational:
</p>  
<ol> 
<strong>
EOF

# time_t for now
stillworking=0
amberstate=0
turnedoff=0
nowtimet=`date +%s`
redstr=' style="color:Red;"'
amberstr=' style="color:#ffbf00;"'
greenstr=' style="color:Green;"'
for country in $COUNTRY_LIST
do
    colstr=$redstr
    lastzip=`ls -rt $ARCHIVE/$country-*.zip | tail -1`
    if [[ "$lastzip" != "" ]]
    then
        lasttime=`stat -c %Z $lastzip`
        lastsize=`find $ARCHIVE -name "$country-*.zip" -mtime -1 -ls | \
            awk 'BEGIN{sum=0} {sum += $7} END {print sum}'`
        #lastsize=`stat -c %s $lastzip`
        lastkeys=`date +"%Y-%m-%d" -d @$lasttime`
        if (( (nowtimet-lasttime)<(FRESHHOURS*60*60) ))
        then
            if (( lastsize < WORKINGSIZE ))
            then
                colstr=$amberstr
                amberstate=$(( amberstate+1 ))
            else
                colstr=$greenstr
                stillworking=$(( stillworking+1 ))
            fi
        else
            turnedoff=$(( turnedoff+1 ))
        fi
    else
        lastkeys="never"
        turnedoff=$(( turnedoff+1 ))
    fi
    echo "<li $colstr>${COUNTRY_NAMES[$country]}, last keys seen at: $lastkeys</li>" >>$TARGET
done

cat >>$TARGET <<EOF

</strong>
</ol>

<p>That's a total of $stillworking still seemingly working, $amberstate
in the "Amber" state, and
$turnedoff apparently turned off. Portugal for example was counted
here as amber as they basically posted one key
per day from March 2021 until 2022-06-10, after which they turned
"red." From 2022-04-06 to 2022-04-11 Croatian key files
contained no keys, so were also amber (though then turned back green, before
finally going red again). The
2021-12-15 date above is also an artefact and really means
"earlier than that" (that was the date we migrated the machine
running this).</p>

<p>This file is updated twice a day, we query services once per hour. This
update is from $NOW UTC. If you manage one of these systems and would prefer we
query less often please feel free to get in touch.</p> 

<h2>Background</h2>

<p>Starting in mid-2020 we expanded the list of countries over
time as more public health authorities adopted the Google/Apple
Exposure Notification (GAEN) API. The code that produces this is
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

<h2>Change log</h2>

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
    <li>20201020: Ireland, Germany and Italy are now sharing TEKS. I've not analysed that yet.</li>
    <li>20201023: Dutch endpoint URL changed (thanks to @damaarten for 
        <a href="https://github.com/sftcd/tek_transparency/issues/16">letting us know</a>.</li>
	<li>20201028: Overnight power outage. No runs between 20:00Z on the 27th 'till 10:00Z on 
		the 28th. Should be back now.</li>
    <li>20201029: Just noticed we now have a few keys from Hungary, didn't yet go back and see when 
        they first appeared.</li>
    <li>20201106: Got a <a href="https://github.com/sftcd/tek_transparency/issues/19">report</a> of oddities for CZ on Oct 14th 2020.
        Had to change from the epoch value from the zip file to the epoch for the midnight before due to some 
        values that are not 00:00Z for that day. May have seen that before (not sure) but it
        happened for sure for CZ on Oct 14 2020 where we had 7 odd epoch values.
        I don't know if that's down to the CZ server or to the odd values being 
        uploaded by handsets there.</li>
    <li>20201119: Found a good 
            <a href="https://www.aphl.org/programs/preparedness/Crisis-Management/COVID-19-Response/Pages/exposure-notifications.aspx">link</a>
            for the set of US states using the same server, should be useful when/if doing 
            more analysis on those keys.</li>
    <li>20201207: Counting the TEKs is now taking hours, so I'll just do that twice a day for a bit. (Since
            reduced further to 1/day on 20210110;-)</li>
    <li>20210111: Tweaked UKSC index URL, as the 'limit' URL param setting needed a change due to a change
        on the service side. Don't think I missed any TEKs there but some will appear to have arrived
        'late' from the POV of my archives - that doesn't mean there was any issue with the actual
        app for that region. </li>
    <li>20210112: Added Croatia (though they're not showing any TEKs as of now)</li>
	<li>20210113: Added URL param (so a 2nd URL we query for zips) so we also grab Croatian server's idea of EU shared keys, not sure if those 
		zips also include or exclude local (.hr) keys or only contain keys from EU members. Still no sign of definitely local (.hr) TEKs. The
		same issue seems to apply to Hungary (since 20201220, we haven't seen any .hu TEKs but adding the "?all=true" URL param results in
		getting a bunch of new zips (similarly named to .hr ones) that presumably (also?) contain EU TEKs.</li>
	<li>20210222: Some college-wide transient n/w outages reported today. I
also saw some sockets hanging in TIME_WAIT state on the measurement machine so
counts could be affected, not sure. Apparently a fix was put in place before or
around noon UTC.</li>
    <li>20210525: The Irish Health Services Executive (HSE) suffered a major
ransomware attack on May 14th and so stopped a lot of data reporting to 
(reasonably) concentrate on getting core services back up and running. That's 
still ongoing.</li>
    <li>20211216: I updated the h/w for this server and have just finished 
migrating to the new h/w. Seems like things work still (mostly) and given
this box has 16X the RAM of the last one, it may be fun to play about some
more with TEKs. That said, some of the URLs from which we're reading may
have changed since we started so I'll need to check that out.</li>
    <li>20220104: had to change a script constant to cover 2022 as well as 2020 and
2021. Never did think it'd last that long when we started;-( </li>
    <li>20220403: a lot of the services (incl. Ireland) seem to be turning off now (finally;-) Changed the header here
to reflect that.</li>
    <li>20220404: Since things are starting to turn off, I captured an <a href="us-states.png">image of the US states</a>
currently participating in their US national server (according to 
<a href="https://www.aphl.org/programs/preparedness/Crisis-Management/COVID-19-Response/Pages/exposure-notifications.aspx">this web page</a>). That's just in case of future link rot.</li>
    <li>20220407: reversed the presentation order of the daily values (below), and adopted colour-coding as
at the top, to make it easier to see latest data</li>
    <li>20220409: changed red/green rule to 36 hours as we were getting some edge-conditions</li>
    <li>20220411: added "amber" state for services still serving fresh zip files that are smaller than 600 
bytes and so have only zero or a couple of keys</li>
    <li>20220411: it turns out we added Hungary (.hu) in error back in Oct 2020 using Croatian (.hr) URLs. As far
as we know that hasn't affected anything published. We did add Croatia properly in Dec 2020. We still have the 
Oct 2020 to Dec 2020 data that's really Croatian in our archives but for now, we'll simply drop Hungary from
our lists. It looks like Hungary perhaps never deployed a GAEN app but it's a hard to be sure at this remove.
Apologies for our error.</li>
    <li>20220503: given the services are being turned off, the domain names involved might get re-used
for other things, I therefore made a bunch of changes so the main survey script is more robust and we shouldn't
try create a "bad" filename such as one starting with "../../" or similar.</li>
    <li>20220506: we're now getting non-zip files as the Estonian app (HOIA) has been <a href="https://hoia.me/en/discontinued/">shut down</a>
so I tweaked the download to not assume the response was a zip file (doing so is no harm as we won't get confused as to what's a TEK or not, but
it will confuse the red/amber/green setting stuff.</li>
    <li>20220602: Estonian URLs now re-directing (302) to https://tehik.ee/ which is returning HTML, so added a check that the content
we're getting is a zip file. We'll see if that works.</li>
    <li>20220603: Finland app now shut down says <a href="https://koronavilkku.fi/en/">https://koronavilkku.fi/en/</a>. 
Quoting some text from what's on that page now: "At most, Koronavilkku had 2.5 million users. Koronavilkku was one of the most widely used COVID-19 apps in relation to the population of the country. 64,000 users reported their infection with the app. 23 % of Koronavilkku users reported having received an alert of potential exposure."</li>
    <li>20220603: The Croatian API server's certificate expired on May 31st so that one's not working, though there do
appear to be new zip files there if one ignores the certificate (which I won't be doing:-). Presumably they'll fix
that and it'll re-appear as an amber or green service. It's interesting though that that hasn't been fixed in 3 days - it'd
seem to imply that either nobody's noticing that the service is down (i.e. no users?) or else that the client app isn't
checking server certificates properly. Neither would seem good news for the GAEN approach. The relevant CT log data can be seen
at <a href="https://crt.sh/?q=en.apis-it.hr">https://crt.sh/?q=en.apis-it.hr</a>.</li>
    <li>20220604: Another certificate expiry! The server certificate the Gibraltar API server expired on June 4th 2022 (being instantiated on June 4th 2020 and valid for 
two years). We'll see if that gets fixed or not I guess. For the record expired cert can be seen in CT logs here: 
<a href="https://crt.sh/?q=app.beatcovid19.gov.gi">https://crt.sh/?q=app.beatcovid19.gov.gi</a>.</li>
    <li>20220626: couple of delayed notes below - delay due to vacationing:-)</li>
    <li>20220626: Canadian app is "now retired" says <a href="https://www.canada.ca/en/public-health/services/diseases/coronavirus-disease-covid-19/covid-alert.html">https://www.canada.ca/en/public-health/services/diseases/coronavirus-disease-covid-19/covid-alert.html</a>. The date on that web page is 2022-06-02 but the last "real" zip I saw was on 2022-06-17.</li>
    <li>20220626: Portugal now also has a certificate validation error since
2022-06-10 - it's not an expired cert in this case but something in the offered
certificate path is s no longer liked by curl. If one ignores the certificate
error (I don't), there are still "amber" zip files being offered containing,
I guess from the size, one key, as has been done since March 2021, but for now,
Portugal is showing "red" and no longer "amber."</li>
    <li>20220715: Looks like Malta is no longer operational as we're now getting
errors accessing their server. Didn't find an official announcement, but it's
discontued according to <a href="https://ec.europa.eu/info/live-work-travel-eu/coronavirus-response/travel-during-coronavirus-pandemic/mobile-contact-tracing-apps-eu-member-states_en">
https://ec.europa.eu/info/live-work-travel-eu/coronavirus-response/travel-during-coronavirus-pandemic/mobile-contact-tracing-apps-eu-member-states_en</a>.</li> 
    <li>20220719: the last of our US servers seemed to stop serving new
zip files over the last few days and hence turned red. There were also some
local n/w issues (at my measurement vantage point) over that time so it's possible
the fault is on my side. Manual checking
(around noon UTC on Jul 19) did seem to show only old zip files at those servers at
that time. I've not seen any
announcement that services are being disabled though. Whatever was
happening seems to have rectified itself around 1900 UTC on Jul 19, so it seems
like it was a roughly 2 day "gap." (Having started on Jul 17 around 2000 UTC.)</li>
    <li>20220730: Croatia re-appeared on July 27th after it's cert expired almost two months before. 
We didn't see any key files from May 31 until July 27 because of those cert failures. 
On July 27 we downloaded what look like backdated key files that (from their names) appear to cover 
days from June 1 to July 27.</li>
    <li>20220805: The measurement machine was down for a day or so. We shouldn't have missed any TEKs
as those should be visible for ~14 days, but there are gaps in the hourly scans. I setup a secondary 
measurement cronjob on another machine on the 4th that collected TEKs until the main box was back 
so the hourly scans that were missed in the end was from 20220803-120001 to 20220804-163459. 
There were a few oddities remaining (some services change file content but not name over time)
that are noted in an all-zips/odd-zips directory.</li>
    <li>20220810: The Australian app isn't one we tracked as it didn't use the Google/Apple scheme,
so just to note it's being turned off too (<a href="https://www.theguardian.com/australia-news/2022/aug/10/australia-retires-covidsafe-contact-tracing-app-that-was-barely-used">https://www.theguardian.com/australia-news/2022/aug/10/australia-retires-covidsafe-contact-tracing-app-that-was-barely-used</a>).</li>
    <li>20220815: changed definition of "amber" to: total size of files seen in last 24 hours < 1024 bytes as
we were getting occasional false positives.</li>
    <li>20220919: noticed that I now get an NXDOMAIN for cdn.projectaurora.cloud which was used by .gu, so added 
a bit of script to skip .gu when there is no A record for that. No idea when that started, nor if it will continue. A 
check using whois seems to indicate that projectaurora.cloud is in the pendingDelete state. </li>
    <li>20220922: Latvia servers seem to be sorta-down, not sure if temporarily or not. The TLS session is 
    being setup, but the web server seems broken perhaps.</li>
    <li>20220923: Northern Ireland server returning no new keys for a couple of days. Not sure
    if broken or turned off. The iccky HTTP bearer-token authentication stuff still seems to
    be working.</li>
    <li>20220926: I checked the Northern Ireland config file (which is still being served) and found that 
    it has a new setting saying: "The HSC StopCOVID NI app will no longer be available as of 20th September 2022"
    So I guess that one has been turned off.</li>
    <li>20220928: Latvian service back since afternoon of 27th. That was a one week gap in key files, 
from the 20th to 27th. Seems an interesting aspect of these systems, that they can go down for days and
apparently nobody notices!</li>
    <li>20221011: Spanish app seems to have been shut down as of Oct 9th: <a href="https://radarcovid.gob.es/home">https://radarcovid.gob.es/home</a>.</li>
    <li>20221119: It looks like the Belgian app may be going away. Not sure when this was posted but <a href="https://coronalert.be/en/">https://coronalert.be/en/</a>
    now says: "Important information Considering the improved sanitary situation, the Coronalert app is no longer being updated, and will be removed from
    the play store and app store.  Please delete the application.  The Coronalert team" From the numbers it may have been turned off on Nov 16th or 17th 
    though a Nov 9th <a href="https://www.brusselstimes.com/health/319414/delete-it-belgiums-covid-tracing-coronalert-app-no-longer-active">news article</a>
    reports the decision to retire this deployment.</li>
    <li>20221205: It looks like the DNS name for the Belgian server (c19distcdn-prd.ixor.be) went away on Dec 3rd.</li>
    <li>20221228: According to their site <a href="https://www.immuni.italia.it/">https://www.immuni.italia.it/</a>, the Italian Immuni app will be turned off 
    on Dec 31st. (It hasn't really been that active for quite a while.)</li>
    <li>20230105: Latvian servers still operating but no new key files since Jan 3rd and number of posted keys declined
    sharply starting Dec 29th, so could be the Latvian service is being turned off, though I've not found any reporting
    saying apturicovid is going away, so it could be a transient service outage.</li>
    <li>20230106: new Latvian key file seen, I guess they just had a new year break.</li>
    <li>20230201: noticed I was no longer seeing case numbers from JHU data - turns out there was another bit of script
    that assumed it would all be over in 2022, so changed that. We'll see if the change is correct.</li>

</ul>

</p>


<h2>Daily values</h2>

EOF


# Check for canaries, these get dropped if bad happens
for canary in $ARCHIVE/*-canary
do
    cat $canary >>$TARGET
done

TMPF=`mktemp`

# table of tables with 1 row only 
echo '<table ><tr>' >>$TARGET
for country in $COUNTRY_LIST
do

    # colour red/green as above 
    nowtimet=`date +%s`
    redstr=' style="background-color:Red;"'
    greenstr=' style="background-color:Green;"'
    amberstr=' style="background-color:#ffbf00;"'
    colstr=$redstr
    lastzip=`ls -rt $ARCHIVE/$country-*.zip | tail -1`
    if [[ "$lastzip" != "" ]]
    then
        lasttime=`stat -c %Z $lastzip`
        #lastsize=`stat -c %s $lastzip`
        lastsize=`find $ARCHIVE -name "$country-*.zip" -mtime -1 -ls | \
            awk 'BEGIN{sum=0} {sum += $7} END {print sum}'`
        lastkeys=`date +"%Y-%m-%d" -d @$lasttime`
        if (( (nowtimet-lasttime)<(FRESHHOURS*60*60) ))
        then
            if (( lastsize < WORKINGSIZE ))
            then
                colstr=$amberstr
            else
                colstr=$greenstr
            fi
        fi
    fi
	cfile="$ARCHIVE/$country-tek-times.csv"
    # reverse the lines in the CSV
    head -1 $cfile >$TMPF
    tail -n +2 $cfile | tac >>$TMPF
	echo '<td valign="top">' >>$TARGET
	echo '<p>'${COUNTRY_NAMES[$country]} '<a href="'$country'-tek-times.csv">csv file</a></p>' >>$TARGET
	echo '<table '$colstr'border="1">' >>$TARGET
	awk -F, '{print "<TR>"; for(i=1;i<=NF;i++) {print "<TD>"$i"</TD>"} print "</TR>"}' $TMPF >>$TARGET
	echo '</table>' >>$TARGET
	echo '</td>' >>$TARGET
    rm -f $TMPF
done
echo "</tr></table>" >>$TARGET

# do the footer
cat >>$TARGET <<EOF
</html>

EOF
