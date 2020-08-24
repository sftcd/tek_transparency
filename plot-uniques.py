#!/usr/bin/python3

# Make a plot of the time vs. epoch/first-seen line
# for each unique country/TEK pair (here termed a ctek)

import sys,argparse,csv,dateutil,math,statistics
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib
import gif,pandas,datetime
from operator import itemgetter
import glob
import datetime

import numpy as np

# colours for different cteks
colours=["red","green","blue","orange","yellow","black","cyan","purple","skyblue","chocolate","slategray"]

# input vars with sensible defaults
xlabel=None
ylabel=None
verbose=False


def time_t2datetime(time_t):
    return datetime.datetime.fromtimestamp(float(time_t))

# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Plot RSSIs for a set of experiments')
    parser.add_argument('-i','--input',     
                    dest='infile',
                    help='File name (wildcards supported) containing TEK CSVs')
    parser.add_argument('-o','--output_file',     
                    dest='outfile',
                    help='file for resulting plot')
    parser.add_argument('-v','--verbose',     
                    help='additional output',
                    action='store_true')
    args=parser.parse_args()

    if args.infile is None:
        usage()

    if args.verbose:
        if args.outfile is not None:
            print("Output will be in " + args.outfile)

    # figure limits of x-axis 
    # we depend on sorted input actually but no harm setting a limit
    maxtime=dateutil.parser.parse("2020-01-01")
    mintime=dateutil.parser.parse("2022-01-01")

    fig,axs=plt.subplots(1)
    #for ax in axs:
        #ax.axis_date()
    if args.outfile is not None:
        fig.set_size_inches(18.5, 10.5)

    rowind=0
    ctekind=0
    lastchange=dateutil.parser.parse("2020-01-01")
    changedur=datetime.timedelta(days=20)
    firstseens=[]
    ctekinds=[]
    epocherr=[]
    if args.infile is not None:
        # read in ctek lines
            with open(args.infile) as csvfile: 
                    readCSV = csv.reader(csvfile, delimiter=',')
                    #try:
                    for row in readCSV:
                        #print(row)
                        firstseen=time_t2datetime(row[2])
                        epoch=time_t2datetime(row[3])
                        # if N (=20) days have elapased we can recycle
                        # the index numbers
                        if (firstseen-lastchange)>changedur:
                            lastchange=firstseen
                            ctekind=0
                        else:
                            ctekind+=1
                        # now print/plot that
                        if args.verbose:
                            print("ctekind:",ctekind,firstseen,epoch)
                        #firstseens.append((firstseen-(firstseen-epoch)/2))
                        #ctekinds.append(ctekind)
                        #epocherr.append((firstseen-epoch)/2)
                        firstseens.append(firstseen)
                        ctekinds.append(ctekind)
                        #plt.scatter(firstseen,ctekind)
                        rowind+=1
                #except Exception as e:
                    #print("Error (0.5) at",str(rowind), str(e))

    #plt.errorbar(firstseens,ctekinds,xerr=epocherr)
    #plt.plot(firstseens,ctekinds)
    plt.scatter(firstseens,ctekinds)
    if args.outfile is not None:
        plt.savefig(args.outfile,dpi=300)
    else:
        plt.show()


