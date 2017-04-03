#!/bin/bash

~/nextflow LanguageMachines/PICCL/download-data.nf -with-docker proycon/LaMachine || exit 2
~/nextflow LanguageMachines/PICCL/download-examples.nf -with-docker proycon/LaMachine || exit 2

echo "First batch: from PDF">&2
~/nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/PDF/ENG/ --language eng --inputtype pdfimages -with-docker proycon/LaMachine || exit 2
~/nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir folia_ocr_output/ --lexicon data/int/eng/eng.aspell.dict --alphabet data/int/eng/eng.aspell.dict.lc.chars --charconfus data/int/eng/eng.aspell.dict.c0.d2.confusion -with-docker proycon/LaMachine || exit 2
ls folia_ticcl_output/*xml || exit 2

rm -Rf folia_ocr_output folia_ticcl_output

echo "Second batch: ">&2
~/nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/TIFF/NLD/ --inputtype tif --language nld -with-docker proycon/LaMachine || exit 2
~/nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir folia_ocr_output/ --lexicon data/int/nld/nld.aspell.dict --alphabet data/int/nld/nld.aspell.dict.lc.chars --charconfus data/int/eng/nld.aspell.dict.c20.d2.confusion -with-docker proycon/LaMachine || exit 2

ls folia_ticcl_output/*xml || exit 2
