#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "------------------------------------"
log.info "Download example corpora for PICCL"
log.info "------------------------------------"

process download {
    publishDir "corpora", mode: 'copy', overwrite: true

    output:
    file "**" into output

    script:
    """
    wget http://ticclops.uvt.nl/TICCL.SampleCorpora.20160504.ALL.tar.gz -O corpora.tar.gz
    tar -xvzf corpora.tar.gz
    mv corpora/* .
    rm -Rf corpora
    rm corpora.tar.gz
    #adhere to naming convention
    for i in `seq 0 9`; do mv corpora/TIFF/NLD/dpo_35_030\${i}_master.tif corpora/TIFF/NLD/dpo_35-030\${i}.tif; done
    """
}
