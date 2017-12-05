#!/usr/bin/env python
#-*- coding:utf-8 -*-

###############################################################
# CLAM: Computational Linguistics Application Mediator
# -- Service Configuration File (Template) --
#       by Maarten van Gompel (proycon)
#       Centre for Language and Speech Technology / Language Machines
#       Radboud University Nijmegen
#
#       https://proycon.github.io/clam
#
#       Licensed under GPLv3
#
###############################################################

#Consult the CLAM manual for extensive documentation

#If we run on Python 2.7, behave as much as Python 3 as possible
from __future__ import print_function, unicode_literals, division, absolute_import

from clam.common.parameters import *
from clam.common.formats import *
from clam.common.converters import *
from clam.common.viewers import *
from clam.common.data import *
from clam.common.digestauth import pwhash
import clam
import sys
import os
from base64 import b64decode as D

REQUIRE_VERSION = 2.1

CLAMDIR = clam.__path__[0] #directory where CLAM is installed, detected automatically
WEBSERVICEDIR = os.path.dirname(os.path.abspath(__file__)) #directory where this webservice is installed, detected automatically

# ======== GENERAL INFORMATION ===========

# General information concerning your system.


#The System ID, a short alphanumeric identifier for internal use only
SYSTEM_ID = "piccl"
#System name, the way the system is presented to the world
SYSTEM_NAME = "PICCL"

#An informative description for this system (this should be fairly short, about one paragraph, and may not contain HTML)
SYSTEM_DESCRIPTION = "PICCL"

# ======== LOCATION ===========

#Add a section for your host:

host = os.uname()[1]
if 'VIRTUAL_ENV' in os.environ:

    HOST = host
    if host in ('applejack','mlp01'): #production configuration in Nijmegen
        HOST = "webservices-lst.science.ru.nl"
        PORT= 443
        URLPREFIX = "piccl"
        USERS_MYSQL = {
            'host': 'mysql-clamopener.science.ru.nl',
            'user': 'clamopener',
            'password': D(open(os.environ['CLAMOPENER_KEYFILE']).read().strip()),
            'database': 'clamopener',
            'table': 'clamusers_clamusers'
        }
        DEBUG = False
        REALM = "WEBSERVICES-LST"
        DIGESTOPAQUE = open(os.environ['CLAM_DIGESTOPAQUEFILE']).read().strip()
        SECRET_KEY = open(os.environ['CLAM_SECRETKEYFILE']).read().strip()
        ADMINS = ['proycon','antalb','wstoop']
        MAXLOADAVG = 20.0
    else:
        PORT = 8080

    PICCLDATAROOT = os.path.join(os.environ['VIRTUAL_ENV'], 'piccldata') #Path that holds the data/ and corpora/ dirs
    if not os.path.exists(PICCLDATAROOT):
        raise Exception("Data root dir " + PICCLDATAROOT + " is not initialised yet. Create the directory, enter it and run: nextflow run LanguageMachines/PICCL/download-data.nf and nextflow run LanguageMachines/PICCL/download-examples.nf")

    ROOT = PICCLDATAROOT + "/clamdata/"
elif os.path.exists('/var/piccldata'):
    #assume we are running in LaMachine docker or VM:

    HOST = host
    PORT = 80 #(for HTTPS set this to 443)
    URLPREFIX = '/piccl/'

    PICCLDATAROOT = '/var/piccldata' #Path that holds the data/ and corpora/ dirs
    if not os.path.exists(PICCLDATAROOT):
        raise Exception("Data root dir " + PICCLDATAROOT + " is not initialised yet. Create the directory, enter it and run: nextflow run LanguageMachines/PICCL/download-data.nf and nextflow run LanguageMachines/PICCL/download-examples.nf")

    ROOT = PICCLDATAROOT + "/clamdata/"
else:
    raise Exception("I don't know where I'm running from! Add a section in the configuration corresponding to this host (" + os.uname()[1]+")")



# ======== AUTHENTICATION & SECURITY ===========

#Users and passwords

#set security realm, a required component for hashing passwords (will default to SYSTEM_ID if not set)
#REALM = SYSTEM_ID

USERS = None #no user authentication/security (this is not recommended for production environments!)

ADMINS = None #List of usernames that are administrator and can access the administrative web-interface (on URL /admin/)

#If you want to enable user-based security, you can define a dictionary
#of users and (hashed) passwords here. The actual authentication will proceed
#as HTTP Digest Authentication. Although being a convenient shortcut,
#using pwhash and plaintext password in this code is not secure!!

#USERS = { user1': '4f8dh8337e2a5a83734b','user2': pwhash('username', REALM, 'secret') }

