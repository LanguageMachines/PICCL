#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "OCR Pipeline"
log.info "--------------------------"

def env = System.getenv()

params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.outputdir = "ocr_output"
params.inputtype = "pdfimages"
params.pdfhandling = "single"
params.seqdelimiter = "-"

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
    log.info "          tif (\$document-\$sequencenumber.tif)  - Images per page (adhere to the naming convention!)"
    log.info "          jpg (\$document-\$sequencenumber.jpg)  - Images per page"
    log.info "          png (\$document-\$sequencenumber.png)  - Images per page"
    log.info "          gif (\$document-\$sequencenumber.gif)  - Images per page"
    log.info "          djvu (extension *.djvu)"
    log.info "          (The hyphen delimiter may optionally be changed using --seqdelimiter)"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents) [default: " + params.outputdir + "]"
    log.info "  --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)"
    log.info "  --pdfhandling reassemble Reassemble/merge all PDFs with the same base name and a number suffix; this can"
    log.info "                           for instance reassemble a book that has its chapters in different PDFs."
    log.info "                           Input PDFs must adhere to a \$document-\$sequencenumber.pdf convention.
    log.info "                           (The hyphen delimiter may optionally be changed using --seqdelimiter)"
    exit 2
}

if ((params.inputtype.substring(0,3) == 'str') && (params.pdfhandling == "reassemble")) {
    pdfparts = Channel.fromPath(params.inputdir+"/**.pdf").groupBy { String partfile -> partfile.baseName.find(params.seqdelimiter) != null ? partfile.baseName.tokenize(params.seqdelimiter)[0..-2].join(params.seqdelimiter) : partfile.baseName }

    process reassemble_pdf {
        input:
        set val(documentname), file("*.pdf") from pdfparts

        output:
        file "${documentname}.pdf" into pdfdocuments

        script:
        """
        pdfinput=\$(ls -1v *.pdf)
        pdfunite \$pdfinput ${documentname}.pdf
        """

    }
}


if (params.inputtype == "djvu") {
    djvudocuments = Channel.fromPath(params.inputdir+"/**.djvu").view { "Input document (djvu): " + it }

    process djvu {
       //Extract images from DJVU

       input:
       file djvudocument from djvudocuments

       output:
       set val("${djvudocument.baseName}"), file("${djvudocument.baseName}*.tif") into djvuimages

       script:
       """
       ddjvu -format=tiff -eachpage ${djvudocument} ${djvudocument.baseName}-%d.tif
       """
    }

    //Convert (documentname, [imagefiles]) channel to [(documentname, imagefile)]
    djvuimages
        .collect { documentname, imagefiles -> [[documentname],imagefiles].combinations() }
        .flatten()
        .collate(2)
        .into { pageimages }

} else if (params.inputtype == "pdfimages") {

    if (params.pdfhandling == "single") {
        pdfdocuments = Channel.fromPath(params.inputdir+"/**.pdf").view { "Input document (pdfimages): " + it }
    }

    process pdfimages {
        //Extract images from PDF
        input:
        file pdfdocument from pdfdocuments

        output:
        set val("${pdfdocument.baseName}"), file("${pdfdocument.baseName}*.p?m") into pdfimages_bitmap

        script: //#older versions of pdfimages can not do tiff directly, we have to accommodate this so do conversion in two steps
        """
        pdfimages -p ${pdfdocument} ${pdfdocument.baseName}
        """
    }


    //Convert (documentname, [imagefiles]) channel to [(documentname, imagefile)]
    pdfimages_bitmap
        .collect { documentname, imagefiles -> [[documentname],imagefiles].combinations() }
        .flatten()
        .collate(2)
        .into { pageimages_bitmap }


    process bitmap2tif {
        //Convert images to tif
        input:
        set val(basename), file(bitmapimage) from pageimages_bitmap

        output:
        set val(basename), file("${bitmapimage.baseName}.tif") into pageimages

        script:
        """
        convert ${bitmapimage} ${bitmapimage.baseName}.tif
        """
    }

} else if ((params.inputtype == "jpg") || (params.inputtype == "jpeg") || (params.inputtype == "tif") || (params.inputtype == "tiff") || (params.inputtype == "png") || (params.inputtype == "gif")) {

    //input is a set of images: $documentname-$sequencenr.$extension  (where $sequencenr can be alphabetically sorted ), Tesseract supports a variery of formats
    //we group and transform the data into a pageimages channel, structure will be: [(documentname, pagefile)


   Channel
        .fromPath(params.inputdir+"/**." + params.inputtype)
        .map { pagefile ->
            def documentname = pagefile.baseName.find(params.seqdelimiter) != null ? pagefile.baseName.tokenize(params.seqdelimiter)[0..-2].join(params.seqdelimiter) : pagefile.baseName
            [ documentname, pagefile ]
        }
        .into { pageimages }


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

    errorStrategy 'ignore' //not the most elegant solution, but sometimes 'empty' hocr files get fed that won't produce a folia file

    input:
    set val(documentname), file(pagehocr) from ocrpages
    val virtualenv from params.virtualenv

    //when:
    //pagehocr.text =~ /ocrx_word/

    output:
    set val(documentname), file("${pagehocr.baseName}" + "*.folia.xml") into foliapages //TODO: verify this also works if input is not TIF or PDF?

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

    if [ -f .tif.folia.xml ]; then
        #only one file, nothing to cat
        cp .tif.folia.xml ${documentname}.folia.xml
    else
        foliainput=\$(ls -1v *.tif.folia.xml)
        foliacat -i ${documentname} -o ${documentname}.folia.xml \$foliainput
    fi
    """
}


foliaoutput.subscribe { println "OCR output document written to " +  params.outputdir + "/" + it.name }
