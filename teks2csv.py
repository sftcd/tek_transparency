#!/usr/bin/python3

# Map all TEK zips in input directory to one CSV file
# I plan to use this in analysis. As of now, it produces
# a single 4.1GB CSV for all the archived ZIP, so we'll
# need to tool up some more;-)

import sys,os,argparse,tempfile
import binascii
import TemporaryExposureKeyExport_pb2
from zipfile import ZipFile

# default  values
indir=os.path.basename(os.getcwd())
outfile=indir+".csv"

parser=argparse.ArgumentParser(description='Map all the GAEN TEK zipfiles in a directory into CSV entries')
parser.add_argument('-i','--input',
                    dest='indir',
                    help='name of directory containing zip file (default: .)')
parser.add_argument('-o','--output',
                    dest='outfile',
                    help='name of CSV file to produce (default named after directory)')
parser.add_argument('-H','--header',
                    action='store_true',
                    help='include a header line in CSV output (default: false)')
parser.add_argument('-a','--append',
                    action='store_true',
                    help='append output to an existing CSV')
parser.add_argument('-v','--verbose',
                    action='store_true',
                    help='provide some feedback')
args=parser.parse_args()

if args.indir is not None:
    indir=args.indir
if args.outfile is not None:
    outfile=args.outfile

if args.append:
    outf=open(outfile,"a")
else:
    outf=open(outfile,"w")

if args.header:
    outf.write("runname,country,zipfile,zipstart,zipend,zipkeyver,zipverkeyid,tek,epoch,period,risklevel\n")

# count lines output to CSV in case of verbose output
linecount=0

try:
    ziplist = [f for f in os.listdir('.') if os.path.isfile(os.path.join('.', f)) and f.endswith('.zip')]
    for zipname in ziplist:
        # the .de config is also a zip'd protobuf, so skip that...
        cfgind=zipname.find("-cfg.zip")
        if cfgind!=-1:
            continue
        # we get some empty files from .ch, so skip those too
        if os.stat(zipname).st_size == 0:
            continue
        # our zipnames are like ie-NNNNNN.zip, we'll use that rather than
        # the country within the zip, because the NI zip says GB (which 
        # is a bit ironic;-)
        cind=zipname.find("-")
        if cind==-1:
            country="unknown"
        else:
            country=zipname[0:cind]
        # vars to keep stuff for possible cleanup
        lzip=""
        ename=""
        # unzip, pull out export.bin, decode and store
        with ZipFile(zipname, 'r') as zipObj:
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
                        outf.write( indir+","+
                                    country+","+
                                    zipname+","+str(g.start_timestamp)+","+str(g.end_timestamp)+","+
                                    g.signature_infos[0].verification_key_version+","+
                                    g.signature_infos[0].verification_key_id+","+
                                    key.key_data.hex()+","+
                                    str(key.rolling_start_interval_number)+","+
                                    str(key.rolling_period)+","+
                                    str(key.transmission_risk_level)+"\n")
                        linecount+=1
            # Tidy up if needed - I'm maybe using the TemporaryFile thing wrong;-)
            if os.path.isdir(lzip):
                if os.path.isfile(ename):
                    os.remove(ename)
                os.rmdir(lzip)
except Exception as e:
    print("problem with " + zipname + ":" + str(e))
    sys.exit(1)

if args.verbose:
    print("Wrote " + str(linecount) + " lines to " + outfile + " from " + indir)
# All done
sys.exit(0)


