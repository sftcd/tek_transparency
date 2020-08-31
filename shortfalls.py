#!/usr/bin/python3

# Generate a (latex) table of shortfalls in visible TEKs

import sys,argparse,csv,math,statistics
import datetime
from dateutil import parser as dp

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
            else:
                print("zerodays is None - probably no TEKs in range at all (tektot=",tektot,")")
                casetot=1

        tline.append(str(casetot))
        if dosf:
            cper=country_actives[country]/country_pops[country]
            shortfall=100-100*(tektot/(cper*casetot))
            tline.append(str('%.1f' % shortfall))
        else:
            tline.append("-")
        if args.rampup:
            tline.append(dates[zerodays].strftime("%Y-%m-%d"))
        else:
            tline.append("-")
        table_lines.append(tline)

    if args.HTML:
        if args.countries is None:
            # give header/footer only if not doing 'em piecemeal
            print("<table border=\"1\">")
            print("<tr><td>Country</td><td>Pop</td><td>Actives</td><td>Uploads</td><td>Cases</td><td>Shortfall</td><td>First</td></tr>")
        for tline in table_lines:
            print("<tr>",end="")
            for tle in tline:
                print("<td>",tle,"</td>",end="")
            print("</tr>")
        if args.countries is None:
            print("</table>")
        sys.exit(0)

    if args.nolatex:
        for tline in table_lines:
            print(tline)
        sys.exit(0)

    # footnote stanzas
    fsts=[]
    for tline in table_lines:
        if args.rampup:
            print("\t\\hline",tline[0],
                " & ",tline[1],
                " & ",tline[2],
                " & ",tline[6],
                " & ",tline[3],
                " & ",tline[4],
                " & ",tline[5]+"\\%",
                "\\\\")
        else:
            print("\t\\hline",tline[0],
                " & ",tline[1],
                " & ",tline[2],
                " & ",tline[3],
                " & ",tline[4],
                " & ",tline[5]+"\\%",
                "\\\\")

    for country in countries:
        if country in country_urls:
            print(country,"\\footnote{\\url{"+country_urls[country]+"}}")

