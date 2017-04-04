#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "----------------------------------"
log.info "Frog pipeline"
log.info "----------------------------------"

def env = System.getenv()

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""

params.extension = "txt"
params.inputformat = "text"
params.outputdir = "frog_output"
params.sentenceperline = false
params.inputclass = "current"
params.skip = ""

if (params.containsKey('help') || !params.containsKey('inputdir')) {
    log.info "Usage:"
    log.info "  frog.nf"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Path to the corpus directory"
    log.info ""
    log.info "Optional parameters:"
    log.info "  --extension EXTENSION    Extension of input documents (default: txt, suggestion: folia.xml)"
    log.info "  --inputformat STR        Set to 'text' or 'folia', automatically determined from extension if possible"
    log.info "  --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)"
    log.info "  --sentenceperline        Indicates that the input (plain text only) is already in a one sentence per line format, skips sentence detection (default: false)"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --inputclass CLASS       Set the FoLiA text class to use as input (default: current)"
    log.info "  --skip=[mptncla]         Skip Tokenizer (t), Lemmatizer (l), Morphological Analyzer (a), Chunker (c), Multi-Word Units (m), Named Entity Recognition (n), or Parser (p)"
    exit 2
}

if ((params.extension.find('xml') != null)  || (params.extension.find('folia') != null)) {
    params.inputformat = "folia"
}

inputdocuments = Channel.fromPath(params.inputdir + "/**." + params.extension)

if (params.inputformat == "folia") {
    process frog_folia2folia {
        publishDir params.outputdir, mode: 'copy', overwrite: true

        input:
        file inputdocument from inputdocuments
		val skip from params.skip
		val inputclass from params.inputclass
        val virtualenv from params.virtualenv

        output:
        file "${inputdocument.baseName}.frog.folia.xml" into tokoutput

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        opts=""
        if [ \$sentenceperline -eq 1 ]; then
            opts="\$opts -n"
        fi
        if [ ! -z "$skip" ]; then
			skip="--skip=${skip}"
		fi

        frog \$opts -X ${inputdocument.baseName}.frog.folia.xml --textclass ${inputclass} --id ${inputdocument.baseName} -x ${inputdocument}
        """
    }
} else {
    //assume text
    process frog_text2folia {
        publishDir params.outputdir, mode: 'copy', overwrite: true

        input:
        file inputdocument from inputdocuments
        val sentenceperline from params.sentenceperline
		val skip from params.skip
        val virtualenv from params.virtualenv

        output:
        file "${inputdocument.baseName}.frog.folia.xml" into tokoutput

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        opts=""
        if [ $sentenceperline -eq 1 ]; then
            opts="\$opts -n"
        fi
        if [ ! -z "$skip" ]; then
			skip="--skip=${skip}"
		fi

        frog \$opts -X ${inputdocument.baseName}.frog.folia.xml --id ${inputdocument.baseName} -t ${inputdocument}
        """
    }
}

tokoutput.subscribe { println "Tokenizer output document written to " +  params.outputdir + "/" + it.name }
