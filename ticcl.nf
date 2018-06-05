#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "TICCL Pipeline"
log.info "--------------------------"

def env = System.getenv()

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.language = "nld"
params.extension = "folia.xml"
params.inputtype = "folia"
params.outputdir = "ticcl_output"
params.inputclass = "OCR"
params.lexicon = ""
params.artifrq = 10000000
params.alphabet = ""
params.distance = 2
params.clip = 1

if (params.containsKey('help') || !params.containsKey('inputdir') || !params.containsKey('lexicon') || !params.containsKey('alphabet') || !params.containsKey('charconfus')) {
    log.info "Usage:"
    log.info "  ticcl.nf [OPTIONS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory (FoLiA documents with an OCR text layer)"
    log.info "  --lexicon FILE           Path to lexicon file (*.dict)"
    log.info "  --alphabet FILE          Path to alphabet file (*.chars)"
    log.info "  --charconfus FILE        Path to character confusion list (*.confusion)"
    log.info""
    log.info "Optional parameters:"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --language LANGUAGE      Language"
    log.info "  --extension STR          Extension of FoLiA documents in input directory (default: folia.xml, must always end in xml)!"
    log.info "  --inputclass CLASS       FoLiA text class to use for input, defaults to 'OCR', may be set to 'current' as well"
    log.info "  --inputtype STR          Input type can be either 'folia' (default), 'text', or 'pdf' (i.e. pdf with text; no OCR)"
    log.info "  --virtualenv PATH        Path to Virtual Environment to load (usually path to LaMachine)"
    log.info "  --artifrq INT            Default value for missing frequencies in the validated lexicon (default: 10000000)"
    log.info "  --distance INT           Levenshtein/edit distance (default: 2)"
    log.info "  --clip INT               Limit the number of variants per word (default: 10)"
    log.info "  --corpusfreqlist FILE    Corpus frequency list (skips the first step that would compute one for you)"
    exit 2
}


lexicon = Channel.fromPath(params.lexicon).ifEmpty("Lexicon file not found")
alphabet = Channel.fromPath(params.alphabet).ifEmpty("Alphabet file not found")

charconfuslist = Channel.fromPath(params.charconfus).ifEmpty("Character confusion file not found")


if (params.inputtype == "folia") {
    folia_ocr_documents = Channel.fromPath(params.inputdir+"/**." + params.extension)
} else if (params.inputtype == "text") {
    textdocuments = Channel.fromPath(params.inputdir+"/**.txt")
} else if (params.inputtype == "pdf") {
    pdfdocuments = Channel.fromPath(params.inputdir+"/**.pdf")

    process pdf2text {
        //convert PDF to Text
        input:
        file pdfdocument from pdfdocuments

        output:
        file "${pdfdocument.baseName}.txt" into textdocuments

        script:
        """
        pdftotext -nopgbrk -eol unix "$pdfdocument" "${pdfdocument.baseName}.txt"
        """
    }
} else {
    log.error "No such inputtype: " + params.inputtype
    exit 2
}

if ((params.inputtype == "text") || (params.inputtype == "pdf")) {
    process txt2folia {
        //Convert txt to FoLiA
        input:
        file textdocument from textdocuments
        val virtualenv from params.virtualenv

        output:
        file "${textdocument.baseName}.folia.xml" into folia_ocr_documents

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        FoLiA-txt --class OCR -t 1 -O . "${textdocument}"
        """

    }
}

folia_ocr_documents.into { folia_ocr_documents_forcorpusfrequency; folia_ocr_documents_forfoliacorrect }

if (params.containsKey('corpusfreqlist')) {
    //corpus frequency list explicitly provided
    corpusfreqlist = Channel.fromPath(params.corpusfreqlist)
} else {
    process corpusfrequency {
        publishDir params.outputdir, mode: 'copy', overwrite: true

        //Process corpus into frequency file for TICCL
        input:
        file "doc*." + params.extension from folia_ocr_documents_forcorpusfrequency
        val virtualenv from params.virtualenv
        val inputclass from params.inputclass
        val extension from params.extension

        output:
        file "corpus.wordfreqlist.tsv" into corpusfreqlist

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        FoLiA-stats --class "$inputclass" -s -t ${task.cpus} -e "$extension" --lang=none --ngram 1 -o corpus .
        """
    }
}

process ticclunk {
    //Filter a wordfrequency list
    publishDir params.outputdir, mode: 'copy', overwrite: true

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

    TICCL-unk --background "${lexicon}" --artifrq ${artifrq} "${corpusfreqlist}"
    """
}

//split channel
corpusfreqlist_clean.into { corpusfreqlist_clean_foranahash; corpusfreqlist_clean_forresolver; corpusfreqlist_clean_forindexer }

process anahash {
    /*
        Read a clean wordfrequency list , and hash all items.
    */
    publishDir params.outputdir, mode: 'copy', overwrite: true

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
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-anahash --alph "${alphabet}" --artifrq ${artifrq} "${corpusfreqlist}"
    """
}


