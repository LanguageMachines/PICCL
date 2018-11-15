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

REQUIRE_VERSION = 2.3

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

#Amount of free memory required prior to starting a new process (in MB!), Free Memory + Cached (without swap!). Set to 0 to disable this check (not recommended)
REQUIREMEMORY = 1024

#Maximum load average at which processes are still started (first number reported by 'uptime'). Set to 0 to disable this check (not recommended)
#MAXLOADAVG = 4.0

#Minimum amount of free diskspace in MB. Set to 0 to disable this check (not recommended)
DISK = '/dev/sda1' #set this to the disk where ROOT is on
MINDISKSPACE = 0

#The amount of diskspace a user may use (in MB), this is a soft quota which can be exceeded, but creation of new projects is blocked until usage drops below the quota again
#USERQUOTA = 100

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


#The secret key is used internally for cryptographically signing session data, in production environments, you'll want to set this to a persistent value. If not set it will be randomly generated.
#SECRET_KEY = 'mysecret'


#load external configuration file (see piccl.config.yml)
loadconfig(__name__)


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
INTERFACEOPTIONS = "disableliveinput inputfromweb"

# ======== PREINSTALLED DATA ===========

#INPUTSOURCES = [
#    InputSource(id='sampledocs',label='Sample texts',path=ROOT+'/inputsources/sampledata',defaultmetadata=PlainTextFormat(None, encoding='utf-8') ),
#]

# ======== PROFILE DEFINITIONS ===========

#Define your profiles here. This is required for the project paradigm, but can be set to an empty list if you only use the action paradigm.


LANGUAGECHOICES = [('eng','English'),('nld','Dutch'),('fin','Finnish'),('fra','French'),('deu','German'),('deu_frak','German Fraktur'),('ell','Greek (Modern)'),('grc','Greek (Classical)'),('isl','Icelandic'),('ita','Italian'),('lat','Latin'),('pol','Polish'),('por','Portuguese'),('ron','Romanian'),('rus','Russian'),('spa','Spanish'),('swe','Swedish')]

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
    InputSource(id='dutchold', label="[Dutch (historical)] TEST data: DPO35 Kalliopi Selection",
        path=PICCLDATAROOT + "/corpora/OCR/DPO35test/",
        metadata=FoLiAXMLFormat(None, encoding='utf-8'),
        inputtemplate='foliaocr'
    )]
if os.path.exists(PICCLDATAROOT + "/corpora/OCR/DPO35tif"):
    INPUTSOURCES += [InputSource(id='dpo35tif', label="[Dutch (historical)] Demonstrator/test data: DPO35 - Martinet book (full)",
        path=PICCLDATAROOT + "/corpora/OCR/DPO35tif/",
        metadata=TiffImageFormat(None),
        inputtemplate='tif'
    )]
if os.path.exists(PICCLDATAROOT + "/data/int/nld"):
    INPUTSOURCES += [InputSource(id='contempNLDlex', label="[Lexicon] Contemporary Dutch Lexicon (Aspell)",
        path=PICCLDATAROOT + "/data/int/nld/nld.aspell.dict",
        metadata=PlainTextFormat(None, encoding='utf-8',language='nld'),
        inputtemplate='lexicon'
    ),
    InputSource(id='contempNLD2lex', label="[Lexicon] Contemporary Dutch Lexicon (Compilation)",
        path=PICCLDATAROOT + "/data/int/nld/ARG4.SGDLEX.UTF8.TICCL.v.4.lst",
        metadata=PlainTextFormat(None, encoding='utf-8',language='nld'),
        inputtemplate='lexicon'
    ),
    InputSource(id='histNLDlex', label="[Lexicon] Historical and Contemporary Dutch Lexicon, with names",
        path=PICCLDATAROOT + "/data/int/nld/nuTICCL.OldandINLlexandINLNamesAspell.v2.COL1.tsv",
        metadata=PlainTextFormat(None, encoding='utf-8',language='nld'),
        inputtemplate='lexicon'
    )]



def generateoutputtemplates(ocrinput=True,inputextension='.pdf'):
    """Because we reuse output template for a large number of profiles, we return them on the fly there so we don't have
    unnecessary duplication"""
    outputtemplates = []
    if ocrinput:
        #do we have an OCR input stage? then we get OCR output
        outputtemplates += [OutputTemplate('folia', FoLiAXMLFormat, 'OCR Output',
            removeextension=inputextension,
            extension='folia.xml',
            multi=True,
        )]
    outputtemplates += [
         ParameterCondition(ticcl="yes", then=[
            #TICCL was enabled, so we obtain TICCL output:
            InputTemplate('lexicon', PlainTextFormat, "Lexicon (one word per line)",
               StaticParameter(id='encoding',name='Encoding',description='The character encoding of the file', value='utf-8'),
               filename="lexicon.lst",
               unique=True,
               optional=True,
            ),
            OutputTemplate('ranked', PlainTextFormat, 'Ranked Variant Output',
               SetMetaField('encoding','utf-8'),
               filename='corpus.wordfreqlist.tsv.clean.ldcalc.ranked',
               unique=True,
            ),
            OutputTemplate('folia', FoLiAXMLFormat, 'OCR post-correction output (TICCL)',
                removeextension=inputextension,
                extension='ticcl.folia.xml',
                multi=True,
            ),
          ]),
          ParameterCondition(frog="yes", then=[
            #Frog was enabled, so we obtain Frog output:
            OutputTemplate('folia', FoLiAXMLFormat, 'Linguistic enrichment output (Frog)',
                removeextension=inputextension,
                extension='frogged.folia.xml',
                multi=True,
            ),
          ]),
          ParameterCondition(ucto="yes", then=[
            OutputTemplate('folia', FoLiAXMLFormat, 'Tokeniser Output (ucto)',
                removeextension=inputextension,
                extension='tok.folia.xml',
                multi=True,
            ),
          ])
    ]
    return outputtemplates




