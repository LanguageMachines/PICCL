#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "OCR Pipeline"
log.info "--------------------------"

params.virtualenv = ""
params.outputdir = "folia_ocr_output"
params.inputtype = "pdfimages"

if (params.containsKey('help') || !params.containsKey('inputdir') || !params.containsKey('language')) {
    log.info "Usage:"
    log.info "  ocr.nf [PARAMETERS]"
    log.info ""
    log.info "Mandatory parameters:"
    log.info "  --inputdir DIRECTORY     Input directory"
    log.info "  --language LANGUAGE      Language (iso-639-3)"
    log.info ""
    log.info "Optional parameters:"
    log.info "  --inputtype STR          Specify input type, the following are supported:"
    log.info "          pdfimages (extension *.pdf)  - Scanned PDF documents (image content) [default]"
    log.info "          pdftext (extension *.pdf)    - PDF documents with a proper text layer [not implemented yet]"
    log.info "          tif (\$document-\$sequencenumber.tif)  - Images per page (adhere to the naming convention!)"
    log.info "          jpg (\$document-\$sequencenumber.jpg)  - Images per page"
    log.info "          png (\$document-\$sequencenumber.png)  - Images per page"
    log.info "          gif (\$document-\$sequencenumber.gif)  - Images per page"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents) [default: " + params.outputdir + "]"
    log.info "  --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)"
    exit 2
}


if (params.inputtype == "pdfimages") {

    pdfdocuments = Channel.fromPath(params.inputdir+"/**.pdf")

    process pdfimages {
        //Extract images from PDF
        input:
        file pdfdocument from pdfdocuments

        output:
        set val("${pdfdocument.baseName}"), file("${pdfdocument.baseName}*.tif") into pdfimages

        script:
        """
        pdfimages  -tiff -p ${pdfdocument} ${pdfdocument.baseName}
        """
    }


    //Convert (documentname, [imagefiles]) channel to [(documentname, imagefile)]
    pdfimages
        .collect { documentname, imagefiles -> [[documentname],imagefiles].combinations() }
        .flatten()
        .collate(2)
        .into { pageimages }

} else if ((params.inputtype == "jpg") || (params.inputtype == "jpeg") || (params.inputtype == "tif") || (params.inputtype == "tiff") || (params.inputtype == "png") || (params.inputtype == "gif")) {

    //input is a set of images: $documentname-$sequencenr.$extension  (where $sequencenr can be alphabetically sorted ), Tesseract supports a variery of formats
    //we group and transform the data into a pageimages channel, structure will be: [documentname, [images]]

   Channel
        .frompath(params.inputdir+"/**." + params.inputtype)
        .collect { filename ->
            def documentname = filename.tokenize('-')[0..-2].join('-') ? filename.find('-') != null : filename
            [ documentname, filename ]
        }
        .into { pageimages }

} else if (params.inputtype == "pdftext") {

    log.error "pdftext inputtype is not implemented yet"
    exit 2

} else {

    log.error "No such input type: " + params.inputtype
    exit 2

}

process tesseract {
    //Do the actual OCR using Tesseract: outputs a hOCR document for each input page image

    input:
    set val(documentname), file(pageimage) from pageimages
    val language from params.language

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
