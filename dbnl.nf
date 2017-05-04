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
    log.info "  --virtualenv PATH        Path to Virtual Environment to load (usually path to LaMachine)"
    exit 2
}


teidocuments = Channel.fromPath(params.inputdir+"/**." + params.extension)

process teiAddIds {
    input:
    file teidocument from teidocuments
    val baseDir from baseDir

    output:
    file teidocument + ".gz" into compressed_tei_id_documents

    script:
    """
    ${baseDir}/scripts/dbnl/teiAddIds.pl ${teidocument}
    """
}


compressed_tei_id_documents.subscribe { println it }
