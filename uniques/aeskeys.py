#!/usr/bin/python3

# Plot AES keys on a Hilbert curve (sorta)

import numpy as np
import time
from hilbertcurve.hilbertcurve import HilbertCurve
import os, sys, argparse
import matplotlib.pyplot as plt
import secrets


# default values
infile="teks.ah.uni" # ascii-hex encoded TEKS, one per line
batch = 10000        # number of lines to read before processing
pfile="teks.points"  # file for hilbert curve points
outfile="teks.png"   # our output Hilbert curve image
degree = 128         # degree of curve
dimension = 2        # 2 dimensional curve
width = 16           # image width, in inches
display = False      # whether to call plt.show()
heatmap = True       # whether to bin plots
bincount = 64        # heatmap bins per side
random = False       # whether to use random data instead
randcount = 33854268 # number of random values to generate (this is how many TEKs we have)

# command line arg handling 
argparser=argparse.ArgumentParser(description='Map AES keys to Hilbert Curve')
argparser.add_argument('-i','--input', dest='infile', help='file containing list of TEKs')
argparser.add_argument('-o','--output_file', dest='outfile', help='file for image')
argparser.add_argument('-p','--points_file', dest='pfile', help='file for points')
argparser.add_argument('-d','--degree', dest='degree', help='degree of curve')
argparser.add_argument('-n','--dimensions', dest='dimension', help='dimension of curve')
argparser.add_argument('-w','--width', dest='width', type=int, help='width of plot')
argparser.add_argument('-D','--display', dest='display', action='store_true', help='interactively display plot')
argparser.add_argument('-H','--heatmap', dest='heatmap', action='store_true', help='plot heatmap')
argparser.add_argument('-R','--random', dest='random', action='store_true', help='use random data for comparison')
argparser.add_argument('-r','--randcount', dest='randcount', type=int, help='use random data for comparison')
args=argparser.parse_args()

if args.infile is not None and infile != args.infile:
    infile=args.infile
    print("reading from file:", infile)
if args.outfile is not None and outfile != args.outfile:
    outfile=args.outfile
    print("writing to file:", outfile)
if args.pfile is not None and pfile != args.pfile:
    pfile=args.pfile
    print("writing points to file:", pfile)
if args.width is not None and width != args.width:
    width=args.width
    print("image width:", width)
if args.display is not None and display != args.display:
    display=args.display
    print("plot display:", display)
if args.heatmap is not None and heatmap != args.heatmap:
    heatmap=args.heatmap
    print("plot heatmap:", heatmap)
if args.random is not None and random != args.random:
    random=args.random
    print("generate random data instead:", random)
if args.randcount is not None and randcount != args.randcount:
    randcount=args.randcount
    print("random count to generate:", randcount)

# get our output ready...
fig=plt.figure(figsize=(width,width))

hilbert_curve = HilbertCurve(degree, dimension)

if random:
    print("Using random data")
    TEKs=[]
    pp=open("random.teks","w")
    count=0
    for i in range(randcount):
        t=secrets.randbits(128)
        TEKs.append(t)
        pp.write(hex(t)[2:].zfill(32)+"\n")
        count+=1
        if count % batch == 0:
            print("Random TEKs generated:",count)
    # save those in case 
    pp.close()
    pp=open("random.points","w")
    points = np.array(hilbert_curve.points_from_distances(TEKs))
    count=0
    for point in points:
        pp.write(str(point[0])+","+str(point[1])+"\n")
        count+=1
        if count % batch == 0:
            print("Random points stored:",count)
    pp.close()
    X,Y = points.T
    if heatmap:
        heatmap, xedges, yedges = np.histogram2d(X, Y, bins=bincount)
        extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
        plt.clf()
        plt.imshow(heatmap.T, extent=extent, origin='lower')
    else:
        plt.scatter(X, Y)
elif os.path.exists(pfile):
    print("Re-using points from",pfile)
    X, Y = np.loadtxt(pfile, dtype=float, delimiter=',', unpack=True)
    if heatmap:
        heatmap, xedges, yedges = np.histogram2d(X, Y, bins=bincount)
        extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
        plt.clf()
        plt.imshow(heatmap.T, extent=extent, origin='lower')
    else:
        plt.scatter(X, Y)
else:
    with open(infile) as fp:
        lines = fp.read().splitlines()
    pp=open(pfile,"w")
    TEKarray=[]
    count=0
    lineno=0
    for line in lines:
        lineno+=1
        try:
            # there is exactly one TEK in our set of 33.85M unique
            # values that is too long - being 144 bits wide - that's
            # likely someone else's bug but we'll not let it percolate
            # further
            # that value is d66cdcd462763af20dd34d34d34d34d34d34 btw
            if len(line) != 32:
                continue
            converted = int(line,16)
            TEKarray.append(converted)
            count+=1
            if count % batch == 0:
                print("Loaded ", count)
                points = np.array(hilbert_curve.points_from_distances(TEKarray))
                for point in points:
                    pp.write(str(point[0])+","+str(point[1])+"\n")
                x,y = points.T
                plt.scatter(x,y, s=0.1)
                TEKarray=[]
        except ValueError:
            print("Invalid text on line ",lineno)
    fp.close()

    # handle last few, if any
    if count % batch != 0:
        print("Final", count)
        points = np.array(hilbert_curve.points_from_distances(TEKarray))
        for point in points:
            pp.write(str(point[0])+","+str(point[1])+"\n")
        x,y = points.T
        plt.scatter(x,y, s=0.1)
    pp.close()

plt.tight_layout()    # tighten in borders
if display:
    plt.show()
fig.savefig(outfile, dpi=fig.dpi)
