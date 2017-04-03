#!/usr/bin/env python
#-*- coding:utf-8 -*-

#CLAM wrapper script for PICCL

#This script will be called by CLAM and will run with the current working directory set to the specified project directory

#This wrapper script uses Python and the CLAM Data API.
#We make use of the XML settings file that CLAM outputs, rather than
#passing all parameters on the command line.


#If we run on Python 2.7, behave as much as Python 3 as possible
from __future__ import print_function, unicode_literals, division, absolute_import

#import some general python modules:
import sys

#import CLAM-specific modules. The CLAM API makes a lot of stuff easily accessible.
import clam.common.data
import clam.common.status

#When the wrapper is started, the current working directory corresponds to the project directory, input files are in input/ , output files should go in output/ .

#make a shortcut to the shellsafe() function
shellsafe = clam.common.data.shellsafe

#this script takes three arguments from CLAM: $DATAFILE $STATUSFILE $OUTPUTDIRECTORY
#(as configured at COMMAND= in the service configuration file, there you can
#reconfigure which arguments are passed and in what order.
datafile = sys.argv[1]
statusfile = sys.argv[2]
inputdir = sys.argv[3]
outputdir = sys.argv[4]
piccldataroot = sys.argv[5]

#If you make use of CUSTOM_FORMATS, you need to import your service configuration file here and set clam.common.data.CUSTOM_FORMATS
#Moreover, you can import any other settings from your service configuration file as well:

#from yourserviceconf import CUSTOM_FORMATS

#Obtain all data from the CLAM system (passed in $DATAFILE (clam.xml)), always pass CUSTOM_FORMATS as second argument if you make use of it!
clamdata = clam.common.data.getclamdata(datafile)

#You now have access to all data. A few properties at your disposition now are:
# clamdata.system_id , clamdata.project, clamdata.user, clamdata.status , clamdata.parameters, clamdata.inputformats, clamdata.outputformats , clamdata.input , clamdata.output

clam.common.status.write(statusfile, "Starting...")


#=========================================================================================================================

datadir = os.path.join(piccldataroot,'data','int',clamdata['lang'])
if not os.path.exists(datadir):
    errmsg = "ERROR: Unable to find data files for language '" + clamdata['lang'] + "' in path " + piccldataroot
    clam.common.status.write(statusfile, errmsg,0) # status update
    print(errmsg,file=sys.stderr)
    sys.exit(4)

#loop over all data files and copy (symlink actually to save diskspace and time) to the current working directory (project dir)
for f in glob.glob(datadir + '/*'):
    if f.split('.')[-1] == 'dict':
        os.symlink('lexicon.lst', f)
    if f.split('.')[-1] == 'chars':
        os.symlink('alphabet.lst', f)
    if f.split('.')[-1] == 'confusion':
        os.symlink('confusion.lst', f)

if not os.path.exists('lexicon.lst'):
    errmsg = "ERROR: Unable to find lexicon file for language '" + clamdata['lang'] + "' in path " + piccldataroot
    clam.common.status.write(statusfile, errmsg,0) # status update
    print(errmsg,file=sys.stderr)
    sys.exit(4)
if not os.path.exists('alphabet.lst'):
    errmsg = "ERROR: Unable to find alphabet file for language '" + clamdata['lang'] + "' in path " + piccldataroot
    clam.common.status.write(statusfile, errmsg,0) # status update
    print(errmsg,file=sys.stderr)
    sys.exit(4)
if not os.path.exists('confusion.lst'):
    errmsg = "ERROR: Unable to find confusion file for language '" + clamdata['lang'] + "' in path " + piccldataroot
    clam.common.status.write(statusfile, errmsg,0) # status update
    print(errmsg,file=sys.stderr)
    sys.exit(4)


#Derive input type from used inputtemplate
inputtype = ''
for inputfile in clamdata.input:
   inputtemplate = inputfile.metadata.inputtemplate
   if inputtemplate == 'pdfimages':
       inputtype = 'pdfimages'
   elif inputtemplate == 'tif':
        inputtype == 'tif'
   elif inputtemplate == 'jpg':
        inputtype == 'jpg'
   elif inputtemplate == 'png':
        inputtype == 'png'
   elif inputtemplate == 'gif':
        inputtype == 'gif'

if not inputtype:
    errmsg = "ERROR: Unable to deduce input type on the basis of input files (should not happen)!"
    clam.common.status.write(statusfile, errmsg,0) # status update
    print(errmsg,file=sys.stderr)
    sys.exit(5)


clam.common.status.write(statusfile, "Running OCR Pipeline",1) # status update
os.system("nextflow run LanguageMachines/PICCL/ocr.nf --inputdir " + shellsafe(inputdir,'"') + " --outputdir ocr_output --inputtype " + shellsafe(inputtype,'"') + " --language " + shellsafe(clamdata['lang'],'" -with-trace') );

#Print Nextflow trace information to stderr so it ends up in the CLAM error.log and is available for inspection
print(open('trace.txt','r',encoding='utf-8').read(), file=sys.stderr)

clam.common.status.write(statusfile, "Running TICCL Pipeline",50) # status update
os.system("nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir ocr_output --outputdir i" + shellsafe(outputdir,'"') + " --lexicon lexicon.lst --alphabet alphabet.lst --charconfus charconfus.lst --clip " + shellsafe(clamdata['rank']) + " --distance " + shellsafe(clamdata['distance']) + " --clip " + shellsafe(clamdata['rank']) + " -with-trace"  );

#Print Nextflow trace information to stderr so it ends up in the CLAM error.log and is available for inspection
print(open('trace.txt','r',encoding='utf-8').read(), file=sys.stderr)

#A nice status message to indicate we're done
clam.common.status.write(statusfile, "All done!",100) # status update

sys.exit(0) #non-zero exit codes indicate an error and will be picked up by CLAM as such!
