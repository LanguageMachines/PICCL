#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "----------------------------------"
log.info "Tokenisation Pipeline using ucto"
log.info "----------------------------------"

def env = System.getenv()

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""

params.extension = "txt"
params.inputformat = "text"
params.outputdir = "tokenized_output"
params.sentenceperline = false
params.inputclass = "current"
params.outputclass = "current"

if (params.containsKey('help') || !params.containsKey('inputdir') || !params.containsKey('language')) {
    log.info "Usage:"
    log.info "  tokenize.nf"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Path to the corpus directory"
    log.info "  --language STR           The language to tokenise for (eng,nld,spa,por,ita,fra,deu,tur,rus,generic)"
    log.info ""
    log.info "Optional parameters:"
    log.info "  --extension EXTENSION    Extension of input documents (default: txt, suggestion: folia.xml)"
    log.info "  --inputformat STR        Set to 'text' or 'folia', automatically determined from extension if possible"
    log.info "  --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)"
    log.info "  --sentenceperline        Indicates that the input (plain text only) is already in a one sentence per line format, skips sentence detection (default: false)"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --inputclass CLASS       Set the FoLiA text class to use as input (default: current)"
    log.info "  --outputclass CLASS       Set the FoLiA text class to use as output (default: current)"
    exit 2
}

if ((params.extension.find('xml') != null)  || (params.extension.find('folia') != null)) {
    params.inputformat = "folia"
}

inputdocuments = Channel.fromPath(params.inputdir + "/**." + params.extension)

if (params.inputformat == "folia") {
    process tokenize_folia2folia {
        publishDir params.outputdir, mode: 'copy', overwrite: true

        input:
        file inputdocument from inputdocuments
        val language from params.language
        val inputclass from params.inputclass
        val outputclass from params.outputclass
        val virtualenv from params.virtualenv

        output:
        file "${inputdocument.baseName}.tok.folia.xml" into tokoutput

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        ID="${inputdocument.baseName}"
        ucto -L ${language} -X --id \$ID --inputclass ${inputclass} --outputclass ${outputclass} -F ${inputdocument} ${inputdocument.baseName}.tok.folia.xml
        """
    }
} else {
    //assume text
    process tokenize_text2folia {
        publishDir params.outputdir, mode: 'copy', overwrite: true

        input:
        file inputdocument from inputdocuments
        val language from params.language
        val sentenceperline from params.sentenceperline
        val virtualenv from params.virtualenv
        val outputclass from params.outputclass

        output:
        file "${inputdocument.baseName}.tok.folia.xml" into tokoutput

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        opts=""
        if [ ${sentenceperline} -eq 1 ]; then
            opts="\$opts -n"
        fi

        ID="${inputdocument.baseName}"
        ucto -L ${language} \$opts -X --id \$ID ${inputdocument} --outputclass ${outputclass} ${inputdocument.baseName}.tok.folia.xml
        """
    }
}

tokoutput.subscribe { println "Tokenizer output document written to " +  params.outputdir + "/" + it.name }