#Amount of free memory required prior to starting a new process (in MB!), Free Memory + Cached (without swap!). Set to 0 to disable this check (not recommended)
REQUIREMEMORY = 1024

#Maximum load average at which processes are still started (first number reported by 'uptime'). Set to 0 to disable this check (not recommended)
#MAXLOADAVG = 4.0

#Minimum amount of free diskspace in MB. Set to 0 to disable this check (not recommended)
DISK = '/dev/sda1' #set this to the disk where ROOT is on
MINDISKSPACE = 0

#The amount of diskspace a user may use (in MB), this is a soft quota which can be exceeded, but creation of new projects is blocked until usage drops below the quota again
#USERQUOTA = 100

#The secret key is used internally for cryptographically signing session data, in production environments, you'll want to set this to a persistent value. If not set it will be randomly generated.
#SECRET_KEY = 'mysecret'

# ======== WEB-APPLICATION STYLING =============

#Choose a style (has to be defined as a CSS file in clam/style/ ). You can copy, rename and adapt it to make your own style
STYLE = 'classic'

# ======== ENABLED FORMATS ===========

#In CUSTOM_FORMATS you can specify a list of Python classes corresponding to extra formats.
#You can define the classes first, and then put them in CUSTOM_FORMATS, as shown in this example:

#class MyXMLFormat(CLAMMetaData):
#    attributes = {}
#    name = "My XML format"
#    mimetype = 'text/xml'

# CUSTOM_FORMATS = [ MyXMLFormat ]

# ======= INTERFACE OPTIONS ===========

#Here you can specify additional interface options (space separated list), see the documentation for all allowed options
#INTERFACEOPTIONS = "inputfromweb" #allow CLAM to download its input from a user-specified url
INTERFACEOPTIONS = "disableliveinput"

# ======== PREINSTALLED DATA ===========

#INPUTSOURCES = [
#    InputSource(id='sampledocs',label='Sample texts',path=ROOT+'/inputsources/sampledata',defaultmetadata=PlainTextFormat(None, encoding='utf-8') ),
#]

# ======== PROFILE DEFINITIONS ===========

#Define your profiles here. This is required for the project paradigm, but can be set to an empty list if you only use the action paradigm.


LANGUAGECHOICES = [('eng','English'),('nld','Dutch'),('fin','Finnish'),('fra','French'),('deu','German'),('deu_frak','German Fraktur'),('ell','Greek (Modern)'),('grc','Greek (Classical)'),('isl','Icelandic'),('ita','Italian'),('lat','Latin'),('pol','Polish'),('por','Portuguese'),('rus','Russian'),('spa','Spanish'),('swe','Swedish')]

INPUTSOURCES = []
if os.path.exists(PICCLDATAROOT + "/corpora/TIFF/NLD"):
    INPUTSOURCES.append(InputSource(id='dutchtif', label="[Dutch] Demonstrator data: Martinet DPO_35 Scanned page images (tif format)",
        path=PICCLDATAROOT + "/corpora/TIFF/NLD/",
        metadata=TiffImageFormat(None),
        inputtemplate='tif'
    ))
if os.path.exists(PICCLDATAROOT + "/corpora/PDF/ENG"):
    INPUTSOURCES += [InputSource(id='englishpdf', label="[English] Demonstrator data: Geets paper (PDF format)",
        path=PICCLDATAROOT + "/corpora/PDF/ENG/",
        metadata=PDFFormat(None),
        inputtemplate='pdfimages'
    ),
    InputSource(id='englishimageslarge', label="[English] Demonstrator data: Russell -- Western Philosophy (DJVU format)",
        path=PICCLDATAROOT + "/corpora/DJVU/ENG/",
        metadata=DjVuFormat(None),
        inputtemplate='djvu'
    ),
    InputSource(id='englishtxt', label="[English] Demonstrator data: Russell -- Western Philosophy (Plain text format)",
        path=PICCLDATAROOT + "/corpora/TXT/ENG/",
        metadata=PlainTextFormat(None, encoding='utf-8'),
        inputtemplate='textocr'
    )]
if os.path.exists(PICCLDATAROOT + "/corpora/FOLIA/DEU-FRAK"):
    INPUTSOURCES += [InputSource(id='germandata', label="[German Fraktur] Demonstrator data: Bolzano Gold Standard post-OCR FoLiA xml",
        path=PICCLDATAROOT + "/corpora/FOLIA/DEU-FRAK/",
        metadata=FoLiAXMLFormat(None, encoding='utf-8'),
        inputtemplate='foliaocr'
    ),
    InputSource(id='germanPDFbook', label="[German Fraktur] Demonstrator data: Bolzano Wissenschaftslehre PDF-images - full book",
        path=PICCLDATAROOT + "/corpora/PDF/DEU-FRAK/BolzanoWLfull",
        metadata=PDFFormat(None),
        inputtemplate='pdfimages'
    ),
    InputSource(id='germanPDFdemo', label="[German Fraktur] Demonstrator data: Bolzano Wissenschaftslehre PDF-images - Vorrede only",
        path=PICCLDATAROOT + "/corpora/PDF/DEU-FRAK/BolzanoWLdemo",
        metadata=PDFFormat(None),
        inputtemplate='pdfimages'
    )]
