#!/usr/bin/python3

# ie and ukni services sometimes serve stale zips - make a plot
# of those as they can affect my ie/ukni estimates

# Input is a CSV with: date,country, and a set of id,time_t+ms

import os,sys,argparse,csv,dateutil,math,statistics
import matplotlib
#matplotlib.use('Agg')
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import numpy as np
import gif,datetime

from forecasting_metrics import *

# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Plot daily TEK counts for a set of countries')
    parser.add_argument('-i','--input',     
                    dest='infile',
                    help='File name (wildcards supported) containing country daily TEK count CSVs')
    parser.add_argument('-o','--output',     
                    dest='outfile',
                    help='output for graph')
    parser.add_argument('-y','--yoffset',     
                    action='store_true',
                    help='Y-offset for ireland')
    parser.add_argument('-c','--country',     
                    dest='country',
                    help='country to graph')
    parser.add_argument('-s','--start',     
                    dest='start',
                    help='start date')
    parser.add_argument('-e','--end',     
                    dest='end',
                    help='end date')
    parser.add_argument('-v','--verbose',     
                    help='additional output',
                    action='store_true')
    parser.add_argument('-n','--nolegend',     
                    help='don\'t add legend to figure',
                    action='store_true')
    args=parser.parse_args()

    if args.verbose:
        if args.outfile is not None:
            print("Output will be in " + args.outfile)

    mintime=dateutil.parser.parse("2020-01-01")
    maxtime=dateutil.parser.parse("2022-01-01")

    if args.start is not None:
        mintime=dateutil.parser.parse(args.start)
    if args.end is not None:
        maxtime=dateutil.parser.parse(args.end)

    if args.infile is None:
        print("Mising input file - exiting")
        sys.exit(1)

    ie_dates=[]
    ukni_dates=[]
    ie_tstamps=[]
    ukni_tstamps=[]
    rowind=1
    with open(args.infile) as csvfile: 
        readCSV = csv.reader(csvfile, delimiter=',')
        for row in readCSV:
            print(rowind,row)
            rdate=dateutil.parser.parse(row[0])
            if rdate < mintime or rdate >= maxtime:
                print("Out of time range:",rdate,rowind)
                rowind+=1
                continue
            if len(row)<4:
                print("Too few cols:",rowind)
                rowind+=1
                continue
            if row[3]=='missing':
                print("Skipping missing:",rowind)
                rowind+=1
                continue
            c=row[1]
            ind=2
            while ind <= len(row)-2:
                ms=int(row[ind+1])
                zt=datetime.datetime.fromtimestamp(ms//1000).replace(microsecond=ms%1000*1000)
                if c == 'ie' and (args.country is None or c == args.country):
                    ie_dates.append(rdate)
                    ie_tstamps.append(zt)
                    print("Adding",rdate,c,zt)
                elif c=='ukni' and (args.country is None or c == args.country):
                    ukni_dates.append(rdate)
                    ukni_tstamps.append(zt)
                    print("Adding",rdate,c,zt)
                else:
                    print("Odd country: ",c)
                ind+=2
            rowind+=1

    fig, ax = plt.subplots(1)
    ax.xaxis_date()
    ax.yaxis_date()
    ax.format_xdata = mdates.DateFormatter('%Y-%m-%d')
    if args.country is None:
        dmintime=min(ie_dates[0],ukni_dates[0])
        dmaxtime=max(ie_dates[-1],ukni_dates[-1])
    elif args.country == 'ie':
        dmintime=ie_dates[0]
        dmaxtime=ie_dates[-1]
    elif args.country == 'ukni':
        dmintime=ukni_dates[0]
        dmaxtime=ukni_dates[-1]
    else:
        print("Unsupported country")
        sys.exit(1)
    if args.start:
        dmintime=mintime
    if args.end:
        dmaxtime=maxtime
    ax.set_xlim(dmintime,dmaxtime)

    yoffset=datetime.timedelta(days=0)
    if args.yoffset:
        yoffset=datetime.timedelta(days=3)
    plt.scatter(ie_dates,[y + yoffset for y in ie_tstamps],color='green')
    plt.scatter(ukni_dates,ukni_tstamps,marker='D',color='blue')

    if not args.nolegend:
        plt.suptitle("Irish and Northern Irish, download time vs. zip filename timestamp")
        if args.yoffset: 
            plt.title("Irish y-values offset by 3 days (upwards)")
        patches=[]
        patches.append(mpatches.Patch(label="Ireland",color="green"))
        patches.append(mpatches.Patch(label="Northern Ireland",color="blue"))
        fig.legend(loc='lower center', fancybox=True, ncol=10, handles=patches)

    if args.outfile is not None:
        fig.set_size_inches(18.5, 11.5)
        plt.savefig(args.outfile,dpi=300)
    else:
        plt.show()

