#!/usr/bin/env python3

import sys
import os
import json
import folia.main as folia

inputfile, outputfile, metadatadir = sys.argv[1:]

id = os.path.basename(inputfile).split('.')[0]
metadatafile = metadatadir + '/' + id + '.json'
if os.path.exists(metadatafile):
    doc = folia.Document(file=inputfile)

    with open(metadatafile,'r') as f:
        data = json.load(f)
    for key, value in sorted(data.items()):
        doc.metadata[key] = value

    print("Added metadata for " + id,file=sys.stderr)
    doc.save(outputfile)
else:
    print("No metadata found for " + id,file=sys.stderr)
    os.symlink(inputfile, outputfile)