//split channels
anahashlist.into { anahashlist_forindexer; anahashlist_forresolver }
charconfuslist.into { charconfuslist_forindexer; charconfuslist_forrank }

process indexer {
    //Computes an index from anagram hashes to
    publishDir params.outputdir, mode: 'copy', overwrite: true

    input:
    file corpusfreqlist from corpusfreqlist_clean_forindexer //only used for naming purposes, not real input
    file anahashlist from anahashlist_forindexer
    file charconfuslist from charconfuslist_forindexer
    file corpusfocilist from corpusfocilist
    val virtualenv from params.virtualenv

    output:
    file "${corpusfreqlist}.indexNT" into index

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    TICCL-indexerNT --hash "${anahashlist}" --charconf "${charconfuslist}" --foci "${corpusfocilist}" -o "${corpusfreqlist}" -t ${task.cpus}
    """
    // -o option is a prefix only, extension indexNT will be appended
}

alphabet_forresolver = Channel.fromPath(params.alphabet).ifEmpty("Alphabet file not found")

process resolver {
    //Resolves numerical confusions back to word form confusions using TICCL-LDcalc
    publishDir params.outputdir, mode: 'copy', overwrite: true

    input:
    file index from index
    file anahashlist from anahashlist_forresolver
    file corpusfreqlist from corpusfreqlist_clean_forresolver
    file alphabet from alphabet_forresolver
    val distance from params.distance
    val artifrq from params.artifrq
    val virtualenv from params.virtualenv

    output:
    file "${corpusfreqlist}.ldcalc" into wordconfusionlist

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

	TICCL-LDcalc --index "${index}" --hash "${anahashlist}" --clean "${corpusfreqlist}" --LD ${distance} --artifrq ${artifrq} -o "${corpusfreqlist}.ldcalc" -t ${task.cpus} --alph ${alphabet}
    """
}

alphabet_forrank = Channel.fromPath(params.alphabet)

process rank {
    //Rank output
    publishDir params.outputdir, mode: 'copy', overwrite: true

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

    TICCL-rank --alph "${alphabet}" --charconf "${charconfuslist}" -o "${wordconfusionlist}.ranked" --debugfile "${wordconfusionlist}.debug.ranked" --artifrq ${artifrq} --clip ${clip} --skipcols=10,11  -t ${task.cpus} "${wordconfusionlist}"
    """
}

process chainer {
    input:
    file rankedlist from rankedlist
    val virtualenv from params.virtualenv
    val clip from params.clip

    output:
    file "${rankedlist}.chained.ranked" into rankedlist_chained

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    if [ $clip -eq 1 ]; then
        TICCL-chain --caseless ${rankedlist}
        mv ${rankedlist}.chained ${rankedlist}.chained.ranked #FoLiA-correct requires extension to be *.ranked so we add it
    else
        #we can only chain with clip 1, just copy the file unmodified if clip>1
        echo "(skipping TICCL-chain because clip==$clip)">&2
        ln -s ${rankedlist} ${rankedlist}.chained.ranked
    fi
    """
}

process foliacorrect {
    //Correct the input documents using the ranked list, produces final output documents with <str>

    publishDir params.outputdir, mode: 'copy', overwrite: true


    input:
    file folia_ocr_documents from folia_ocr_documents_forfoliacorrect.collect()
    file rankedlist from rankedlist_chained
    file punctuationmap from punctuationmap
    file unknownfreqlist from unknownfreqlist
    val extension from params.extension
    val inputclass from params.inputclass
    val virtualenv from params.virtualenv

    output:
    file "*.ticcl.folia.xml" into folia_ticcl_documents

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    #some bookkeeping
    mkdir outputdir

    FoLiA-correct --inputclass "${inputclass}" --outputclass current --nums 10 -e ${extension} -O outputdir/ --unk "${unknownfreqlist}" --punct "${punctuationmap}" --rank "${rankedlist}"  -t ${task.cpus} .
    cd outputdir
    for f in *.xml; do
        if [[ \${f%.ticcl.xml} != \$f ]]; then
            newf="\${f%.ticcl.xml}.ticcl.folia.xml"
        else
            newf="\$f"
        fi
        mv \$f ../\$newf
    done
    cd ..
    """
}

folia_ticcl_documents.subscribe { println "TICCL output document written to " +  params.outputdir + "/" + it.name }

