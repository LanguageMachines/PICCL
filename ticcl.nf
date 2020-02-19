#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "TICCL Pipeline"
log.info "--------------------------"

def env = System.getenv()

//Set default parameter values
params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : "" //automatically detects whether we are running in a Virtual Environment (one of the LaMachine flavours)
params.language = "nld"
params.extension = "folia.xml"
params.inputtype = "folia"
params.outputdir = "ticcl_output"
params.inputclass = "current"
params.lexicon = ""
params.artifrq = 10000000
params.alphabet = ""
params.distance = 2
params.clip = 1
params.low = 5
params.high = 35

//Output usage information if --help is specified
if (params.containsKey('help')) {
    log.info "Usage:"
    log.info "  ticcl.nf [OPTIONS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory (FoLiA documents with an OCR text layer)"
    log.info "  --lexicon FILE           Path to lexicon file (*.dict)"
    log.info "  --alphabet FILE          Path to alphabet file (*.chars)"
    log.info "  --charconfus FILE        Path to character confusion list (*.confusion)"
    log.info ""
    log.info "Optional parameters:"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --language LANGUAGE      Language"
    log.info "  --extension STR          Extension of FoLiA documents in input directory (default: folia.xml, must always end in xml)!"
    log.info "  --inputclass CLASS       FoLiA text class to use for input, defaults to 'current' for FoLiA input; must be set to 'OCR' for FoLiA documents produced by ocr.nf"
    log.info "  --inputtype STR          Input type can be either 'folia' (default), 'text', or 'pdf' (i.e. pdf with text; no OCR)"
    log.info "  --virtualenv PATH        Path to Virtual Environment to load (usually path to LaMachine)"
    log.info "  --artifrq INT            Default value for missing frequencies in the validated lexicon (default: 10000000)"
    log.info "  --distance INT           Levenshtein/edit distance (default: 2)"
    log.info "  --clip INT               Limit the number of variants per word (default: 10)"
    log.info "  --corpusfreqlist FILE    Corpus frequency list (skips the first step that would compute one for you)"
    log.info "  --low INT                skip entries from the anagram file shorter than 'low' characters. (default = 5)"
    log.info "  --high INT               skip entries from the anagram file longer than 'high' characters. (default=35)"
    exit 2
}

//Check mandatory parameters and produce sensible error messages
if (!params.containsKey('inputdir')) {
    log.info "Error: Missing --inputdir parameter, see --help for usage details"
} else {
    def dircheck = new File(params.inputdir)
    if (!dircheck.exists()) {
        log.info "Error: Specified input directory does not exist"
        exit 2
    }
}
if (!params.containsKey('lexicon')) {
    log.info "Error: Missing --lexicon parameter, see --help for usage details"
    exit 2
}
if (!params.containsKey('alphabet')) {
    log.info "Error: Missing --alphabet parameter, see --help for usage details"
    exit 2
}
if (!params.containsKey('charconfus')) {
    log.info "Error: Missing --charconfus parameter, see --help for usage details"
    exit 2
}


//Initialise channels from various input files specified in parameters, these will be consumed as input by a process later on
lexicon = Channel.fromPath(params.lexicon).ifEmpty("Lexicon file not found")
alphabet = Channel.fromPath(params.alphabet).ifEmpty("Alphabet file not found")
charconfuslist = Channel.fromPath(params.charconfus).ifEmpty("Character confusion file not found")

inputclass = "OCR" //default internal inputclass (will be overriden with the default 'current' in case of FoLiA input)

