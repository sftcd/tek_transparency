#!/usr/bin/python3

# Make a bar chart of my estimated uploads vs. ground truth

# Input is 2 CSVs with: date,count

import os,sys,argparse,csv,dateutil,math,statistics
import matplotlib
matplotlib.use('Agg')
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import numpy as np
import gif,datetime

from forecasting_metrics import *

def smape(predicted, actual):
    # calculate mean absolute percentage error
    # https://en.wikipedia.org/wiki/Mean_absolute_scaled_error
    if len(predicted) != len(actual):
        raise ValueError('mase: lengths differ (',len(predicted),len(actual),')')
    # mean average error
    #smape=sum([abs(predicted[i]-actual[i])/((abs(actual[i])+predicted[i])/2) for i in range(len(predicted))])/len(predicted)
    smape=sum([abs(predicted[i]-actual[i])/((abs(actual[i])+predicted[i])) for i in range(len(predicted))])/len(predicted)
    return smape

def mape(predicted, actual):
    # calculate mean absolute percentage error
    # https://en.wikipedia.org/wiki/Mean_absolute_scaled_error
    if len(predicted) != len(actual):
        raise ValueError('mase: lengths differ (',len(predicted),len(actual),')')
    # mean average error
    mape=sum([abs(predicted[i]-actual[i])/abs(actual[i]) for i in range(len(predicted))])/len(predicted)
    return mape

def mase(predicted, actual):
    # calculate mean absolute scaled error
    # https://en.wikipedia.org/wiki/Mean_absolute_scaled_error
    if len(predicted) != len(actual):
        raise ValueError('mase: lengths differ (',len(predicted),len(actual),')')
    if len(actual)==1:
        raise ValueError('mase: length of 1 invalid')
    # mean average error
    aes=[abs(predicted[i]-actual[i]) for i in range(len(predicted))]
    mae=sum(aes)/len(predicted)
    # divisor
    naive=sum([abs(actual[i+1]-actual[i]) for i in range(len(actual)-1)])
    if naive==0:
        raise ValueError('mase: sum of actual diffs is zero')
    divisor=naive/(len(actual)-1)
    return mae/divisor

# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Plot daily TEK counts for a set of countries')
    parser.add_argument('-1','--input1',     
                    dest='in1',
                    help='File name (wildcards supported) containing country daily TEK count CSVs')
    parser.add_argument('-2','--input2',     
                    dest='in2',
                    help='File name (wildcards supported) containing country daily TEK count CSVs')
    parser.add_argument('-o','--one',     
                    dest='label1',
                    help='label for first data')
    parser.add_argument('-t','--two',     
                    dest='label2',
                    help='label for second data')
    parser.add_argument('-c','--country',     
                    dest='country',
                    help='label for country')
    parser.add_argument('-s','--start',     
                    dest='start',
                    help='start date')
    parser.add_argument('-e','--end',     
                    dest='end',
                    help='end date')
    parser.add_argument('-i','--image',     
                    dest='outfile',
                    help='file for resulting plot')
    parser.add_argument('-v','--verbose',     
                    help='additional output',
                    action='store_true')
    parser.add_argument('-n','--nolegend',     
                    help='don\'t add legend to figure',
                    action='store_true')
    parser.add_argument('-7','--seven',     
                    help='add 7 day running averages',
                    action='store_true')
    parser.add_argument('-f','--fourteen',     
                    help='add 14 day running averages',
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
    
    if args.in1 is None or args.in2 is None:
        print("Mising input file(s) - exiting")
        sys.exit(1)

    dates1=[]
    counts1=[]
    if args.in1 is not None:
        with open(args.in1) as csvfile: 
            readCSV = csv.reader(csvfile, delimiter=',')
            for row in readCSV:
                rdate=dateutil.parser.parse(row[0])
                if rdate < mintime or rdate >= maxtime:
                    continue
                if rdate not in dates1:
                    dates1.append(rdate)
                    counts1.append(int(row[1]))

    dates2=[]
    counts2=[]
    if args.in2 is not None:
        with open(args.in2) as csvfile: 
            readCSV = csv.reader(csvfile, delimiter=',')
            for row in readCSV:
                rdate=dateutil.parser.parse(row[0])
                if rdate < mintime or rdate >= maxtime:
                    continue
                if rdate not in dates2:
                    dates2.append(rdate)
                    counts2.append(int(row[1]))

    # the 7 and 14 day averages
    c7_1=[]
    c14_1=[]
    c7_2=[]
    c14_2=[]
    for ind in range(7,len(counts1)):
        c7_1.append(sum(counts1[ind-7:ind])/7)
    for ind in range(14,len(counts1)):
        c14_1.append(sum(counts1[ind-14:ind])/14)
    for ind in range(7,len(counts2)):
        c7_2.append(sum(counts2[ind-7:ind])/7)
    for ind in range(14,len(counts2)):
        c14_2.append(sum(counts2[ind-14:ind])/14)

    fig, ax = plt.subplots(1)
    ax.xaxis_date()
    ax.format_xdata = mdates.DateFormatter('%Y-%m-%d')
    ax.tick_params(axis='x', which='major', labelsize=24, labelrotation=20)
    #ax.tick_params(axis='y', which='major', labelsize=24)
    dmintime=min(dates1[0],dates2[0])
    dmaxtime=min(dates1[-1],dates2[-1])
    if args.start:
        dmintime=mintime
    if args.end:
        dmaxtime=maxtime
    ax2=ax.twinx()
    ax2.tick_params(axis='y', which='major', labelsize=24)


    # match up the dates - we'll graph only the common dates
    ind2=0
    ind1=0
    if dates1[0] <= dates2[0]:
        if dates1[-1] < dates2[0]:
            print("Dates out of whack 1")
            sys.exit(1)
        while dates1[ind1] < dates2[0]:
            ind1+=1
    else:
        if dates2[-1] < dates1[0]:
            print("Dates out of whack 2")
            sys.exit(1)
        while dates2[ind2] < dates1[0]:
            ind2+=1
    while counts1[ind1]==0 or counts2[ind2]==0:
        ind1+=1
        ind2+=1
    # even things up
    l=min(len(counts1[ind1:]),len(counts2[ind2:]))
    l-=1
    print(len(counts1),ind1,l,len(counts2),ind2,l)
    print(len(counts1[ind1:ind1+l]),len(counts2[ind2:ind2+l]))

    # 7-day totals
    lsuma=0
    lsump=0
    d7=[]
    a7=[]
    p7=[]
    for ind in range(l):
        lsuma+=counts2[ind2+ind]
        lsump+=counts1[ind1+ind]
        if ind % 7 == 0:
            d7.append(dates1[ind1+ind])
            a7.append(lsuma)
            p7.append(lsump)
            lsuma=0
            lsump=0
        ind+=1
    print(d7[0],a7,p7)
    print("MASE7: ",mase(p7,a7))
    print("MAPE7: ",mape(p7,a7))
    print("SMAPE7: ",smape(p7,a7))

    dmintime=dates1[ind1]
    dmaxtime=min(dates1[-1],dates2[-1])
    ax.set_xlim(dmintime,dmaxtime)

    bar_width=0.4
    #bwm=datetime.timedelta(days=2*bar_width)
    bwm=datetime.timedelta(days=0.2)
    plt.bar([d-bwm for d in dates1[ind1:]],counts1[ind1:],bar_width,color="red")
    plt.bar([d+bwm for d in dates2[ind2:]],counts2[ind2:],bar_width,color="blue")

    predicted=counts1[ind1:ind1+l]
    actual=counts2[ind2:ind2+l]
    print("")
    print("Predicted:",predicted)
    print("Actual:",actual)
    print("MASE: ",mase(predicted,actual))
    print("MAPE: ",mape(predicted,actual))
    print("SMAPE: ",smape(predicted,actual))
    print("Days: ",l,"Dates: ",dates1[ind1],dates2[ind2])

    if args.seven:
        ax2.plot([d+bwm for d in dates1[7+ind1:]],c7_1[ind1:],marker='o',color="red")
        ax2.plot([d+bwm for d in dates2[7+ind2:]],c7_2[ind2:],marker='o',color="blue")
    if args.fourteen:
        ax2.plot([d+bwm for d in dates1[14+ind1:]],c14_1[ind1:],marker='o',color="red")
        ax2.plot([d+bwm for d in dates2[14+ind2:]],c14_2[ind2:],marker='o',color="blue")

    if args.country:
        plt.suptitle("Estimated uploads versus ground truth for "+args.country)
    else:
        plt.suptitle("Estimated uploads versus ground truth")
    if args.seven and args.fourteen:
        ax.set(title="with 7- and 14- day running averages on lines")
    elif args.seven:
        ax.set(title="with 7- day running averages on lines")
    elif args.fourteen:
        ax.set(title="with 14- day running averages on lines")

    if not args.nolegend:
        patches=[]
        patches.append(mpatches.Patch(label=args.label1,color="red"))
        patches.append(mpatches.Patch(label=args.label2,color="blue"))
        if args.seven or args.fourteen:
            patches.append(mpatches.Patch(lw=None,ls='dashed',label="7/14-day running average"))
        fig.legend(loc='lower center', fancybox=True, ncol=10, handles=patches)

    if args.outfile is not None:
        fig.set_size_inches(18.5, 11.5)
        plt.savefig(args.outfile,dpi=300)
    else:
        plt.show()

    # plot the 7 day stuff
    fig7, ax7 = plt.subplots(1)
    ax7.xaxis_date()
    ax7.format_xdata = mdates.DateFormatter('%Y-%m-%d')
    #ax7.tick_params(axis='x', which='major', labelsize=24, labelrotation=20)
    ax7.tick_params(axis='x', which='major', labelrotation=20)
    dmintime=min(dates1[0],dates2[0])
    dmaxtime=min(dates1[-1],dates2[-1])
    if args.start:
        dmintime=mintime
    if args.end:
        dmaxtime=maxtime
    bar_width=0.8
    #bwm=datetime.timedelta(days=2*bar_width)
    bwm=datetime.timedelta(days=1)
    plt.bar([d-bwm for d in d7],p7,bar_width,color="red")
    plt.bar([d+bwm for d in d7],a7,bar_width,color="blue")

    outfile7=os.path.splitext(args.outfile)[0]+"-seven.png"

    if args.outfile is not None:
        fig.set_size_inches(18.5, 11.5)
        plt.savefig(outfile7,dpi=300)
    else:
        plt.show()
