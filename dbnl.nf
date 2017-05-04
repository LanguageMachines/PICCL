#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "DBNL Pipeline"
log.info "--------------------------"

def env = System.getenv()

println "BaseDir: " + baseDir

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.language = "nld"
params.extension = "xml"
params.outputdir = "dbnl_output"
params.skip = "mcpa"

if (params.containsKey('help') || !params.containsKey('inputdir')) {
    log.info "Usage:"
    log.info "  dbnl.nf [OPTIONS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory (TEI documents)"
    log.info""
    log.info "Optional parameters:"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --language LANGUAGE      Language"
    log.info "  --extension STR          Extension of TEI documents in input directory (default: xml)"
    log.info "  --skip=[mptncla]         Skip Tokenizer (t), Lemmatizer (l), Morphological Analyzer (a), Chunker (c), Multi-Word Units (m), Named Entity Recognition (n), or Parser (p)"
    log.info "  --virtualenv PATH        Path to Virtual Environment to load (usually path to LaMachine)"
    exit 2
}


teidocuments = Channel.fromPath(params.inputdir+"/**." + params.extension)

process teiAddIds {
    //Add ID attribute to TEI file

    input:
    file teidocument from teidocuments
    val baseDir from baseDir

    output:
    file "${teidocument.baseName}.ids.xml" into tei_id_documents

    script:
    """
    ${baseDir}/scripts/dbnl/teiAddIds.pl ${teidocument}
    """
}

process teiExtractText {
    //Extract text from TEI documents and convert to FoLiA

    input:
    file teidocument from tei_id_documents

    output:
    file teidocument.baseName + ".folia.xml" into foliadocuments

    script:
    """
    ${baseDir}/scripts/dbnl/teiExtractText.pl ${teidocument} > ${teidocument.baseName}.folia.xml
    """
}

process tokenize_ucto {
    //tokenize the text

    input:
    file inputdocument from foliadocuments
    val language from params.language
    val virtualenv from params.virtualenv

    output:
    file "${inputdocument.baseName}.tok.folia.xml" into foliadocuments_tokenized

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    ucto -L ${language} -X -F ${inputdocument} ${inputdocument.baseName}.tok.folia.xml
    """
}


process modernize {
    //translate the document to contemporary dutch for PoS tagging
    //adds an extra <t class="contemporary"> layer
    input:
    file foliadocument from foliadocuments_tokenized

    output:
    file "${foliadocument.baseName}.modernized.folia.xml" into foliadocuments_modernized

    script:
    """
    #TODO
    """
}

process frog_folia2folia {
    publishDir params.outputdir, mode: 'copy', overwrite: true

    input:
    file inputdocument from foliadocuments_modernized
    val skip from params.skip
    val virtualenv from params.virtualenv

    output:
    file "${inputdocument.baseName}.frog.folia.xml" into foliadocuments_frogged

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

    frog \$opts -X ${inputdocument.baseName}.frog.folia.xml --textclass contemporary -x ${inputdocument}
    """
    }

foliadocuments_frogged.subscribe { println it }
