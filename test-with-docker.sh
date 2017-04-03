#!/bin/bash

if [ "$USER" == "travis" ]; then
   cd /home/travis/build/LanguageMachines/PICCL
   export PATH="/home/travis/build/LanguageMachines/PICCL:$PATH"
fi


echo "Downloading data...">&2
nextflow run LanguageMachines/PICCL/download-data.nf -with-docker proycon/lamachine || exit 2

echo "Downloading examples...">&2
nextflow run LanguageMachines/PICCL/download-examples.nf -with-docker proycon/lamachine || exit 2

echo "First batch: OCR">&2
nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/PDF/ENG/ --language eng --inputtype pdfimages -with-docker proycon/lamachine || exit 2
echo "First batch: TICCL">&2
nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir folia_ocr_output/ --lexicon data/int/eng/eng.aspell.dict --alphabet data/int/eng/eng.aspell.dict.lc.chars --charconfus data/int/eng/eng.aspell.dict.c0.d2.confusion -with-docker proycon/lamachine || exit 2
ls folia_ticcl_output/*xml || exit 2

rm -Rf folia_ocr_output folia_ticcl_output

echo "Second batch: OCR">&2
nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/TIFF/NLD/ --inputtype tif --language nld -with-docker proycon/lamachine || exit 2
echo "Second batch: TICCL">&2
nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir folia_ocr_output/ --lexicon data/int/nld/nld.aspell.dict --alphabet data/int/nld/nld.aspell.dict.lc.chars --charconfus data/int/eng/nld.aspell.dict.c20.d2.confusion -with-docker proycon/lamachine || exit 2

ls folia_ticcl_output/*xml || exit 2