if (params.inputtype == "folia") {
    //Create two identical channels (folia_ocr_document & input_overview) globbing all FoLiA documents in the input directory (recursively!)
    //the input_overview channel will be consumed immediately, simply printing all input filenames
    Channel.fromPath(params.inputdir+"/**." + params.extension).into { folia_ocr_documents; input_overview }
    input_overview.subscribe { println "TICCL FoLiA input: ${it.baseName}" }
    inputclass = params.inputclass //use user-supplied input class (default to 'current')
} else if (params.inputtype == "text") {
    //Create two identical channel globbing all text documents in the input directory (recursively!)
    Channel.fromPath(params.inputdir+"/**.txt").filter { it.baseName != "trace" }.into { textdocuments; input_overview }
    input_overview.subscribe { println "TICCL text input: ${it.baseName}" }
} else if (params.inputtype == "pdf") {
    //Create two identical channel globbing all PDF documents in the input directory (recursively!)
    pdfdocuments = Channel.fromPath(params.inputdir+"/**.pdf")
    Channel.fromPath(params.inputdir+"/**.pdf").into { pdfdocuments; input_overview }
    input_overview.subscribe { println "TICCL PDF input: ${it.baseName}" }
    inputclass = "OCR"

    process pdf2text {
        /*
            convert PDF to Text with pdftotext
        */

        input:
        file pdfdocument from pdfdocuments

        output:
        file "${pdfdocument.baseName}.txt" into textdocuments

        script:
        """
        #!/bin/bash
        pdftotext -nopgbrk -eol unix "$pdfdocument" "${pdfdocument.baseName}.txt"
        """
    }
} else {
    log.error "No such inputtype: " + params.inputtype
    exit 2
}

if ((params.inputtype == "text") || (params.inputtype == "pdf")) { //(pdf will have been converted to text by prior process)
    process txt2folia {
        /*
             Convert txt to FoLiA with FoLiA-txt
        */

        input:
        file textdocument from textdocuments
        val virtualenv from params.virtualenv

        output:
        file "${textdocument.baseName}.folia.xml" into folia_ocr_documents

        script:
        """
        #!/bin/bash
        #set up the virtualenv (bit unelegant currently, but we have to do this for each process to ensure the LaMachine environment works)
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        FoLiA-txt --class OCR -t 1 -O . "${textdocument}" || exit 1

        if [ ! -s "${textdocument.baseName}.folia.xml" ]; then
            echo "ERROR: Expected output ${textdocument.baseName}.folia.xml does not exist or is empty">&2
            exit 6
        fi
        """

    }
}

//fork the above output channel into two so it can be used as input by two processes  (a channel is consumed upon input)
folia_ocr_documents.into { folia_ocr_documents_forcorpusfrequency; folia_ocr_documents_forfoliacorrect }

if (params.containsKey('corpusfreqlist')) {
    //a corpus frequency is list explicitly provided as parameter, set up a channel
    corpusfreqlist = Channel.fromPath(params.corpusfreqlist)
} else {
    //no corpus frequency list is provided, so we compute one with FoLiA-stats

    process corpusfrequency {
        /*
            Process corpus into frequency file for TICCL (with FoLiA-stats)
        */

        publishDir params.outputdir, mode: 'copy', overwrite: true //publish the output for the end-user to see (rather than deleting this intermediate output)

        input:
        file "doc*." + params.extension from folia_ocr_documents_forcorpusfrequency
        val virtualenv from params.virtualenv
        val inputclass from inputclass
        val extension from params.extension
        val ngram from params.ngram

        output:
        file "corpus.wordfreqlist.tsv" into corpusfreqlist

        script:
        """
        #!/bin/bash
        #set up the virtualenv if necessary
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        FoLiA-stats --class "$inputclass" -s -t ${task.cpus} -e "$extension" --lang=none --collect --maxngram $ngram -o corpus . || exit 1

        if [ ! -s "corpus.wordfreqlist.tsv" ]; then
            echo "ERROR: Expected output corpus.wordfreqlist.tsv does not exist or is empty">&2
            exit 6
        fi
        """
    }
}

