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

try {
    if (!nextflow.version.matches('>= 0.25')) { //ironically available since Nextflow 0.25 only
        log.error "Requires Nextflow >= 0.25, your version is too old"
        exit 2
    }
} catch(ex) {
    log.error "Requires Nextflow >= 0.25, your version is too old"
    exit 2
}

def getbasename(File file) {
    file.name.split("\\.", 2)[0]
}

teidocuments = Channel.fromPath(params.inputdir+"/**." + params.extension)
dictionary = Channel.fromPath(params.dictionary)
preservationlexicon = Channel.fromPath(params.preservation)
rulefile = Channel.fromPath(params.rules)
oztfile = Channel.fromPath(params.oztids)

process teiAddIds {
    //Add ID attribute to TEI file

    input:
    each file(teidocument) from teidocuments
    val baseDir from baseDir
    file(oztfile) from oztfile

    output:
    file "${teidocument.baseName}.ids.xml" into tei_id_documents

    script:
    """
    ${baseDir}/scripts/dbnl/teiAddIds.pl ${teidocument} ${oztfile}
    """
}

process tei2folia {
    //Extract text from TEI documents and convert to FoLiA

    input:
    file teidocument from tei_id_documents

    output:
    file "${teidocument.getBaseName(2)}.folia.xml" into foliadocuments

    script:
    """
    ${baseDir}/scripts/dbnl/teiExtractText.pl ${teidocument} > tmp.xml

    #Delete any empty paragraphs (invalid FoLiA)
    ${baseDir}/scripts/dbnl/frogDeleteEmptyPs.pl tmp.xml > tmp2.xml

    #the generated FoLiA may not be valid due to multiple heads in a single section, eriktks post-corrected this with the following script:
    ${baseDir}/scripts/dbnl/frogHideHeads.pl tmp2.xml NODECODE > ${teidocument.getBaseName(2)}.folia.xml

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

//foliadocuments_tokenized.subscribe { println it }

//split the tokenized documents into batches of 1000 each, fork into two channels
foliadocuments_tokenized
    .buffer( size: 1000, remainder: true)
    .collect()
    .into { foliadocuments_batches_tokenized1; foliadocuments_batches_tokenized2 }

    //.map { file -> tuple(file.getBaseName(3), file }  // I tried this before buffer but don't know how to handle it as desired input/output

process frog_original {
    //Linguistic enrichment on the original text of the document (pre-modernization)

    //Receives multiple input files in batches

    input:
    file "*.tok.folia.xml" from foliadocuments_batches_tokenized1
    val skip from params.skip
    val virtualenv from params.virtualenv

    output:
    file "*.frogoriginal.folia.xml" into foliadocuments_frogged_original mode flatten

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

    #move input files to separate staging directory
    mkdir input
    mv *.folia.xml input/

    #output will be in cwd
    frog \$opts --xmldir "." --threads ${task.cpus} --testdir input/ -x

    #set proper output extension (output files would otherwise have same name as input files and confuse nextflow)
    mmv "*.tok.folia.xml" "#1.frogoriginal.folia.xml"
    """
}

foliadocuments_frogged_original.subscribe { println "DBNL debug pipeline output document: " + it.name }

/*
process modernize_and_frog {
    //translate the document to contemporary dutch for PoS tagging AND run Frog on it
    //adds an extra <t class="contemporary"> layer

    input:
    file "*.tok.folia.xml" from foliadocuments_batches_tokenized2
    val skip from params.skip
    val virtualenv from params.virtualenv

    file dictionary from dictionary
    file preservationlexicon from preservationlexicon
    file rulefile from rulefile
    val virtualenv from params.virtualenv

    output:
    file "*.frogmodernized.folia.xml" into foliadocuments_frogged_modernized mode flatten

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

    mkdir modernization_work
    mv *.folia.xml modernization_work

    FoLiA-wordtranslate --outputclass contemporary -t ${task.cpus} -d ${dictionary} -p ${preservationlexicon} -r ${rulefile} modernization_work/

    mkdir froginput
    mv *.translated.folia.xml froginput/

    #output will be in cwd
    frog \$opts -x --xmldir "." --threads=${task.cpus} --textclass contemporary --testdir froginput/

    #set proper output extension
    mmv "*.tok.translated.folia.xml" "#1.frogmodernized.folia.xml"
    """
}


// transform [file] -> [(basename, file)]
foliadocuments_frogged_original
    .map { file -> [file.getBaseName(3), file] }
    .into { foliadocuments_frogged_original2 }

// transform [file] -> [(basename, file)]
foliadocuments_frogged_modernized
    .map { file -> [file.getBaseName(3), file] }
    .into { foliadocuments_frogged_modernized2 }

//now combine the two channels on basename: [ (basename, modernizedfile, originalfile) ]
foliadocuments_frogged_modernized2
    .combine(foliadocuments_frogged_original2, by: 0) //0 refers to first input tuple element (basename)
    .into { foliadocuments_pairs }

process merge {
    //merge the modernized annotations with the original ones, the original ones will be included as alternatives
    publishDir params.outputdir, mode: 'copy', overwrite: true

    input:
    set val(basename), file(modernfile), file(originalfile) from foliadocuments_pairs
    val skip from params.skip
    val virtualenv from params.virtualenv

    output:
    file "${basename}.folia.xml" into foliadocuments_merged

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    foliamerge -a ${modernfile} ${originalfile} > ${basename}.folia.xml
    """
}

foliadocuments_merged.subscribe { println "DBNL pipeline output document written to " +  params.outputdir + "/" + it.name }
*/
