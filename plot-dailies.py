#!/usr/bin/python3

# Make a bar chart of the date vs. country-counts

# Input is a CSV with: country,date,count,epoch

import sys,argparse,csv,dateutil,math,statistics
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib
import numpy as np
import gif,datetime

# colours for different cteks
colours=["red","green","blue","orange","yellow","black","cyan","purple","skyblue","chocolate","slategray"]


# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Plot daily TEK counts for a set of countries')
    parser.add_argument('-i','--input',     
                    dest='infile',
                    help='File name (wildcards supported) containing country daily TEK count CSVs')
    parser.add_argument('-c','--countries',     
                    dest='countries',
                    help='comma-separated list of country names to process')
    parser.add_argument('-s','--start',     
                    dest='start',
                    help='start date')
    parser.add_argument('-e','--end',     
                    dest='end',
                    help='end date')
    parser.add_argument('-o','--output_file',     
                    dest='outfile',
                    help='file for resulting plot')
    parser.add_argument('-v','--verbose',     
                    help='additional output',
                    action='store_true')
    parser.add_argument('-n','--nolegend',     
                    help='don\'t add legend to figure',
                    action='store_true')
    parser.add_argument('-t','--notitle',     
                    help='don\'t add title to figure',
                    action='store_true')
    parser.add_argument('-7','--seven',     
                    help='add 7 day running averages',
                    action='store_true')
    parser.add_argument('-1','--fourteen',     
                    help='add 14 day running averages',
                    action='store_true')
    args=parser.parse_args()

    if args.infile is None:
        print("No input file specified - exiting")
        sys.exit(1)

    if args.verbose:
        if args.outfile is not None:
            print("Output will be in " + args.outfile)

    sel_countries=[]
    if args.countries is not None:
        sel_countries=args.countries.split(",")

    mintime=dateutil.parser.parse("2020-01-01")
    maxtime=dateutil.parser.parse("2022-01-01")

    if args.start is not None:
        mintime=dateutil.parser.parse(args.start)
    if args.end is not None:
        maxtime=dateutil.parser.parse(args.end)

    dates=[]
    countries=[]
    country_teksncases={}
    country_teks={}
    country_cases={}

    if args.infile is not None:
        with open(args.infile) as csvfile: 
            readCSV = csv.reader(csvfile, delimiter=',')
            for row in readCSV:
                country=row[0]
                if args.countries is not None and country not in sel_countries:
                    continue
                rdate=dateutil.parser.parse(row[1])
                if rdate < mintime or rdate >= maxtime:
                    continue
                if rdate not in dates:
                    dates.append(rdate)
                if country not in countries:
                    countries.append(country)
                    country_teks[country]=[]
                    country_cases[country]=[]
                    country_teksncases[country+'-teks']=[]
                    country_teksncases[country+'-cases']=[]
                country_teks[country].append(int(row[2]))
                country_cases[country].append(int(row[3]))
                country_teksncases[country+'-teks'].append(int(row[2]))
                country_teksncases[country+'-cases'].append(int(row[3]))


    # the 7 and 14 day averages
    c7_tek={}
    c14_tek={}
    c7_case={}
    c14_case={}
    for country in countries:
        c7_tek[country]=[]
        c14_tek[country]=[]
        c7_case[country]=[]
        c14_case[country]=[]
        for ind in range(7,len(country_teks[country])):
            c7_tek[country].append(sum(country_teks[country][ind-7:ind])/7)
        for ind in range(14,len(country_teks[country])):
            c14_tek[country].append(sum(country_teks[country][ind-14:ind])/14)
        for ind in range(7,len(country_cases[country])):
            c7_case[country].append(sum(country_cases[country][ind-7:ind])/7)
        for ind in range(14,len(country_cases[country])):
            c14_case[country].append(sum(country_cases[country][ind-14:ind])/14)

    c7_ratio={}
    c14_ratio={}
    for country in countries:
        c7_ratio[country]=[ 100*x/y if y else 0 for x,y in zip(c7_tek[country],c7_case[country]) ]
        c14_ratio[country]=[ 100*x/y if y else 0 for x,y in zip(c14_tek[country],c14_case[country]) ]

    fig, ax = plt.subplots(1)
    ax.xaxis_date()
    ax.format_xdata = mdates.DateFormatter('%Y-%m-%d')
    ax.tick_params(axis='both', which='major', labelsize=16)
    ax.tick_params(axis='both', which='minor', labelsize=12)
    dmintime=dates[0]
    dmaxtime=dates[-1]
    if args.start:
        dmintime=mintime
    if args.end:
        dmaxtime=maxtime
    ax.set_xlim(dmintime,dmaxtime)
    ax2=ax.twinx()

    bar_width=0.8/(2*len(countries))
    for c in countries:
        bwm=datetime.timedelta(days=(2*countries.index(c))*bar_width)
        plt.bar([d+bwm for d in dates],country_teksncases[c+'-teks'],bar_width,color=colours[(2*countries.index(c))%len(colours)])
        bwm=datetime.timedelta(days=(2*countries.index(c)+1)*bar_width)
        plt.bar([d+bwm for d in dates],country_teksncases[c+'-cases'],bar_width,color=colours[(2*countries.index(c)+1)%len(colours)])

    d7=dates[7:]
    for c in countries:
        if args.seven:
            ax2.plot([d+bwm for d in dates[7:]],c7_tek[c],marker='o',color=colours[(2*countries.index(c))%len(colours)])
            ax2.plot([d+bwm for d in dates[7:]],c7_case[c],marker='^',color=colours[(2*countries.index(c)+1)%len(colours)])
            ax2.plot([d+bwm for d in dates[7:]],c7_ratio[c],linestyle='dashed',color=colours[(2*countries.index(c))%len(colours)])
        if args.fourteen:
            ax2.plot([d+bwm for d in dates[14:]],c14_tek[c],marker='o',color=colours[(2*countries.index(c))%len(colours)])
            ax2.plot([d+bwm for d in dates[14:]],c14_case[c],marker='^',color=colours[(2*countries.index(c)+1)%len(colours)])
            ax2.plot([d+bwm for d in dates[14:]],c14_ratio[c],linestyle='dashed',color=colours[(2*countries.index(c))%len(colours)])

    #ax.xaxis.set_major_locator(mdates.DayLocator())
    #ax.xaxis_date()

    if not args.notitle:
        plt.suptitle("TEKs versus Cases for "+str(countries))
        if args.seven and args.fourteen:
            ax.set(title="with 7- and 14- day running averages on lines (dashed=ratio)")
        elif args.seven:
            ax.set(title="with 7- day running averages on lines (dashed=ratio)")
        elif args.fourteen:
            ax.set(title="with 14- day running averages on lines (dashed=ratio)")

    if not args.nolegend:
        patches=[]
        for c in countries:
            patches.append(mpatches.Patch(color=colours[(2*countries.index(c))%len(colours)],label=c+'-teks'))
            patches.append(mpatches.Patch(color=colours[(2*countries.index(c)+1)%len(colours)],label=c+'-cases'))
            if args.seven or args.fourteen:
                patches.append(mpatches.Patch(lw=None,ls='dashed',color=colours[(2*countries.index(c))%len(colours)],label=c+'-tek/case-ratio'))
        fig.legend(loc='lower center', fancybox=True, ncol=10, handles=patches)

    #ax.xaxis.set_major_locator(mdates.DayLocator())
    #ax.xaxis_date()
    #ax.format_xdata = mdates.DateFormatter('%Y-%m-%d')

    if args.outfile is not None:
        fig.set_size_inches(18.5, 10.5)
        plt.savefig(args.outfile,dpi=300)
    else:
        plt.show()