if os.path.exists(PICCLDATAROOT + "/corpora/PDF/FRA"):
    INPUTSOURCES += [InputSource(id='frenchimagessmall', label="[French] Demonstrator data: Delpher dpo-7270 (PDF-images)",
        path=PICCLDATAROOT + "/corpora/PDF/FRA/",
        metadata=PDFFormat(None),
        inputtemplate='pdfimages'
    )]
if os.path.exists(PICCLDATAROOT + "/corpora/OCR"):
    INPUTSOURCES += [InputSource(id='dutchnew', label="[Dutch] TEST data: VUDNC Kalliopi Selection",
        path=PICCLDATAROOT + "/corpora/OCR/VUDNCtest/",
        metadata=FoLiAXMLFormat(None, encoding='utf-8'),
        inputtemplate='foliaocr'
    ),
    InputSource(id='dutchold', label="[Dutch (old)] TEST data: DPO35 Kalliopi Selection",
        path=PICCLDATAROOT + "/corpora/OCR/DPO35test/",
        metadata=FoLiAXMLFormat(None, encoding='utf-8'),
        inputtemplate='foliaocr'
    )]

PROFILES = [

    Profile(
        InputTemplate('tif', TiffImageFormat, 'TIF image of a scanned page',
           extension='tif',
           multi=True,
        ),
        OutputTemplate('ranked', PlainTextFormat, 'Ranked Variant Output',
           SetMetaField('encoding','utf-8'),
           filename='corpus.wordfreqlist.tsv.clean.ldcalc.ranked',
           unique=True,
        ),
        OutputTemplate('folia', FoLiAXMLFormat, 'TICCL Output',
            extension='ticcl.folia.xml', #pending
            multi=True,
        ),
    ),

    Profile(
        InputTemplate('pdfimages', PDFFormat, 'PDF document containing scanned pages',
           extension='pdf',
           multi=True,
        ),
        OutputTemplate('ranked', PlainTextFormat, 'Ranked Variant Output',
           SetMetaField('encoding','utf-8'),
           filename='corpus.wordfreqlist.tsv.clean.ldcalc.ranked',
           unique=True,
        ),
        OutputTemplate('folia', FoLiAXMLFormat, 'TICCL Output',
            removeextension='.pdf',
            extension='ticcl.folia.xml',
            multi=True,
        ),
    ),

    Profile(
        InputTemplate('djvu', PDFFormat, 'DJVU document containing scanned pages',
           extension='djvu',
           multi=True,
        ),
        OutputTemplate('ranked', PlainTextFormat, 'Ranked Variant Output',
           SetMetaField('encoding','utf-8'),
           filename='corpus.wordfreqlist.tsv.clean.ldcalc.ranked',
           unique=True,
        ),
        OutputTemplate('folia', FoLiAXMLFormat, 'TICCL Output',
            removeextension='.pdf',
            extension='ticcl.folia.xml',
            multi=True,
        ),
    ),

    Profile(
        InputTemplate('textocr', PDFFormat, 'Post-OCR text document',
           extension='txt',
           multi=True,
        ),
        OutputTemplate('ranked', PlainTextFormat, 'Ranked Variant Output',
           SetMetaField('encoding','utf-8'),
           filename='corpus.wordfreqlist.tsv.clean.ldcalc.ranked',
           unique=True,
        ),
        OutputTemplate('folia', FoLiAXMLFormat, 'TICCL Output',
            removeextension='.pdf',
            extension='ticcl.folia.xml',
            multi=True,
        ),
    ),

    Profile(
        InputTemplate('foliaocr', FoLiAXMLFormat, 'FoLiA with OCR text layer',
           extension='folia.xml',
           multi=True,
        ),
        OutputTemplate('ranked', PlainTextFormat, 'Ranked Variant Output',
           SetMetaField('encoding','utf-8'),
           filename='corpus.wordfreqlist.tsv.clean.ldcalc.ranked',
           unique=True,
        ),
        OutputTemplate('folia', FoLiAXMLFormat, 'TICCL Output',
            removeextension='.pdf',
            extension='ticcl.folia.xml',
            multi=True,
        ),
    ),

]

# ======== COMMAND ===========

