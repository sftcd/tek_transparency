#!/usr/bin/python3

# Generate a (latex) table of shortfalls in visible TEKs

import sys,argparse,csv,math,statistics
import datetime
from dateutil import parser as dp

# return the index of the nearest date
# in the list
def nearest_date(tocheck,thelist):
    if tocheck<=thelist[0]:
        return(0)
    if tocheck>=thelist[-1]:
        return(len(thelist)-1)
    ind=0
    for d in thelist:
        if d>=tocheck:
            ind=thelist.index(d)
            break
    above=thelist[ind]-tocheck
    below=tocheck-thelist[ind-1]
    if (above<below):
        return(ind)
    else:
        return(ind-1)


# for the given country, check if we have more
# fine-grained active-user counts, and if so,
# then calculate shortfall as the sum of the
# weekly shortfalls; if the active user counts
# aren't daily/weekly then we'll interpolate
# if we don't have active user counts, we'll
# return None
def weekly_shortfall(country,thedir,dates,teks,cases,pop):
    # we check in CWD for a file called <country>-actives.csv
    # that should have lines like "2020-07-01,50122" meaning 
    # there were 50122 active users on July 1 2020
    if thedir is None:
        return(None,0)
    aufname=country+"-actives.csv"
    if thedir is not None:
        aufname=thedir+"/"+aufname
    try:
        # we're just called once so load file and don't worry about
        # caching
        adates=[]
        acounts=[]
        with open(aufname) as csvfile: 
            readCSV = csv.reader(csvfile, delimiter=',')
            for row in readCSV:
                rdate=dp.parse(row[0])
                rcount=float(row[1])
                adates.append(rdate)
                acounts.append(rcount)
        expected=0
        short=0
        nweeks=int(len(dates)/7)
        for week in range(0,nweeks):
            aind=nearest_date(dates[week*7],adates)
            acount=acounts[aind]
            csum=sum(cases[week*7:(week+1)*7])
            tsum=sum(teks[week*7:(week+1)*7])
            aper=acount/(pop*1000000)
            wexpected=csum*aper
            wshort=wexpected-tsum
            #print(dates[week*7],tsum,csum,wexpected,wshort,aind,acount,aper)
            expected+=wexpected
            short+=wshort
    except Exception as e:
        print("weekly error:",str(e))
        return(None,0)

    if expected==0:
        return(None,0)
    wsf=100*short/expected
    #print("shortfall",wsf,"expected",expected)
    return wsf,expected

# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Figure out TEKs shortfalls')
    parser.add_argument('-c','--countries',     
                    dest='countries',
                    help='comma-separated list of country names to process')
    parser.add_argument('-t','--teks',     
                    dest='teks',
                    help='File name (wildcards supported) containing country daily TEK count CSVs')
    parser.add_argument('-d','--downloads',     
                    dest='downloads',
                    help='CSV with country populations and download figures')
    parser.add_argument('-D','--actives_dir',     
                    dest='actives_dir',
                    help='directory name where per-country active user count files can be found')
    parser.add_argument('-s','--start',     
                    dest='start',
                    help='start date')
    parser.add_argument('-e','--end',     
                    dest='end',
                    help='end date')
    parser.add_argument('-n','--nolatex',     
                    help='output table without latex',
                    action='store_true')
    parser.add_argument('-r','--rampup',     
                    help='don\'t count cases until after 1st TEK in date-range',
                    action='store_true')
    parser.add_argument('-H','--HTML',     
                    help='output table as HTML fragment',
                    action='store_true')
    args=parser.parse_args()

    if args.teks is None:
        print("You need to provide TEK info - exiting")
        sys.exit(1)
    if args.downloads is None:
        print("You need to provide population/active-users info - exiting")
        sys.exit(1)

    sel_countries=[]
    if args.countries is not None:
        sel_countries=args.countries.split(",")

    mintime=dp.parse("2020-01-01")
    maxtime=dp.parse("2022-01-01")
    if args.start is not None:
        mintime=dp.parse(args.start)
    if args.end is not None:
        maxtime=dp.parse(args.end)

    dates=[]
    countries=[]
    country_teks={}
    country_cases={}

    with open(args.teks) as csvfile: 
        readCSV = csv.reader(csvfile, delimiter=',')
        for row in readCSV:
            country=row[0]
            if args.countries is not None and country not in sel_countries:
                continue
            rdate=dp.parse(row[1])
            if rdate < mintime or rdate >= maxtime:
                continue
            if rdate not in dates:
                dates.append(rdate)
            if country not in countries:
                countries.append(country)
                country_teks[country]=[]
                country_cases[country]=[]
            country_teks[country].append(int(row[2]))
            if row[3]=='':
                country_cases[country].append(0)
            else:
                country_cases[country].append(int(row[3]))
    
    country_pops={}
    country_actives={}
    country_urls={}
    with open(args.downloads) as csvfile:
        readCSV = csv.reader(csvfile, delimiter=',')
        for row in readCSV:
            country=row[0]
            if args.countries is not None and country not in sel_countries:
                continue
            if country not in countries:
                # only do countries where we have TEK/case counts
                continue
            if country not in country_pops:
                country_pops[country]=[]
            if country not in country_actives:
                country_actives[country]=[]
            if row[1]!='':
                country_pops[country]=float(row[1])
            else:
                country_pops[country]=0
            if row[2]!='':
                country_actives[country]=float(row[2])
            else:
                country_actives[country]=0
            if row[3]!="":
                country_urls[country]=row[3]

    #print(countries,country_teks,country_cases)
    #print(countries,country_pops,country_actives,country_urls)

    table_lines=[]

    # make up the table details
    for country in countries:
        dosf=True
        tline=[]
        tline.append(country)
        if country_pops[country]==0:
            tline.append("-")
            dosf=False
        else:
            tline.append(country_pops[country])
        if country_actives[country]==0:
            tline.append("-")
            dosf=False
        else:
            tline.append(country_actives[country])
        zerodays=0
        casetot=0
        tektot=sum(country_teks[country])
        if args.rampup:
            zerodays = next((index for index,value in enumerate(country_teks[country]) if value != 0), None)
            #print(tektot,zerodays,country_teks[country])
            #print("First non-zero TEK date:",dates[zerodays],"after",zerodays,"zero days")
        tline.append(str(tektot))
        if not args.rampup:
            casetot=sum(country_cases[country])
        else:
            if zerodays is not None:
                casetot=sum(country_cases[country][zerodays:])
                #print(casetot,zerodays,country_cases[country])
                if casetot==0:
                    dosf=False
            else:
                #print("zerodays is None - probably no TEKs in range at all (tektot=",tektot,")")
                casetot=sum(country_cases[country])
                dosf=False

        tline.append(str(casetot))
        wsf=0.0
        expected=0
        if dosf:
            cper=country_actives[country]/country_pops[country]
            shortfall=100-100*(tektot/(cper*casetot))
            wsf,expected=weekly_shortfall(country,args.actives_dir,
                            dates,country_teks[country],country_cases[country],country_pops[country])
            if wsf is not None:
                shortfall=wsf
            tline.append(str('%.1f' % shortfall))
        else:
            tline.append("-")
        if args.rampup and zerodays is not None:
            tline.append(dates[zerodays].strftime("%Y-%m-%d"))
        else:
            tline.append("-")
        # expected
        if country_pops[country]!=0:
            if expected==0:
                expected=casetot*country_actives[country]/country_pops[country]
            tline.append(str(int(expected)))
        else:
            tline.append("-")
        table_lines.append(tline)

    if args.HTML:
        if args.countries is None:
            # give header/footer only if not doing 'em piecemeal
            print("<table border=\"1\">")
            print("<tr><td>Country</td><td>Pop</td><td>Actives</td><td>Estimated Uploads</td><td>Cases</td><td>Shortfall</td><td>First</td></tr>")
        for tline in table_lines:
            print("<tr>",end="")
            for tle in tline:
                print("<td>",tle,"</td>",end="")
            print("</tr>")
        if args.countries is None:
            print("</table>")
        sys.exit(0)

    if args.nolatex:
        print("{")
        for tline in table_lines:
            print("    "+str(tline)+",")
        print("}")
        sys.exit(0)

    # footnote stanzas
    fsts=[]
    for tline in table_lines:
        print("\t\\hline",tline[0], # country
                " & ",tline[1], # pop
                " & ",tline[2], # actives
                " & ",tline[6], # start 
                " & ",dates[-1].strftime("%Y-%m-%d"), # end
                " & ",tline[4], # cases
                " & ",tline[3], # uploads
                " & ",tline[7], # expected
                " & ",tline[5]+"\\%", # shortfall
                "\\\\")

    for country in countries:
        if country in country_urls:
            print(country,"\\footnote{\\url{"+country_urls[country]+"}}")

