#!/usr/bin/python3

# Make a plot of the time vs. SF evolution for a set
# of countries

import sys,argparse,csv,dateutil,math,statistics
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib
import gif,datetime
from operator import itemgetter
import glob
import pandas as pd

import numpy as np

# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Plot RSSIs for a set of experiments')
    parser.add_argument('-c','--countries',     
                    dest='countries',
                    help='comma-separated list of country names to process')
    parser.add_argument('-i','--input',     
                    dest='infile',
                    help='File name (wildcards supported) containing TEK CSVs')
    parser.add_argument('-B','--BIG',     
                    help='make plot labels BIGger',
                    action='store_true')
    parser.add_argument('-o','--output_file',     
                    dest='outfile',
                    help='file for resulting plot')
    parser.add_argument('-s','--start',     
                    dest='start',
                    help='earliest date to use')
    parser.add_argument('-e','--end',     
                    dest='end',
                    help='latest date to use')
    parser.add_argument('-v','--verbose',     
                    help='additional output',
                    action='store_true')
    parser.add_argument('-H','--hourly',     
                    help='make legend for hourly plot',
                    action='store_true')
    args=parser.parse_args()

    if args.infile is None:
        usage()

    if args.verbose:
        if args.outfile is not None:
            print("Output will be in " + args.outfile)

    sel_countries=[]
    if args.countries is not None:
        sel_countries=args.countries.split(",")
        if args.verbose:
            print(sel_countries)

    # figure limits of x-axis 
    # we depend on sorted input actually but no harm setting a limit
    maxtime=dateutil.parser.parse("2020-01-01")
    mintime=dateutil.parser.parse("2022-01-01")

    if args.start is not None:
        mintime=dateutil.parser.parse(args.start)
    if args.end is not None:
        maxtime=dateutil.parser.parse(args.end)

    fig, ax = plt.subplots(1)

    data = pd.read_csv(args.infile,header=0,parse_dates=True,names=["country","start","end","shortfall"])
    if args.verbose:
        print(data)
    if args.countries is not None:
        data=data.loc[data['country'].isin(sel_countries)]
        if args.verbose:
            print(data)
    df = data.pivot(index='start', columns='country', values='shortfall')
    df.fillna(method='ffill', inplace=True)

    if args.verbose:
        print(df)
    df.plot()

    if args.BIG:
        plt.tick_params(axis='x', which='major', labelsize=16, labelrotation=20)
        plt.tick_params(axis='y', which='major', labelsize=16)
        plt.tick_params(axis='both', which='minor', labelsize=16)
    else:
        plt.tick_params(axis='x', labelrotation=20)
    plt.xlabel("Date")
    plt.ylabel("Shortfall")
    if args.hourly:
        plt.xlabel("Hour of the day")
        plt.ylabel("Number of transitions")
    #plt.tight_layout()

    #plt.legend(loc='upper righ', fancybox=True, ncol=3)
    plt.legend(bbox_to_anchor=(0, 1, 1, 0), loc="lower left", mode="expand", ncol=10)

    #ax.set_xticks(ax.get_xticks()[::2])
    #ax.set_xlim(mintime,maxtime)

    #ax.xaxis_date()
    #ax.format_xdata = mdates.DateFormatter('%Y-%m-%d')
    #ax.tick_params(axis='x', labelrotation=20)
    #plt.yticks([])
    #ax.set_xlabel("Date")
    #ax.set_ylabel("Shortfall")
    #ax.tick_params(axis='x', which='major', labelsize=24, labelrotation=20)
    #ax.tick_params(axis='y', which='major', labelsize=16)
    #ax.xaxis.label.set_size(24)
    #dmintime=dates[0]
    #dmaxtime=dates[-1]
    if args.outfile is not None:
        #fig.set_size_inches(18.5, 11.5)
        fig.set_size_inches(9.25, 5.75)
        plt.savefig(args.outfile,dpi=300)
    else:
        plt.show()