#The system command for the project paradigm.
#It is recommended you set this to small wrapper
#script around your actual system. Full shell syntax is supported. Using
#absolute paths is preferred. The current working directory will be
#set to the project directory.
#
#You can make use of the following special variables,
#which will be automatically set by CLAM:
#     $INPUTDIRECTORY  - The directory where input files are uploaded.
#     $OUTPUTDIRECTORY - The directory where the system should output
#                        its output files.
#     $TMPDIRECTORY    - The directory where the system should output
#                        its temporary files.
#     $STATUSFILE      - Filename of the .status file where the system
#                        should output status messages.
#     $DATAFILE        - Filename of the clam.xml file describing the
#                        system and chosen configuration.
#     $USERNAME        - The username of the currently logged in user
#                        (set to "anonymous" if there is none)
#     $PARAMETERS      - List of chosen parameters, using the specified flags
#
COMMAND = WEBSERVICEDIR + "/picclservice_wrapper.py $DATAFILE $STATUSFILE $INPUTDIRECTORY $OUTPUTDIRECTORY " + PICCLDATAROOT

# ======== PARAMETER DEFINITIONS ===========

#The global parameters (for the project paradigm) are subdivided into several
#groups. In the form of a list of (groupname, parameters) tuples. The parameters
#are a list of instances from common/parameters.py

PARAMETERS = [
    ('Language Selection', [
        ChoiceParameter('lang','Language?','Which language do you want to work with?', choices=LANGUAGECHOICES) #old ticcl -t
    ]),
    ('N-best Ranking', [
            ChoiceParameter('rank','How many ranked variants?','Return N best-first ranked variants',choices=[('3','Up to three N-best ranked'),('1','First-best Only'),('2','Up to two N-best ranked'),('5','Up to five N-best ranked'),('10','Up to ten N-best ranked'),('20','Up to twenty N-best ranked')]) #old ticcl -r
    ]),
    ('Edit/Levenshtein Distance', [
        ChoiceParameter('distance','How many edits?','Search a distance of N characters for variants',choices=[('2','Up to two edits'),('1','Only one edit')]) #old TICCL -L
    ]),
    #('Focus Word Selection', [
    #    IntegerParameter('minlength','Minimum Word Length','Integer between zero and one hundred',default=5,minvalue=0, maxvalue=100), #old ticcl -x
    #    IntegerParameter('maxlength','Maximum Word Length','Integer between zero and one hundred',default=100,minvalue=0, maxvalue=100), #old ticcl -y
    #]),
]



# ======= ACTIONS =============

#The action paradigm is an independent Remote-Procedure-Call mechanism that
#allows you to tie scripts (command=) or Python functions (function=) to URLs.
#It has no notion of projects or files and must respond in real-time. The syntax
#for commands is equal to those of COMMAND above, any file or project specific
#variables are not available though, so there is no $DATAFILE, $STATUSFILE, $INPUTDIRECTORY, $OUTPUTDIRECTORY or $PROJECT.

ACTIONS = [
    #Action(id='multiply',name='Multiply',parameters=[IntegerParameter(id='x',name='Value'),IntegerParameter(id='y',name='Multiplier'), command=sys.path[0] + "/actions/multiply.sh $PARAMETERS" ])
    #Action(id='multiply',name='Multiply',parameters=[IntegerParameter(id='x',name='Value'),IntegerParameter(id='y',name='Multiplier'), function=lambda x,y: x*y ])
]


# ======== DISPATCHING (ADVANCED! YOU CAN SAFELY SKIP THIS!) ========

#The dispatcher to use (defaults to clamdispatcher.py), you almost never want to change this
#DISPATCHER = 'clamdispatcher.py'

#DISPATCHER_POLLINTERVAL = 30   #interval at which the dispatcher polls for resource consumption (default: 30 secs)
#DISPATCHER_MAXRESMEM = 0    #maximum consumption of resident memory (in megabytes), processes that exceed this will be automatically aborted. (0 = unlimited, default)
#DISPATCHER_MAXTIME = 0      #maximum number of seconds a process may run, it will be aborted if this duration is exceeded.   (0=unlimited, default)
#DISPATCHER_PYTHONPATH = []        #list of extra directories to add to the python path prior to launch of dispatcher

#Run background process on a remote host? Then set the following (leave the lambda in):
#REMOTEHOST = lambda: return 'some.remote.host'
#REMOTEUSER = 'username'

#For this to work, the user under which CLAM runs must have (passwordless) ssh access (use ssh keys) to the remote host using the specified username (ssh REMOTEUSER@REMOTEHOST)
#Moreover, both systems must have access to the same filesystem (ROOT) under the same mountpoint.
