#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "DBNL Pipeline"
log.info "--------------------------"

def env = System.getenv()

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.language = "nld"
params.extension = "xml"
params.outputdir = "dbnl_output"
params.skip = "mcpa"
params.oztids = "data/dbnl_ozt_ids.txt"
params.preservation = "/dev/null"
params.rules = "/dev/null"

if (params.containsKey('help') || !params.containsKey('inputdir') || !params.containsKey('dictionary')) {
    log.info "Usage:"
    log.info "  dbnl.nf [OPTIONS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory (TEI documents)"
    log.info "  --dictionary FILE        Modernisation dictionary"
    log.info""
    log.info "Optional parameters:"
    log.info "  --preservation FILE      Preservation lexicon (list of words that will not be processed by the rules)"
    log.info "  --rules FILE             Substitution rules"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --language LANGUAGE      Language"
    log.info "  --oztids FILE            List of IDs for DBNL onzelfstandige titels (default: data/dbnl_ozt_ids.txt)"
    log.info "  --extension STR          Extension of TEI documents in input directory (default: xml)"
    log.info "  --skip=[mptncla]         Skip Tokenizer (t), Lemmatizer (l), Morphological Analyzer (a), Chunker (c), Multi-Word Units (m), Named Entity Recognition (n), or Parser (p)"
    log.info "  --virtualenv PATH        Path to Virtual Environment to load (usually path to LaMachine)"
    exit 2
}


def getbasename(File file) {
    file.name.split("\\.", 2)[0]
}

teidocuments = Channel.fromPath(params.inputdir+"/**." + params.extension)
dictionary = Channel.fromPath(params.dictionary)
oztfile = Channel.fromPath(params.oztids)

process teiAddIds {
    //Add ID attribute to TEI file

    input:
    file teidocument from teidocuments
    val baseDir from baseDir
    file oztfile from oztfile

    output:
    file "${teidocument.baseName}.ids.xml" into tei_id_documents

    script:
    """
    ${baseDir}/scripts/dbnl/teiAddIds.pl ${teidocument} ${oztfile}
    """
}

process teiExtractText {
    //Extract text from TEI documents and convert to FoLiA

    input:
    file teidocument from tei_id_documents

    output:
    file "${teidocument.getBaseName(2)}.folia.xml" into foliadocuments

    script:
    """
    ${baseDir}/scripts/dbnl/teiExtractText.pl ${teidocument} > ${teidocument.getBaseName(2)}.folia.xml
    """
}

process tokenize_ucto {
    //tokenize the text

    input:
    file inputdocument from foliadocuments
    val language from params.language
    val virtualenv from params.virtualenv

    output:
    file "${inputdocument.getBaseName(2)}.tok.folia.xml" into foliadocuments_tokenized

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    ucto -L ${language} -X -F ${inputdocument} ${inputdocument.getBaseName(2)}.tok.folia.xml
    """
}


//TODO: runs one a per-document basis now: transform to multithreaded
process modernize {
    //translate the document to contemporary dutch for PoS tagging
    //adds an extra <t class="contemporary"> layer

    input:
    file foliadocument from foliadocuments_tokenized
    file dictionary from dictionary
    file preservation from preservation
    file rules from rules
    val virtualenv from params.virtualenv

    output:
    file "${foliadocument.getBaseName(2)}.translated.folia.xml" into foliadocuments_modernized

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    FoLiA-wordtranslate --outputclass contemporary -d ${dictionary} -p ${preservation} -r ${rules} ${foliadocument}
    """
}

process frog_folia2folia {
    publishDir params.outputdir, mode: 'copy', overwrite: true

    input:
    file inputdocument from foliadocuments_modernized
    val skip from params.skip
    val virtualenv from params.virtualenv

    output:
    file "${inputdocument.getBaseName(3)}.frog.folia.xml" into foliadocuments_frogged

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    opts=""
    if [ ! -z "$skip" ]; then
        skip="--skip=${skip}"
    fi

    frog \$opts -X ${inputdocument.getBaseName(3)}.frog.folia.xml --textclass contemporary -x ${inputdocument}
    """
    }

foliadocuments_frogged.subscribe { println "DBNL pipeline output document written to " +  params.outputdir + "/" + it.name }