PROFILES = [

    Profile(
        InputTemplate('tif', TiffImageFormat, 'TIF image of a scanned page (perform OCR)',
           extension='tif',
           multi=True,
        ),
        *generateoutputtemplates(ocrinput=True, inputextension='.tif'),
    ),

    Profile(
        InputTemplate('pdfimages', PDFFormat, 'PDF document with scanned pages (images) (perform OCR)',
           extension='pdf',
           multi=True,
        ),
        *generateoutputtemplates(ocrinput=True, inputextension='.pdf'), #this function is defined above to prevent unnecessary duplication
    ),

    Profile(
        InputTemplate('pdftext', PDFFormat, 'PDF document with embedded text (no OCR)',
           extension='pdf',
           multi=True,
        ),
        *generateoutputtemplates(ocrinput=False, inputextension='.pdf'), #this function is defined above to prevent unnecessary duplication

    ),


    Profile(
        InputTemplate('djvu', PDFFormat, 'DJVU document containing scanned pages (perform OCR)',
           extension='djvu',
           multi=True,
        ),
        *generateoutputtemplates(ocrinput=True, inputextension='.djvu'), #this function is defined above to prevent unnecessary duplication

    ),

    Profile(
        InputTemplate('textocr', PDFFormat, 'Plain-text document (no OCR)',
           extension='txt',
           multi=True,
        ),
        *generateoutputtemplates(ocrinput=True, inputextension='.txt'), #this function is defined above to prevent unnecessary duplication

    ),

    Profile(
        InputTemplate('foliaocr', FoLiAXMLFormat, 'FoLiA with OCR text layer already present (no OCR)',
           extension='folia.xml',
           multi=True,
        ),
        *generateoutputtemplates(ocrinput=False, inputextension='.folia.xml'), #this function is defined above to prevent unnecessary duplication
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
if PICCLDIR:
    COMMAND = WEBSERVICEDIR + "/picclservice_wrapper.py $DATAFILE $STATUSFILE $INPUTDIRECTORY $OUTPUTDIRECTORY " + PICCLDATAROOT + " " + PICCLDIR
else:
    COMMAND = WEBSERVICEDIR + "/picclservice_wrapper.py $DATAFILE $STATUSFILE $INPUTDIRECTORY $OUTPUTDIRECTORY " + PICCLDATAROOT

# ======== PARAMETER DEFINITIONS ===========

#The global parameters (for the project paradigm) are subdivided into several
#groups. In the form of a list of (groupname, parameters) tuples. The parameters
#are a list of instances from common/parameters.py

PARAMETERS = [
    ("Input Options", [
        ChoiceParameter('lang','Language?',"Specify the language of your input documents", choices=LANGUAGECHOICES), #old ticcl -t
        BooleanParameter('reassemble','Reassemble PDF',"Use this option if you have PDF input files, such as chapters or pages, that first need to be merged together prior to processing. Filenames must be named {documentname}-{sequencenumber}.pdf for this to work.")
    ]),
    ("OCR post-correction (TICCL)", [
        ChoiceParameter('ticcl','Enable TICCL?',"Perform OCR post-correction and normalisation using TICCL? You can fine-tune parameters in the category below", choices=[('yes','Yes'),('no','No')], default='yes'),
    ]),
    ('OCR post-correction parameters', [
        ChoiceParameter('rank','How many ranked variants?','Return N best-first ranked variants',choices=[('1','First-best Only'),('2','Up to two N-best ranked'),('3','Up to three N-best ranked'),('5','Up to five N-best ranked'),('10','Up to ten N-best ranked'),('20','Up to twenty N-best ranked')]), #old ticcl -r
        ChoiceParameter('distance','How many edits?','Search a distance of N characters for variants (Edit/Levenshtein) distance)',choices=[('2','Up to two edits'),('1','Only one edit')]) #old TICCL -L
    ]),
    ('Tokenisation', [
        ChoiceParameter('ucto','Enable Tokenisation?',"Perform tokenisation using ucto? (works for various languages). There is no need to enable this if you also enable Frog below.", choices=[('yes','Yes'),('no','No')], default='yes'),
    ])
    ('Linguistic Enrichment', [
        ChoiceParameter('frog','Enable Linguistic Enrichment?',"Perform linguistic enrichment using Frog? This works for dutch only. Use the next two categories to fine-tune your selection.", choices=[('yes','Yes'),('no','No')], default='yes'),
    ])
    ('Basic enrichments steps (recommended)', [
        BooleanParameter('tok','Tokenisation',"Perform tokenisation", default=True),
        BooleanParameter('pos','Part-of-Speech Tagging',"Part-of-speech Tagging (for Dutch only!)",default=True),
        BooleanParameter('lemma','Lemmatisation',"Lemmatisation (for Dutch only!)", default=True),
    ]),
    ('Other enrichments steps (advanced)', [
        BooleanParameter('morph','Morphological Analysis',"Morphological Analysis (for Dutch only!)", default=False),
        BooleanParameter('ner','Named Entity Recognition',"Named Entity Recognition", default=False),
        BooleanParameter('parser','Dependency Parser',"Dependency parser (for Dutch only!)", default=False),
        BooleanParameter('chunker','Chunker / Shallow-parser Parser',"Chunker / Shallow parser (for Dutch only!)", default=False),
    ]),
    ('Debug', [
        BooleanParameter('debug',"Enable extra debug output (make sure to delete the project after you are done!)", default=False),
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


# ======== DISPATCHING (ADVANCED! YOU CAN SAFELY SmedKIP THIS!) ========

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
