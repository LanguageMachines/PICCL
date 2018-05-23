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
params.outputclass = "current"
params.workers = 1
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
    log.info "  --ouputclass CLASS       Set the FoLiA text class to use as input (default: current)"
    log.info "  --skip=[mptncla]         Skip Tokenizer (t), Lemmatizer (l), Morphological Analyzer (a), Chunker (c), Multi-Word Units (m), Named Entity Recognition (n), or Parser (p)"
    log.info "  --workers NUMBER         The number of workers (Frogs in parallel)"
    exit 2
}

if ((params.extension.find('xml') != null)  || (params.extension.find('folia') != null)) {
    params.inputformat = "folia"
}

inputdocuments = Channel.fromPath(params.inputdir + "/**." + params.extension)
inputdocuments_counter = Channel.fromPath(params.inputdir + "/**." + params.extension)

if (params.inputformat == "folia") {
    //group documents into n (=$worker) batches
    foliainput_batched = Channel.create()
    inputdocuments
        .buffer( size: Math.ceil(inputdocuments_counter.count().val / params.workers).toInteger(), remainder: true)
        .into(foliainput_batched)

    process frog_folia2folia {
        publishDir params.outputdir, pattern: "*.xml", mode: 'copy', overwrite: true

        cpus params.workers

        input:
        file foliadocuments from foliainput_batched
		val skip from params.skip
		val inputclass from params.inputclass
		val outputclass from params.outputclass
        val virtualenv from params.virtualenv

        output:
        file "output/*.xml" into foliadocuments_output mode flatten

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        opts=""
        if [ ! -z "$skip" ]; then
			opts="--skip=${skip}"
		fi

        #move input files to separate staging directory
        mkdir input
        mv *.xml input/

        #output will be in output/
        mkdir output
        frog \$opts --inputclass "${inputclass}" --outputclass "${outputclass}" --xmldir "output" --threads 1 --nostdout --testdir input/ -x
        """
    }

} else {
    //group documents into n (=$worker) batches
    textinput_batched = Channel.create()
    inputdocuments
        .buffer( size: Math.ceil(inputdocuments_counter.count().val / params.workers).toInteger(), remainder: true)
        .into(textinput_batched)

    process frog_text2folia {
        publishDir params.outputdir, pattern: "*.xml", mode: 'copy', overwrite: true

        cpus params.workers

        input:
        file foliadocuments from textinput_batched
		val skip from params.skip
		val outputclass from params.outputclass
        val extension from params.extension
        val sentenceperline from params.sentenceperline
        val virtualenv from params.virtualenv

        output:
        file "output/*.xml" into foliadocuments_output mode flatten

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        opts=""
        if [[ "$sentenceperline" == "true" ]]; then
            opts="\$opts -n"
        fi
        if [ ! -z "$skip" ]; then
			opts="\$opts --skip=${skip}"
		fi

        #move input files to separate staging directory
        mkdir input
        mv *.$extension input/

        #output will be in cwd
        mkdir output
        frog \$opts --outputclass "${outputclass}" --xmldir "output" --threads 1 --nostdout --testdir input/
        """
    }

}

foliadocuments_output.subscribe { println "Frog output document written to " +  params.outputdir + "/" + it.name }
