#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "TICCL Pipeline"
log.info "--------------------------"

params.virtualenv = ""
params.language = "nld"
params.outputdir = "folia_ticcl_output"
params.inputclass = "OCR"
params.lexicon = ""
params.artifrq = 10000000
params.alphabet = ""

if (params.containsKey('help') || !params.containsKey('inputdir') || !params.containsKey('lexicon') || !params.containsKey('alphabet')) {
    log.info "Usage:"
    log.info "  ocr.nf [OPTIONS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory (FoLiA documents with an OCR text layer)"
    log.info "  --lexicon FILE           Path to lexicon file
    log.info "  --alphabet FILE          Path to alphabet file"
    log.info""
    log.info "Optional parameters:"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --language LANGUAGE      Language"
    log.info "  --inputclass CLASS       FoLiA text class to use for input, defaults to 'OCR', may be set to 'current' as well"
    log.info "  --virtualenv PATH        Path to Virtual Environment to load (usually path to LaMachine)"
    log.info "  --artifrq INT            Default value for missing frequencies in the validated lexicon (default: 10000000)"

    exit 2
}


lexicon = Channel.fromPath(params.lexicon)
alphabet = Channel.fromPath(params.alphabet)

folia_ocr_documents = Channel.fromPath(params.inputdir+"/**.folia.xml")

process corpusfrequency {
    //Process corpus into frequency file for TICCL

    input:
    file "*.folia.xml" from foliaoutput
    val virtualenv from params.virtualenv
    val inputclass from params.inputclass

    output:
    file "corpus.wordfreqlist.tsv" into corpusfreqlist

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    FoLiA-stats --class "$inputclass" -s -t $threads -e folia.xml --lang=none --ngram 1 -o corpus .
    """
}

process ticclunk {
    //Filter a wordfrequency list

    input:
    file corpusfreqlist from corpusfreqlist //corpus frequency list in FoLiA-stats format
    file lexicon from lexicon
    val virtualenv from params.virtualenv
    val artifrq from params.artifrq

    output:
    file "${corpusfreqlist}.clean" into corpusfreqlist_clean //cleaned wordfrequency file
    file "${corpusfreqlist}.unk" into unknownfreqlist //unknown words list
    file "${corpusfreqlist}.punct" into punctuationmap //list of words mapping strings with leading/trailing punctuation to clean variants

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-unk --corpus ${lexicon} --artifrq ${artifrq} ${corpusfreqlist}
    """
}

process anahash {
    /*
        Read a clean wordfrequency list , and hash all items.
    */

    input:
    file corpusfreqlist from corpusfreqlist_clean
    file alphabet from alphabet
    val virtualenv from params.virtualenv

    output:
    file "anahash" into anahashfile

    script:

	"""
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-anahash --alph ${alphabet} --artifrq ${artifrq} ${corpusfreqlist}
    """
}

