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
params.inputtype = "pdf"
params.pdfhandling = "single"
params.seqdelimiter = "_"

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
    log.info "          pdf (extension *.pdf)  - Scanned PDF documents (image content) [default]"
    log.info "          tif (\$document_\$sequencenumber.tif)  - Images per page (adhere to the naming convention!)"
    log.info "          jpg (\$document_\$sequencenumber.jpg)  - Images per page"
    log.info "          png (\$document_\$sequencenumber.png)  - Images per page"
    log.info "          gif (\$document_\$sequencenumber.gif)  - Images per page"
    log.info "          djvu (extension *.djvu)"
    log.info "          (The underscore delimiter may optionally be changed using --seqdelimiter)"
    log.info "  --outputdir DIRECTORY    Output directory (FoLiA documents) [default: " + params.outputdir + "]"
    log.info "  --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)"
    log.info "  --pdfhandling reassemble Reassemble/merge all PDFs with the same base name and a number suffix; this can"
    log.info "                           for instance reassemble a book that has its chapters in different PDFs."
    log.info "                           Input PDFs must adhere to a \$document_\$sequencenumber.pdf convention."
    log.info "                           (The underscore delimiter may optionally be changed using --seqdelimiter)"
    log.info "  --seqdelimiter           Sequence delimiter in input files (defaults to: _)"
    log.info "  --seqstart               What input field is the sequence number (may be a negative number to count from the end), default: -2"
    exit 2
}

if ((params.inputtype == "pdf") && (params.pdfhandling == "reassemble")) {

    //Group $documentname-$sequencenumber.pdf in a channel emitting a documentname and a list of (unordered) sequence pdf files
    Channel.fromPath(params.inputdir+"/**.pdf")
                .map { partfile -> partfile.baseName.find(params.seqdelimiter) != null ? tuple(partfile.baseName.tokenize(params.seqdelimiter)[0..-2].join(params.seqdelimiter), partfile) : tuple(partfile.baseName, partfile) }
                .groupTuple()
                .set { pdfparts }

    process reassemble_pdf {
        //Reassemble a PDF 'book' (or whatever) from its parts (e.g, chapters, pages)
        input:
        set val(documentname), file(pdffiles) from pdfparts

        output:
        file "${documentname}.pdf" into pdfdocuments

        script:
        """
        count=\$(ls *.pdf | wc -l)
        if [ \$count -eq 1 ]; then
            cp \$(ls *.pdf) ${documentname}.pdf
        elif [ \$count -eq 0 ]; then
            echo "No input PDFs to merge!">&2
            exit 5
        else
            pdfinput=\$(ls -1v *.pdf) #performs a natural sort
            pdfunite \$pdfinput ${documentname}.pdf
        fi
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
       ddjvu -format=tiff -eachpage ${djvudocument} ${djvudocument.baseName}_%d.tif
       """
    }

    //Convert (documentname, [imagefiles]) channel to [(documentname, imagefile)]
    djvuimages
        .collect { documentname, imagefiles -> [[documentname],imagefiles].combinations() }
        .flatten()
        .collate(2)
        .set { pageimages }

} else if ((params.inputtype == "pdf") || (params.inputtype == "pdfimages")) { //2nd condition is needed for backwards compatibility

    if (params.pdfhandling == "single") {
        pdfdocuments = Channel.fromPath(params.inputdir+"/**.pdf").view { "Input document (pdf): " + it }
    }

    process pdfimages {
        //Extract images from PDF
        input:
        file pdfdocument from pdfdocuments

        output:
        set val("${pdfdocument.baseName}"), file("${pdfdocument.baseName}*.p?m") into pdfimages_bitmap

        script: //#older versions of pdfimages can not do tiff directly, we have to accommodate this so do conversion in two steps
        """
        #!/usr/bin/env python3
        import os
        import glob
        import sys

        r = os.system("pdfimages -p ${pdfdocument} ${pdfdocument.baseName}")
        if r != 0:
            print("pdfimages failed...", file=sys.stderr)
            sys.exit(r)

        #This post processing script deletes all images extracted from pages EXCEPT the largest one (bitmap filesize-wise)
        def prune(sizes):
            for i, (filename, size) in enumerate(sorted(sizes.items(), key= lambda x: x[1]*-1)):
                if i > 0:
                    print("pruning image that is not the largest for a this page:  ", filename, size, file=sys.stderr)
                    os.unlink(filename)

        sizes = {}
        prev_docname_page = None
        for imagefile in sorted(glob.glob("${pdfdocument.baseName}*.p?m")):
            fields = imagefile[:-4].split('-')
            docname_page = tuple(fields[:-1])
            if docname_page != prev_docname_page and sizes:
                prune(sizes)
                sizes = {}
            sizes[imagefile] = os.path.getsize(imagefile)
            prev_docname_page = docname_page
        prune(sizes)
        """
    }


    //Convert (documentname, [imagefiles]) channel to [(documentname, imagefile)]
    pdfimages_bitmap
        .collect { documentname, imagefiles -> [[documentname],imagefiles].combinations() }
        .flatten()
        .collate(2)
        .set { pageimages_bitmap }


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

    //input is a set of images: $documentname_$sequencenr.$extension  (where $sequencenr can be alphabetically sorted ), Tesseract supports a variery of formats
    //we group and transform the data into a pageimages channel, structure will be: [(documentname, pagefile)


   Channel
        .fromPath(params.inputdir+"/**." + params.inputtype)
        .map { pagefile ->
            def documentname = pagefile.baseName.find(params.seqdelimiter) != null ? pagefile.baseName.tokenize(params.seqdelimiter)[0..-2].join(params.seqdelimiter) : pagefile.baseName
            [ documentname, pagefile ]
        }
        .set { pageimages }


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
    .set { groupfoliapages }

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
