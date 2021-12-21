#!/usr/bin/python3

# Count bits in AES keys (just in case:-)

import numpy as np
import time
import os, sys, argparse
import matplotlib.pyplot as plt
import secrets

def bitCount(int_type):
    count = 0
    while(int_type):
        int_type &= int_type - 1
        count += 1
    return(count)

def updateBitCounts(int_type, accum):
    try:
        for i in range(127):
            if int_type & (1 << (127-i)):
                accum[i] += 1
        accum[127] += int_type % 2
    except:
        print("Ooops")
        

# default values
infile="teks.ah.uni"    # ascii-hex encoded TEKS, one per line
batch = 10000           # number of lines to read before processing
outfile="bitcounts.png" # our output Hilbert curve image
width = 16              # image width, in inches
display = False         # whether to call plt.show()

# command line arg handling 
argparser=argparse.ArgumentParser(description='Map AES keys to Hilbert Curve')
argparser.add_argument('-i','--input', dest='infile', help='file containing list of TEKs')
argparser.add_argument('-o','--output_file', dest='outfile', help='file for image')
argparser.add_argument('-w','--width', dest='width', type=int, help='width of plot')
argparser.add_argument('-D','--display', dest='display', action='store_true', help='interactively display plot')
args=argparser.parse_args()

if args.infile is not None and infile != args.infile:
    infile=args.infile
    print("reading from file:", infile)
if args.outfile is not None and outfile != args.outfile:
    outfile=args.outfile
    print("writing to file:", outfile)
if args.width is not None and width != args.width:
    width=args.width
    print("image width:", width)
if args.display is not None and display != args.display:
    display=args.display
    print("plot display:", display)

# get our output ready...
fig=plt.figure(figsize=(width,width))

with open(infile) as fp:
    lines = fp.read().splitlines()
TEKonesarray={}
bitcounts={}
for i in range(128):
    bitcounts[i]=0
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
        bc=bitCount(converted)
        if bc not in TEKonesarray: 
            TEKonesarray[bc] = 1
        else:
            TEKonesarray[bc] += 1
        updateBitCounts(converted,bitcounts)
        count+=1
        if count % batch == 0:
            print("Loaded ", count)
    except ValueError:
        print("Invalid text on line ",lineno)
fp.close()
# note last few, if any
if count % batch != 0:
    print("Final", count)

maxones=0
for i in range(128):
    if i in TEKonesarray:
        if TEKonesarray[i] > maxones:
            maxones = TEKonesarray[i]


for i in range(128):
    bitcounts[i] /= count
    bitcounts[i] *= maxones 
    #if i in TEKonesarray:
        #TEKonesarray[i] /= maxones

plt.bar(list(bitcounts.keys()), bitcounts.values(), color='g')
plt.bar(list(TEKonesarray.keys()), TEKonesarray.values(), color='b')

plt.tight_layout()    # tighten in borders
if display:
    plt.show()
fig.savefig(outfile, dpi=fig.dpi)
