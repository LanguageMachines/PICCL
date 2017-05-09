#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "Download data for PICCL"
log.info "--------------------------"

process download {
    publishDir "data", mode: 'copy', overwrite: true

    output:
    file "**" into output

    script:
    """
    wget http://ticclops.uvt.nl/TICCL.languagefiles.ALLavailable.20160421.tar.gz -O data.tar.gz
    tar --one-top-level=data -xvzf data.tar.gz
    rm data.tar.gz
    """
}
