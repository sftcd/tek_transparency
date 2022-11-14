#!/usr/bin/python3

# Make plots of the start and end-times for services
# for each country

import sys,argparse,csv,dateutil,math,statistics
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib
import datetime
from operator import itemgetter
import glob
import datetime

import numpy as np

# input vars with sensible defaults
xlabel=None
ylabel=None
verbose=False
dostarts=True

def tstr2datetime(tstr):
    return datetime.datetime.strptime(tstr,"%Y-%m-%d")

# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Plot start/end for a set of services')
    parser.add_argument('-i','--input',     
                    dest='infile',
                    help='File name (wildcards supported) containing CSV with begin/end data')
    parser.add_argument('-o','--output_file',     
                    dest='outfile',
                    help='file for resulting plot')
    parser.add_argument('-e','--ends',     
                    help='plot end dates',
                    action='store_true')
    parser.add_argument('-v','--verbose',     
                    help='additional output',
                    action='store_true')
    args=parser.parse_args()

    if args.infile is None:
        usage()

    if args.verbose:
        if args.outfile is not None:
            print("Output will be in " + args.outfile)

    if args.ends:
        dostarts=False

    # figure limits of x-axis 
    # we depend on sorted input actually but no harm setting a limit
    maxtime=dateutil.parser.parse("2020-01-01")
    mintime=dateutil.parser.parse("2023-01-01")

    fig,axs=plt.subplots(1)
    axs.xaxis_date()
    if args.outfile is not None:
        fig.set_size_inches(18.5, 10.5)

    rowind=0
    ctekind=0
    lastchange=dateutil.parser.parse("2020-01-01")
    firstseens=[]
    lastseens=[]
    countries=[]
    clabels=[]
    if args.infile is not None:
        # read in ctek lines
            with open(args.infile) as csvfile: 
                readCSV = csv.reader(csvfile, delimiter=',')
                try:
                    for row in readCSV:
                        if rowind == 0:
                            rowind+=1
                            continue
                        #print(row)
                        country=row[0]
                        cstring=row[1]
                        firstseen=tstr2datetime(row[2])
                        lastseen=tstr2datetime(row[3])
                        # now print/plot that
                        if args.verbose:
                            print(country,cstring,firstseen,lastseen)
                        #firstseens.append((firstseen-(firstseen-epoch)/2))
                        #ctekinds.append(ctekind)
                        #epocherr.append((firstseen-epoch)/2)
                        firstseens.append(firstseen)
                        lastseens.append(lastseen)
                        countries.append(country)
                        clabels.append(cstring)
                        rowind+=1
                except Exception as e:
                    print("Error (0.5) at",str(rowind), str(e))

    if dostarts == True:
        plt.scatter(firstseens,countries)
        for i, txt in enumerate(clabels):
            axs.annotate(txt, (firstseens[i], countries[i]))
    else:
        plt.scatter(lastseens,countries)
        for i, txt in enumerate(clabels):
            axs.annotate(txt, (lastseens[i], countries[i]))

    if args.outfile is not None:
        plt.savefig(args.outfile,dpi=300)
    else:
        plt.show()


