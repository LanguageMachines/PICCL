#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "-------------------------------------------"
log.info "Nederlab Linguistic Enrichment Pipeline"
log.info "-------------------------------------------"
log.info " (no OCR/normalisation/TICCL!)"

def env = System.getenv()

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.language = "nld-historical"
params.extension = "xml"
params.outputdir = "nederlab_output"
params.skip = "mcpa"
params.oztids = "data/dbnl_ozt_ids.txt"
params.preservation = "/dev/null"
params.rules = "/dev/null"
params.wikiente = false
params.spotlight = "http://127.0.0.1:2222/rest/"
params.metadatadir = ""
params.mode = "simple"
params.dolangid = false
params.uselangid = false
params.tei = false
params.tok = false
params.workers = Runtime.runtime.availableProcessors()
params.frogconfig = ""
params.recursive = false


if (params.containsKey('help') || !params.containsKey('inputdir') ) {
    log.info "Usage:"
    log.info "  nederlab.nf [OPTIONS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory (FoLiA documents or TEI documents if --tei is set)"
    log.info ""
    log.info "Optional parameters:"
    log.info "  --mode [modernize|simple|both|convert]  Add modernisation layer, process original content immediately (simple), do both? Or convert to FoLiA only (used with --tei)? Default: simple"
    log.info "  --dictionary FILE        Modernisation dictionary (required for modernize mode)"
    log.info "  --inthistlexicon FILE    INT Historical Lexicon dump file (required for modernize mode)"
    log.info "  --workers NUMBER         The number of workers (e.g. frogs) to run in parallel; input will be divided into this many batches"
    log.info "  --tei                    Input TEI XML instead of FoLiA (adds a conversion step), this https://www.tei-c.org/release/doc/tei-p5-doc/en/html/ref-encodingc.html"
    log.info "  --tok                    FoLiA Input is not tokenised yet, do so (adds a tokenisation step)"
    log.info "  --recursive              Process input directory recursively (make sure it's not also your current working directory or weird recursion may ensue)"
    log.info "  --inthistlexicon FILE    INT historical lexicon"
    log.info "  --preservation FILE      Preservation lexicon (list of words that will not be processed by the rules)"
    log.info "  --rules FILE             Substitution rules"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --metadatadir DIRECTORY  Directory including JSON metadata (one file matching each input document), needs to be an absolute path"
    log.info "  --language LANGUAGE      Language"
    log.info "  --frogconfig FILE        Path to frog.cfg (or using the default if not set)"
    log.info "  --oztids FILE            List of IDs for DBNL onzelfstandige titels (default: data/dbnl_ozt_ids.txt)"
    log.info "  --extension STR          Extension of TEI documents in input directory (default: xml)"
    log.info "  --skip=[mptncla]         Skip Tokenizer (t), Lemmatizer (l), Morphological Analyzer (a), Chunker (c), Multi-Word Units (m), Named Entity Recognition (n), or Parser (p)"
    log.info "  --dolangid               Do language identification"
    log.info "  --uselangid              Take language identification into account (does not perform identification but takes already present identification into account!)"
    log.info "  --wikiente               Run WikiEnte for Name Entity Recognition and entity linking"
    log.info "  --spotlight URL          URL to spotlight server (should end in rest/, defaults to http://127.0.0.1:2222/rest"
    log.info "  --virtualenv PATH        Path to Virtual Environment to load (usually path to LaMachine, autodetected if enabled)"
    exit 2
}

if (params.mode == "modernize" && (!params.containsKey('dictionary') || !params.containsKey('inthistlexicon'))) {
    log.error "Modernisation mode requires --dictionary and --inthislexicon"
    exit 2
}