process ticclunk {
    /*
        Filter a wordfrequency list (TICCL-unk)
    */

    publishDir params.outputdir, mode: 'copy', overwrite: true //publish the output for the end-user to see (rather than deleting this intermediate output)

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
    #!/bin/bash
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-unk --background "${lexicon}" --artifrq ${artifrq} "${corpusfreqlist}" || exit 1

    if [ ! -s "${corpusfreqlist}.clean" ]; then
        echo "ERROR: Expected output ${corpusfreqlist}.clean does not exist or is empty">&2
        exit 6
    fi
    """
}

//fork the above output channel so it can be used as input for THREE processes
corpusfreqlist_clean.into { corpusfreqlist_clean_foranahash; corpusfreqlist_clean_forresolver; corpusfreqlist_clean_forindexer }

process anahash {
    /*
        Read a clean wordfrequency list , and hash all items with TICCL-anahash
    */

    publishDir params.outputdir, mode: 'copy', overwrite: true //publish the output for the end-user to see (rather than deleting this intermediate output)

    input:
    file corpusfreqlist from corpusfreqlist_clean_foranahash
    file alphabet from alphabet
    val virtualenv from params.virtualenv
    val artifrq from params.artifrq

    output:
    file "${corpusfreqlist}.anahash" into anahashlist
    file "${corpusfreqlist}.corpusfoci" into corpusfocilist

    script:

	"""
    #!/bin/bash
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-anahash --alph "${alphabet}" --artifrq ${artifrq} "${corpusfreqlist}" --ngrams || exit 1

    if [ ! -s "${corpusfreqlist}.anahash" ]; then
        echo "ERROR: Expected output ${corpusfreqlist}.anahash does not exist or is empty">&2
        exit 6
    fi

    if [ ! -s "${corpusfreqlist}.corpusfoci" ]; then
        echo "ERROR: Expected output ${corpusfreqlist}.corpusfoci does not exist or is empty">&2
        exit 6
    fi
    """
}


//fork channels so we can consume them from multiple processes
anahashlist.into { anahashlist_forindexer; anahashlist_forresolver }
charconfuslist.into { charconfuslist_forindexer; charconfuslist_forrank }

process indexer {
    /*
        Computes an index from anagram hashes (TICCL-indexerNT)
    */
    publishDir params.outputdir, mode: 'copy', overwrite: true

    input:
    file corpusfreqlist from corpusfreqlist_clean_forindexer //only used for naming purposes, not real input
    file anahashlist from anahashlist_forindexer
    file charconfuslist from charconfuslist_forindexer
    file corpusfocilist from corpusfocilist
    val virtualenv from params.virtualenv
    val low from params.low
    val high from params.high

    output:
    file "${corpusfreqlist}.indexNT" into index

    script:
    """
    #!/bin/bash
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-indexerNT --hash "${anahashlist}" --charconf "${charconfuslist}" --foci "${corpusfocilist}" -o "${corpusfreqlist}" -t ${task.cpus} --low ${low} --high ${high} || exit 1

    if [ ! -s "${corpusfreqlist}.indexNT" ]; then
        echo "ERROR: Expected output ${corpusfreqlist}.indexNT does not exist or is empty">&2
        exit 6
    fi
    """
    //NOTE: -o option is a prefix only, extension indexNT will be appended !!
}

//set up a new channel for the alphabet file for the resolved (the other one is consumed already)
alphabet_forresolver = Channel.fromPath(params.alphabet).ifEmpty("Alphabet file not found")

process resolver {
    //Resolves numerical confusions back to word form confusions using TICCL-LDcalc
    publishDir params.outputdir, mode: 'copy', overwrite: true //publish the output for the end-user to see (rather than deleting this intermediate output)


    input:
    file index from index
    file anahashlist from anahashlist_forresolver
    file corpusfreqlist from corpusfreqlist_clean_forresolver
    file alphabet from alphabet_forresolver
    val distance from params.distance
    val artifrq from params.artifrq
    val virtualenv from params.virtualenv
    val low from params.low
    val high from params.high

    output:
    file "${corpusfreqlist}.ldcalc" into wordconfusionlist

    script:
    """
    #!/bin/bash
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

	TICCL-LDcalc --index "${index}" --hash "${anahashlist}" --clean "${corpusfreqlist}" --LD ${distance} --artifrq ${artifrq} -o "${corpusfreqlist}.ldcalc" -t ${task.cpus} --alph ${alphabet} --low ${low} --high ${high} || exit 1

    if [ ! -s "${corpusfreqlist}.ldcalc" ]; then
        echo "ERROR: Expected output ${corpusfreqlist}.ldcalc does not exist or is empty">&2
        exit 6
    fi
    """
}

alphabet_forrank = Channel.fromPath(params.alphabet)

process rank {
    /*
        Rank output using TICCL-rank
    */

    publishDir params.outputdir, mode: 'copy', overwrite: true //publish the output for the end-user to see (rather than deleting this intermediate output)


    input:
    file wordconfusionlist from wordconfusionlist
    file alphabet from alphabet_forrank
    file charconfuslist from charconfuslist_forrank
    val distance from params.distance
    val artifrq from params.artifrq
    val clip from params.clip
    val virtualenv from params.virtualenv

    output:
    file "${wordconfusionlist}.ranked" into rankedlist

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-rank --alph "${alphabet}" --charconf "${charconfuslist}" -o "${wordconfusionlist}.ranked" "${wordconfusionlist}.debug.ranked" --subtractartifrqfeature2 0  0 --clip ${clip} --skipcols=1,10,11,13 -t ${task.cpus} "${wordconfusionlist}" || exit 1

    if [ ! -s "${wordconfusionlist}.ranked" ]; then
        echo "ERROR: Expected output ${wordconfusionlist}.ranked does not exist or is empty">&2
        exit 6
    fi
    """
}

