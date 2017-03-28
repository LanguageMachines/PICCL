#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "OCR Pipeline"
log.info "--------------------------"

params.virtualenv = ""
params.language = "nld"
params.outputdir = "folia_ocr_output"

if (params.containsKey('help') || !params.containsKey('inputdir')) {
    log.info "Usage:"
    log.info "  ocr.nf --inputdir DIRECTORY [OPTIONS]"
    log.info ""
    log.info "Options:"
    log.info "  --inputdir DIRECTORY     Input directory"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents)"
    log.info "  --language LANGUAGE      Language"
    log.info "  --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)"
    exit 2
}


pdfdocuments = Channel.fromPath(params.inputdir+"/**.pdf")

process pdfimages {
    //Extracted images from PDF
    input:
    file pdfdocument from pdfdocuments

    output:
    set val("${pdfdocument.baseName}"), file("${pdfdocument.baseName}*.tif") into pdfimages

    script:
    """
    pdfimages  -tiff -p ${pdfdocument} ${pdfdocument.baseName}
    """
}

pdfimages
    .collect { documentname, images -> [[documentname],images].combinations() }
    .flatten()
    .collate(2)
    .into { pageimages }

process tesseract {
    //Do the actual OCR using Tesseract: outputs a hOCR document for each input page image

    input:
    set val(documentname), file(pageimage) from pageimages
    val language from params.language
https://encrypted.google.com/search?hl=en&q=central%20architecture#q=piccl+architecture+reynaert&hl=en&nirf=piccolo%20architecture%20reynaert&start=10&*
    output:
    set val(documentname), file("${pageimage.baseName}" + ".hocr") into ocrpages

    script:
    """
    tesseract ${pageimage} ${pageimage.baseName} -c "tessedit_create_hocr=T" -l ${language}
    """
}

process ocrpages_to_foliapages {
    //Convert Tesseract hOCR output to FoLiA

    input:
    set val(documentname), file(pagehocr) from ocrpages
    val virtualenv from params.virtualenv

    output:
    set val(documentname), file("${pagehocr.baseName}" + ".tif.folia.xml") into foliapages

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    FoLiA-hocr -O ./ -t 1 ${pagehocr}
    """
}

//Collect all pages for a given document
//transforms [(documentname, hocrpage)] output to [(documentname, [hocrpages])], grouping pages per base name
foliapages
    .groupTuple(sort: {
        //sort by file name (not full path)
        file(it).getName()
    })
    .into { groupfoliapages }

process foliacat {
    //Concatenate separate FoLiA pages pertaining to the same document into a single document again

    publishDir params.outputdir, mode: 'copy', overwrite: true

    input:
    set val(documentname), file("*.tif.folia.xml") from groupfoliapages
    val virtualenv from params.virtualenv

    output:
    file "${documentname}.folia.xml" into foliaoutput

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    foliainput=\$(ls *.tif.folia.xml | sort)
    foliacat -i ${documentname} -o ${documentname}.folia.xml \$foliainput
    """
}

foliaoutput.subscribe { println it }
