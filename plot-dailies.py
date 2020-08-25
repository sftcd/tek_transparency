#!/usr/bin/python3

# Make a bar chart of the date vs. country-counts

# Input is a CSV with: country,date,count,epoch

import sys,argparse,csv,dateutil,math,statistics
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib
import numpy as np
import gif,pandas,datetime
from operator import itemgetter
import glob
import datetime
import pandas as pd

# colours for different cteks
colours=["red","green","blue","orange","yellow","black","cyan","purple","skyblue","chocolate","slategray"]


# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Plot RSSIs for a set of experiments')
    parser.add_argument('-i','--input',     
                    dest='infile',
                    help='File name (wildcards supported) containing country daily TEK count CSVs')
    parser.add_argument('-o','--output_file',     
                    dest='outfile',
                    help='file for resulting plot')
    parser.add_argument('-v','--verbose',     
                    help='additional output',
                    action='store_true')
    parser.add_argument('-n','--nolegend',     
                    help='don\'t add legend to figure',
                    action='store_true')
    args=parser.parse_args()

    if args.infile is None:
        usage()

    if args.verbose:
        if args.outfile is not None:
            print("Output will be in " + args.outfile)

    #fig, ax = plt.subplots()
    #ax.xaxis_date()

    if args.outfile is not None:
        fig.set_size_inches(18.5, 10.5)

    rowind=0
    dates=[]
    countries=[]
    country_counts={}
    if args.infile is not None:
        with open(args.infile) as csvfile: 
            readCSV = csv.reader(csvfile, delimiter=',')
            for row in readCSV:
                rdate=dateutil.parser.parse(row[0])
                if rdate not in dates:
                    dates.append(rdate)
                country=row[1]
                if country not in countries:
                    countries.append(country)
                    country_counts[country]=[]
                country_counts[country].append(int(row[2]))

    plotdata=pd.DataFrame(country_counts,dates)
    plotdata.plot(kind='bar')
    plotdata.head()

    plt.show()