alphabet_forchain = Channel.fromPath(params.alphabet)

process chainer {
    /*
        Chain stuff? (@martinreynaert: update description to be more sensible?)
    */

    input:
    file rankedlist from rankedlist
    file alphabet from alphabet_forchain
    val virtualenv from params.virtualenv
    val clip from params.clip

    output:
    file "${rankedlist}.chained.ranked" into rankedlist_chained

    script:
    """
    #!/bin/bash
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-chain --caseless ${rankedlist} --alph ${alphabet} || exit 1
    mv ${rankedlist}.chained ${rankedlist}.chained.ranked || exit 2 #FoLiA-correct requires extension to be *.ranked so we add it

    if [ ! -s "${rankedlist}.chained.ranked" ]; then
        echo "ERROR: Expected output ${rankedlist}.chained.ranked does not exist or is empty">&2
        exit 6
    fi
    """
}

process foliacorrect {
    /*
        Correct the input documents using the ranked list, produces final output documents with <str>, using FoLiA-correct
    */

    publishDir params.outputdir, mode: 'copy', overwrite: true //publish the output for the end-user to see (this is the final output)

    input:
    file folia_ocr_documents from folia_ocr_documents_forfoliacorrect.collect() //collects all files first
    file rankedlist from rankedlist_chained
    file punctuationmap from punctuationmap
    file unknownfreqlist from unknownfreqlist
    val extension from params.extension
    val inputclass from inputclass
    val virtualenv from params.virtualenv

    output:
    file "*.ticcl.folia.xml" into folia_ticcl_documents

    script:
    """
    #!/bin/bash
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    #some bookkeeping
    mkdir outputdir


    FoLiA-correct --inputclass "${inputclass}" --outputclass current --nums 10 -e ${extension} -O outputdir/ --unk "${unknownfreqlist}" --punct "${punctuationmap}" --rank "${rankedlist}"  -t ${task.cpus} . || exit 1

    cd outputdir
    ls

    #rename files so they have *.ticcl.folia.xml as extension (rather than .ticcl.xml which FoLiA-correct produces)
    for f in *.xml; do
        if [[ \$f != "*.xml" ]]; then
            if [[ \${f%.ticcl.xml} != \$f ]]; then
                newf="\${f%.ticcl.xml}.ticcl.folia.xml"
            else
                newf="\$f"
            fi
            mv \$f ../\$newf
        fi
    done
    cd ..
    """
}

//explicitly report the final documents created to stdout
folia_ticcl_documents.subscribe { println "TICCL output document written to " +  params.outputdir + "/" + it.name }
