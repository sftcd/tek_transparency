#!/usr/bin/python3

# Map all TEK zips in input directory to one CSV file
# I plan to use this in analysis. As of now, it produces
# a single 12GB CSV for all the archived ZIPs, so we'll
# need to tool up some more;-)

import sys,os,argparse,tempfile
import re,binascii
import TemporaryExposureKeyExport_pb2
import hashlib
from pathlib import Path
from zipfile import ZipFile

def matchespattern(fname,pattern):
    try:
        #print("matching",pattern,"vs",fname)
        if re.match(pattern,fname):
            #print(pattern,"matches",fname)
            return True
        #print(pattern,"doesn't match",fname)
        return False
    except Exception as e:
        print("problem matching:",str(e),"when trying",pattern,"against",fname)
        sys.exit(1)

# default  values
#indir=os.path.basename(os.getcwd())
indir=os.getcwd()+"/"
outfile="teks.csv"

parser=argparse.ArgumentParser(description='Map all the GAEN TEK zipfiles in a directory into CSV entries')
parser.add_argument('-i','--input',
                    dest='indir',
                    help='name of directory containing zip file (default: .)')
parser.add_argument('-o','--output',
                    dest='outfile',
                    help='name of CSV file to produce (default: teks.csv)')
parser.add_argument('-H','--header',
                    action='store_true',
                    help='include a header line in CSV output (default: false)')
parser.add_argument('-a','--append',
                    action='store_true',
                    help='append output to an existing CSV')
parser.add_argument('-v','--verbose',
                    action='store_true',
                    help='provide some feedback')
parser.add_argument('-r','--recurse',
                    action='store_true',
                    help='recurse down from "indir" and try process all aptly-named zips')
parser.add_argument('-R','--raw',
                    action='store_true',
                    help='don\'t hash the TEK values, just emit the raw data (default: false)')
parser.add_argument('-p','--pattern',
                    dest='pattern',
                    help='provide a pattern used to select which zip files to process')
parser.add_argument('-j','--justlist',
                    action='store_true',
                    help='just list the set of zips that would be processed, then exit')
args=parser.parse_args()

if args.indir is not None:
    indir=args.indir
    if indir[-1]!='/':
        indir+="/"
if args.outfile is not None:
    outfile=args.outfile

# count lines output to CSV in case of verbose output
linecount=0
ziplist=[]

try:
    if args.recurse is False:
        lziplist = [f for f in os.listdir(indir) if os.path.isfile(os.path.join(indir, f)) and f.endswith('.zip')]
        for z in lziplist:
            if args.pattern is not None:
                if not matchespattern(indir+z,args.pattern):
                    continue
            ftime=str(os.path.getctime(indir+z))
            ziplist.append([ftime,indir+z])
    else:
        for path in Path(indir).rglob("[a-z]*-*.zip"):
            if args.pattern is not None:
                if not matchespattern(str(path),args.pattern):
                    continue
            ftime=str(os.path.getctime(path))
            ziplist.append([ftime,path])
    print("About to process " + str(len(ziplist)) + " zip files")
except Exception as e:
    print("problem making ziplist:",str(e),ziplist)
    sys.exit(1)

if len(ziplist)==0:
    print("No zipfiles selected - exiting")
    sys.exit(2)

if args.justlist is True:
    print("Would have processed",len(ziplist),"zips")
    if args.verbose:
        for z in ziplist:
            print("\t",z[1])
    sys.exit(0)

if args.append:
    outf=open(outfile,"a")
else:
    outf=open(outfile,"w")
if args.header:
    if args.raw:
        outf.write("indir,country,zipfile,filetime,zipstart,zipend,zipkeyver,zipverkeyid,tek,epoch,period,risklevel\n")
    else:
        outf.write("indir,country,zipfile,filetime,zipstart,zipend,zipkeyver,zipverkeyid,H(tek),epoch,period,risklevel\n")

# sort ziplist by file time so eventual CSV is naturally sorted
if args.verbose:
    print("Sorting ziplist")
sortedziplist = sorted(ziplist, key=lambda x:x[0])
if args.verbose:
    print("Sorted ziplist")

try:
    for zipname in sortedziplist:
        # the .de config is also a zip'd protobuf, so skip that...
        bn=os.path.basename(zipname[1])
        cfgind=bn.find("-cfg.zip")
        if cfgind!=-1:
            continue
        # we get some empty files from .ch, so skip those too
        if os.stat(zipname[1]).st_size == 0:
            continue
        # our zipnames are like ie-NNNNNN.zip, we'll use that rather than
        # the country within the zip, because the NI zip says GB (which 
        # is a bit ironic;-)
        cind=bn.find("-")
        if cind==-1:
            country="unknown"
        else:
            country=bn[0:cind]
        # vars to keep stuff for possible cleanup
        lzip=""
        ename=""

        # We'll see if we can skip malformed zips - there is at least
        # one in our archive "dk-2020-07-28.0.zip"
        try:
            # unzip, pull out export.bin, decode and store
            with ZipFile(zipname[1], 'r') as zipObj:
                # Get a list of all archived file names from the zip
                listOfFileNames = zipObj.namelist()
                # Iterate over the file names, though we only really want the one
                for fileName in listOfFileNames:
                    # Check filename is export.bin
                    if fileName == "export.bin":
                        # Extract a single file from zip
                        tmpfile=tempfile.TemporaryFile()
                        zipObj.extract(fileName, str(tmpfile.name))
                        lzip=str(tmpfile.name)
                        ename=str(tmpfile.name)+"/export.bin"
                        if os.stat(ename).st_size == 0:
                            continue
                        f = open(ename, "rb")
                        g = TemporaryExposureKeyExport_pb2.TemporaryExposureKeyExport()
                        header = f.read(16)
                        g.ParseFromString(f.read())
                        f.close()
                        for key in g.keys:
                            tekval=hashlib.sha256(key.key_data).hexdigest()
                            if args.raw:
                                tekval=key.key_data.hex()
                            outf.write( indir+","+
                                        country+","+
                                        str(zipname[1])+","+
                                        zipname[0]+","+
                                        str(g.start_timestamp)+","+str(g.end_timestamp)+","+
                                        g.signature_infos[0].verification_key_version+","+
                                        g.signature_infos[0].verification_key_id+","+
                                        tekval+","+
                                        str(key.rolling_start_interval_number)+","+
                                        str(key.rolling_period)+","+
                                        str(key.transmission_risk_level)+"\n")
                            linecount+=1
                            if args.verbose and (linecount%1000)==0:
                                print("Wrote " + str(linecount) + " lines to " + outfile + " from " + indir)
                # Tidy up if needed - I'm maybe using the TemporaryFile thing wrong;-)
                if os.path.isdir(lzip):
                    if os.path.isfile(ename):
                        os.remove(ename)
                    os.rmdir(lzip)
        except Exception as e:
            print("Skipping " + str(zipname[1]) + ":" + str(e))
except Exception as e:
    print("problem with " + str(zipname[1]) + ":" + str(e))
    sys.exit(1)

if args.verbose:
    print("Wrote " + str(linecount) + " lines to " + outfile + " from " + indir)
# All done
sys.exit(0)


