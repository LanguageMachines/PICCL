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
params.outputdir = "foliaoutput"

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
    //Extracted images per page from PDF
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
    .collect { basename, images -> [[basename],images].combinations() }
    .flatten()
    .collate(2)
    .into { pageimages }

process tesseract {
    input:
    set val(basename), file(pageimage) from pageimages
    val language from params.language

    output:
    set val(basename), file("${pageimage.baseName}" + ".hocr") into ocrpages

    script:
    """
    tesseract ${pageimage} ${pageimage.baseName} -c "tessedit_create_hocr=T" -l ${language}
    """
}

process ocrpages_to_foliapages {
    input:
    set val(basename), file(pagehocr) from ocrpages
    val virtualenv from params.virtualenv

    output:
    set val(basename), file("${pagehocr.baseName}" + ".tif.folia.xml") into foliapages

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

foliapages
    .groupTuple(sort: {
        //sort by file name (not full path)
        file(it).getName()
    })
    .into { groupfoliapages }

process foliacat {
    publishDir params.outputdir, mode: 'copy', overwrite: true

    input:
    set val(basename), file("*.tif.folia.xml") from groupfoliapages
    val virtualenv from params.virtualenv

    output:
    file "${basename}.folia.xml" into foliaoutput

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u

    foliainput=\$(ls *.tif.folia.xml | sort)
    foliacat -i ${basename} -o ${basename}.folia.xml \$foliainput
    """
}

foliaoutput.subscribe { println it }
