#!/usr/bin/python3

# Open a TEKs csv and plot time vs. first-seen time (for each TEK)
# with a line back to the start of the epoch for that TEK

import os,sys,argparse,csv,dateutil,math,statistics
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib


def filtercsv(fname,outfile):
    uniques=[]
    cteks=[]
    rowind=0
    try:
        with open(fname) as csvfile: 
            readCSV = csv.reader(csvfile, delimiter=',')
            for row in readCSV:
                # skip header, if present
                if row[0]=="indir":
                    continue
                country=row[1]
                fftime=float(row[3])
                ftime=str(fftime)
                tek=row[8]
                iepoch=int(row[9])*600
                epoch=str(iepoch)
                ctek=country+"/"+tek
                ihourssinceepoch=int((fftime-iepoch)/3600)
                hourssinceepoch=str(ihourssinceepoch)
                if ctek not in cteks:
                    cteks.append(ctek)
                    uniques.append([ctek,country,ftime,epoch,hourssinceepoch])
                else:
                    ind=cteks.index(ctek)
                    uniques[ind]=[ctek,country,ftime,epoch,hourssinceepoch]
                rowind+=1
                if (rowind%1000)==0:
                    print("did",rowind,"rows")
    except Exception as e:
        print("Error (1) handling",fname,"at line:",str(rowind), str(e))
    print("Writing to",outfile)
    outp=open(outfile,"w")
    cind=0
    for u in uniques:
        outp.write(u[0]+","+u[1]+","+u[2]+","+u[3]+","+u[4]+"\n")
        cind+=1
        if (cind%1000)==0:
            print("wrote",cind,"rows")

# mainline processing
if __name__ == "__main__":

    # command line arg handling 
    parser=argparse.ArgumentParser(description='Plot RSSIs for a set of experiments')
    parser.add_argument('-i','--input',     
                    dest='input',
                    help='TEKs CSV file name')
    parser.add_argument('-o','--output',     
                    dest='output',
                    help='Unique CSV output file name')
    args=parser.parse_args()

    # def infile
    infile="teks.csv"
    outfile="uniques.csv"
    if args.input is not None:
        infile=args.input
    if args.output is not None:
        outfile=args.output

    filtercsv(infile,outfile)
