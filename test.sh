#!/bin/bash

if [ "$USER" == "travis" ]; then
   cd /home/travis/build/LanguageMachines/PICCL
   export PATH="/home/travis/build/LanguageMachines/PICCL:$PATH"
fi

if [ -d /vagrant ] || [ ! -z "$VIRTUAL_ENV" ] || [ -f /usr/bin/TICCL-anahash ]; then
    #we are in LaMachine, no need for docker
    WITHDOCKER=""
else
    #we are not in LaMachine so use the docker LaMachine:
    WITHDOCKER="-with-docker proycon/lamachine"
fi


echo "Downloading data...">&2
echo "----------------------------------------">&2
nextflow run LanguageMachines/PICCL/download-data.nf $WITHDOCKER || exit 2

echo "Downloading examples...">&2
echo "----------------------------------------">&2
nextflow run LanguageMachines/PICCL/download-examples.nf $WITHDOCKER || exit 2

echo "Testing OCR (eng) with inputtype pdfimages">&2
echo "----------------------------------------">&2
nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/PDF/ENG/ --language eng --inputtype pdfimages $WITHDOCKER || exit 2
echo "Testing TICCL (eng)">&2
echo "----------------------------------------">&2
nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir ocr_output/ --lexicon data/int/eng/eng.aspell.dict --alphabet data/int/eng/eng.aspell.dict.lc.chars --charconfus data/int/eng/eng.aspell.dict.c0.d2.confusion $WITHDOCKER || exit 2
ls ticcl_output/*xml || exit 2

rm -Rf ocr_output ticcl_output

echo "Testing OCR (nld) with inputtype tif">&2
echo "----------------------------------------">&2
nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/TIFF/NLD/ --inputtype tif --language nld $WITHDOCKER || exit 2
echo "Testing TICCL (nld)">&2
echo "----------------------------------------">&2
nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir ocr_output/ --lexicon data/int/nld/nld.aspell.dict --alphabet data/int/nld/nld.aspell.dict.lc.chars --charconfus data/int/nld/nld.aspell.dict.c20.d2.confusion $WITHDOCKER || exit 2

ls ticcl_output/*xml || exit 2