if (params.recursive) {
    inputpattern = "**"
} else {
    inputpattern = "*"
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

inputdocuments_counter = Channel.fromPath(params.inputdir+"/" + inputpattern + "." + params.extension)

if (params.tei) {
    teidocuments = Channel.fromPath(params.inputdir+"/" + inputpattern + "." + params.extension)

    oztfile = Channel.fromPath(params.oztids)

    process tei2folia {
        //Extract text from TEI documents and convert to FoLiA

        if (params.mode == "convert" && params.metadatadir == "") {
            publishDir params.outputdir, mode: 'copy', overwrite: true
        }

        input:
        file teidocument from teidocuments
        val virtualenv from params.virtualenv

        output:
        file "${teidocument.simpleName}.folia.xml" into foliadocuments

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        tei2folia --traceback --dtddir /tmp "${teidocument}"
        """
    }

    if (params.metadatadir != "") {
        process addmetadata {
            if (params.mode == "convert" && params.metadatadir != "") {
                publishDir params.outputdir, mode: 'copy', overwrite: true
            }

            input:
            each file(inputdocument) from foliadocuments
            val virtualenv from params.virtualenv
            val metadatadir from params.metadatadir
            file oztfile

            output:
            file "${inputdocument.simpleName}.withmetadata.folia.xml" into foliadocuments_untokenized

            script:
            """
            set +u
            if [ ! -z "${virtualenv}" ]; then
                source ${virtualenv}/bin/activate
            fi
            set -u

            python ${LM_PREFIX}/opt/PICCL/scripts/dbnl/addmetadata.py --oztfile ${oztfile} -d ${metadatadir} -o ${inputdocument.simpleName}.withmetadata.folia.xml ${inputdocument}
            """
        }
    } else {
        foliadocuments.set { foliadocuments_untokenized }
    }

    if (params.mode == "convert") {
        // we only did conversion so we're all done
        foliadocuments_untokenized.subscribe { println it }
        return
    }

    //foliadocuments_tokenized.subscribe { println it }
} else {
    foliadocuments_untokenized = Channel.fromPath(params.inputdir+"/" + inputpattern + ".folia.xml")
}

if ((params.tok) && (params.mode != "convert")) {
    //documents need to be tokenised
    if (!params.tei) {
        foliadocuments_untokenized = Channel.fromPath(params.inputdir+"/" + inputpattern + ".folia.xml")
    }
    process tokenize_ucto {
        //tokenize the text

        input:
        file inputdocument from foliadocuments_untokenized
        val language from params.language
        val virtualenv from params.virtualenv

        output:
        file "${inputdocument.simpleName}.tok.folia.xml" into foliadocuments_tokenized

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        if [[ "${inputdocument}" != "${inputdocument.simpleName}.tok.folia.xml" ]]; then
            ucto -L "${language}" -X -F "${inputdocument}" "${inputdocument.simpleName}.tok.folia.xml"
        else
            exit 0
        fi
        """
    }
} else {
    foliadocuments_untokenized.set { foliadocuments_tokenize }
}


if (params.dolangid) {
    process langid {
        input:
        file inputdocument from foliadocuments_tokenized
        val virtualenv from params.virtualenv

        output:
        file "${inputdocument.simpleName}.langid.folia.xml" into foliadocuments_postlangid

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        if [[ "${inputdocument}" != "${inputdocument.simpleName}.langid.folia.xml" ]]; then
            folialangid -n -l nld,eng,deu,lat,fra,spa,ita,por,rus,tur,fas,ara "${inputdocument}" > "${inputdocument.simpleName}.langid.folia.xml"
        else
            exit 0
        fi
        """
    }
} else {
    foliadocuments_tokenized.set { foliadocuments_postlangid }
}


//split the tokenized documents into batches, fork into two channels
foliadocuments_postlangid
    .buffer( size: Math.ceil(inputdocuments_counter.count().val / params.workers).toInteger(), remainder: true)
    .into { foliadocuments_batches_tokenized1; foliadocuments_batches_tokenized2 }

if ((params.mode == "both") || (params.mode == "simple")) {

    process frog_original {
        //Linguistic enrichment on the original text of the document (pre-modernization)
        //Receives multiple input files in batches

        if ((!params.wikiente) && (params.mode == "simple")) {
            publishDir params.outputdir, mode: 'copy', overwrite: true
        }

        input:
        file foliadocuments from foliadocuments_batches_tokenized1 //foliadocuments is a collection/batch for multiple files
        val skip from params.skip
        val uselangid from params.uselangid
        val virtualenv from params.virtualenv
        val frogconfig from params.frogconfig

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
        if [ ! -z "$frogconfig" ]; then
            opts="-c $frogconfig"
        fi
        if [ ! -z "$skip" ]; then
            opts="\$opts --skip=${skip}"
        fi
        if [[ "$uselangid" == "true" ]]; then
            opts="\$opts --language=nld"
        fi

        #move input files to separate staging directory
        mkdir input
        mv *.folia.xml input/

        #output will be in cwd
        frog \$opts --override tokenizer.rulesFile=tokconfig-nld-historical --xmldir "." --nostdout --testdir input/ -x

        #set proper output extension
        mmv "*.folia.xml" "#1.frogoriginal.folia.xml"
        """
    }

}


//foliadocuments_frogged_original.subscribe { println "DBNL debug pipeline output document: " + it.name }
if ((params.mode == "both") || (params.mode == "modernize")) {

    //add the necessary input files to each batch
    foliadocuments_batches_tokenized2
        .map { batchfiles -> tuple(batchfiles, file(params.dictionary), file(params.preservation), file(params.rules), file(params.inthistlexicon)) }
        .set { foliadocuments_batches_withdata }

    process modernize {
        //translate the document to contemporary dutch for PoS tagging
        //adds an extra <t class="contemporary"> layer

        cpus Math.ceil(inputdocuments_counter.count().val / params.workers).toInteger()

        input:
        set file(inputdocuments), file(dictionary), file(preservationlexicon), file(rulefile), file(inthistlexicon) from foliadocuments_batches_withdata
        val virtualenv from params.virtualenv

        output:
        file "*.translated.folia.xml" into foliadocuments_modernized

        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        if [ ! -d modernization_work ]; then
            mkdir modernization_work
            mv *.folia.xml modernization_work
        fi

        FoLiA-wordtranslate --outputclass contemporary -t ${task.cpus} -d "${dictionary}" -p "${preservationlexicon}" -r "${rulefile}" -H "${inthistlexicon}" modernization_work/
        """
    }

    process frog_modernized {
        if ((!params.wikiente) && (params.mode == "modernize")) {
            publishDir params.outputdir, mode: 'copy', overwrite: true
        }

        input:
        file inputdocuments from foliadocuments_modernized
        val skip from params.skip
        val virtualenv from params.virtualenv
        val uselangid from params.uselangid
        val frogconfig from params.frogconfig

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
        if [ ! -z "$frogconfig" ]; then
            opts="-c $frogconfig"
        fi
        if [ ! -z "$skip" ]; then
            opts="\$opts --skip=${skip}"
        fi
        if [[ "$uselangid" == "true" ]]; then
            opts="\$opts --language=nld"
        fi

        if [ ! -d in ]; then
            mkdir in out
            mv *.translated.folia.xml in/
        fi

        #output will be in cwd
        frog \$opts --override tokenizer.rulesFile=tokconfig-nld-historical -x --xmldir "out/" --textclass contemporary --nostdout --testdir in/ --retry


        #set proper output extension
        if [ \$? -eq 0 ]; then
            mv out/*.xml .
            mmv "*.translated.folia.xml" "#1.frogmodernized.folia.xml"
        fi
        """
    }


    if (params.mode == "both") {

        // transform [file] -> [(basename, file)]
        foliadocuments_frogged_original
            .map { file -> [file.simpleName, file] }
            .set { foliadocuments_frogged_original2 }

        // transform [file] -> [(basename, file)]
        foliadocuments_frogged_modernized
            .map { file -> [file.simpleName, file] }
            .set { foliadocuments_frogged_modernized2 }

        //now combine the two channels on basename: [ (basename, modernizedfile, originalfile) ]
        foliadocuments_frogged_modernized2
            .combine(foliadocuments_frogged_original2, by: 0) //0 refers to first input tuple element (basename)
            .set { foliadocuments_pairs }

        process merge {
            //merge the modernized annotations with the original ones, the original ones will be included as alternatives

            if (params.entitylinking == "") {
                publishDir params.outputdir, mode: 'copy', overwrite: true
            }

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

            foliamerge -a "${modernfile}" "${originalfile}" > "${basename}.folia.xml"
            """
        }

    } else {
        //modernize mode
        foliadocuments_frogged_modernized
            .set { foliadocuments_merged }
    }
} else {
    //simple mode

    foliadocuments_frogged_original
        .set { foliadocuments_merged }

}

if (params.wikiente) {
    process wikiente {
        publishDir params.outputdir, mode: 'copy', overwrite: true

        input:
        file document from foliadocuments_merged
        val virtualenv from params.virtualenv
        val spotlightserver from params.spotlight

        output:
        file "${document.simpleName}.linked.folia.xml" into entitylinker_output


        script:
        """
        set +u
        if [ ! -z "${virtualenv}" ]; then
            source ${virtualenv}/bin/activate
        fi
        set -u

        wikiente -s "${spotlightserver}" -c 0.75 -o "${document.simpleName}.linked.folia.xml" "${document}"
        """
    }

    entitylinker_output.subscribe { println "Nederlab pipeline output document written to " +  params.outputdir + "/" + it.name }
} else {
    //for all modes
    foliadocuments_merged.subscribe { println "Nederlab pipeline output document written to " +  params.outputdir + "/" + it.name }
}
