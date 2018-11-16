#!/bin/bash
if [ ! -z $LM_SOURCEPATH ]; then
    export CONFIGFILE=$LM_SOURCEPATH/PICCL/webservice/picclservice/piccl.config.yml
fi
python3 setup.py develop
clamservice -d picclservice.picclservice
