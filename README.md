[![Language Machines Badge](http://applejack.science.ru.nl/lamabadge.php/PICCL)](http://applejack.science.ru.nl/languagemachines/)
[![Build Status](https://travis-ci.org/LanguageMachines/PICCL.svg?branch=master)](https://travis-ci.org/LanguageMachines/PICCL)
[![Docker Pulls](https://img.shields.io/docker/pulls/proycon/lamachine.svg)](https://hub.docker.com/r/proycon/lamachine/)

# PICCL: Philosophical Integrator of Computational and Corpus Libraries

PICCL offers a workflow for corpus building and builds on a variety of tools.
The primary component of PICCL is TICCL; a Text-induced Corpus Clean-up system, which
performs spelling correction and OCR post-correction (normalisation of spelling
variants etc).

PICCL and TICCL constitute original research by Martin Reynaert (Tilburg University & Radboud University Nijmegen), and
is currently developed in the scope of the [CLARIAH](https://www.clariah.nl) project.

This repository hosts the relevant workflows that constitute PICCL, powered by
[Nextflow](https://www.nextflow.io).  These will be shipped as part of our
[LaMachine](https://proycon.github.io/LaMachine) software distribution. The
combination of these enable the PICCL workflow to be portable and scalable; it
can be executed accross multiple computing nodes on a high performance cluster
such as SGE, LSF, SLURM, PBS, HTCondor, Kubernetes and Amazon AWS.
Parallellisation is handled automatically. Consult the [Nextflow
documentation](https://www.nextflow.io/docs/latest/index.html) for details
regarding this.

All the modules that make up TICCL are part of the [TicclTools](https://github.com/LanguageMachines/ticcltools)
collection, and are not part of the current repository. Certain other required components are in the
[FoLiA-Utils](https://github.com/LanguageMachines/foliautils) collection. There is no need to install either of these or
other dependencies manually.

PICCL makes extensive use of the [FoLiA](https://proycon.github.io/folia) format, a rich XML-based format for linguistic
annotation.

**Important Note**: This is a new experimental version in early stages of development; for the old version consult [this repository](https://github.com/martinreynaert/TICCL). Integration in LaMachine is not released yet at this stage.

## Installation

PICCL is already shipped as a part of [LaMachine](https://proycon.github.io/LaMachine). Inside LaMachine, the command line interface is invoked as follows:

    $ nextflow run LanguageMachines/PICCL

Alternatively, and for the command line interface only; you can install [Nextflow](https://www.nextflow.io) and [Docker](https://docker.io) manually and then run the
following to obtain PICCL:

    $ nextflow pull LanguageMachines/PICCL

Subsequently ensure to always run it with the ``-with-docker proycon/lamachine`` parameter:

    $ nextflow run LanguageMachines/PICCL -with-docker proycon/lamachine

We have prepared PICCL for work in many languages, mainly on the basis of available open source lexicons due to [Aspell](http://aspell.net), these data files serve as the input TICCL and have to be downloaded once as follows;

    $ nextflow run LanguageMachines/PICCL/download-data.nf

This will generate a ``data/`` directory in your current directory, and will be referenced in the usage examples in the
next section. In addition, you can also download example corpora (>300MB), which will be placed in a ``corpora/`` directory:

    $ nextflow run LanguageMachines/PICCL/download-examples.nf

## Usage

### Command line interface

PICCL comes with the following workflows, most of them complement one or more others:

 * ``ocr.nf``   - A pipeline for Optical Character Recognition using [Tesseract](https://github.com/tesseract-ocr/tesseract); takes PDF documents or images of scanned pages and produces [FoLiA](https://proycon.github.io/folia) documents.
 * ``ticcl.nf`` - The Text-induced Corpus Clean-up system: performs OCR-postcorrection, takes as input the result from
   ``ocr.nf`` and produces further enriched [FoLiA](https://proycon.github.io/folia) documents.
 * ``tokenize.nf`` - A tokenisation workflow using the [ucto](https://LanguageMachines.github.io/ucto) tokeniser; takes either plaintext or untokenised FoLiA documents (e.g. output from ticcl), and produces tokenised FoLiA documents.
 * ``frog.nf`` - An NLP workflow for Dutch using the [frog](https://LanguageMachines.github.io/frog) tokeniser; takes either plaintext or untokenised FoLiA documents (e.g. output from ticcl), and produces linguistically enriched FoLiA documents, takes care of tokenisation as well.
 * ``foliavalidator.nf`` - A simple validation workflow to validate FoLiA documents.

The workflows can be explicitly invoked through NextFlow as follows (add the ``-with-docker proycon/lamachine`` parameter if you
are not already in LaMachine, this applies to all examples in this section), running with the ``--help`` parameter or absence of any parameters will output usage
information.

    $ nextflow run LanguageMachines/PICCL/ocr.nf --help
    --------------------------
    OCR Pipeline
    --------------------------
    Usage:
      ocr.nf [PARAMETERS]

    Mandatory parameters:
      --inputdir DIRECTORY     Input directory
      --language LANGUAGE      Language (iso-639-3)

    Optional parameters:
      --inputtype STR          Specify input type, the following are supported:
              pdfimages (extension *.pdf)  - Scanned PDF documents (image content) [default]
              pdftext (extension *.pdf)    - PDF documents with a proper text layer [not implemented yet]
              tif ($document-$sequencenumber.tif)  - Images per page (adhere to the naming convention!)
              jpg ($document-$sequencenumber.jpg)  - Images per page
              png ($document-$sequencenumber.png)  - Images per page
              gif ($document-$sequencenumber.gif)  - Images per page
              djvu (extension *.djvu)
      --outputdir DIRECTORY    Output directory (FoLiA documents) [default: ocr_output]
      --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)


    $ nextflow run LanguageMachines/PICCL/ticcl.nf --help
    --------------------------
    TICCL Pipeline
    --------------------------
    Usage:
      ticcl.nf [OPTIONS]

    Mandatory parameters:
      --inputdir DIRECTORY     Input directory (FoLiA documents with an OCR text layer)
      --lexicon FILE           Path to lexicon file (*.dict)
      --alphabet FILE          Path to alphabet file (*.chars)
      --charconfus FILE        Path to character confusion list (*.confusion)

    Optional parameters:
      --outputdir DIRECTORY    Output directory (FoLiA documents)
      --language LANGUAGE      Language
      --extension STR          Extension of FoLiA documents in input directory (default: folia.xml)
      --inputclass CLASS       FoLiA text class to use for input, defaults to 'OCR', may be set to 'current' as well


An example of invoking an OCR workflow for English is provided below, it assumes the sample data are installed in the ``corpora/``
directory. It OCRs the ``OllevierGeets.pdf`` file, which contains scanned image data, therefore we choose the
``pdfimages`` input type.

    $ nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/PDF/ENG/ --inputtype pdfimages --language eng

Alternative input types are https://pythonhosted.org/bob/index.htmlimages per page, in which case ``inputtype`` is set to either ``tif``, ``jpg``, ``gif`` or ``png``. These input files should be placed in the designated input directory and follow the naming convention
``$documentname-$sequencenumber.$extension``, for example ``harrypotter-032.png``. An example invocation on dutch
scanned pages in the example collection would be:

    $ nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/TIFF/NLD/ --inputtype tif --language nld

In case of the first example the result will be a file ``OllevierGeets.folia.xml`` in the ``ocr_output/`` directory. This in turn can serve as
input for the TICCL workflow, which will attempt to correct OCR errors:

    $ nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir ocr_output/ --lexicon data/int/eng/eng.aspell.dict --alphabet data/int/eng/eng.aspell.dict.lc.chars --charconfus data/int/eng/eng.aspell.dict.c0.d2.confusion

Note that here we pass a language-specific lexicon file, alphabet file, and character confusion file from the data files obtained by
``download-data.nf``. Result will be a file ``OllevierGeets.folia.ticcl.xml`` in the ``ticcl_output/`` directory,
containing enriched corrections. The second example, on the dutch corpus data, can be run as follows:

    $ nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir ocr_output/ --lexicon data/int/nld/nld.aspell.dict --alphabet data/int/nld/nld.aspell.dict.lc.chars --charconfus data/int/eng/nld.aspell.dict.c20.d2.confusion


## Webapplication / RESTful webservice

### Installation

PICCL is also available as a webapplication and RESTful webservice, powered by [CLAM](https://proycon.github.io/clam).
If you are in LaMachine, the webservice is already installed, if not you will have to clone this git repository, edit
``picclservice.py`` (the service configuration file) for your system and then run:

    $ cd webservice
    $ python3 setup.py install

Before the webservice can be used, in any shape or form, it is necessary to download the necessary data into the appropriate directory
(configured as ``PICCLDATAROOT`` in ``picclservice.py``)  so the webservice can find it. Follow the instructions
according to your flavour of LaMachine:

In the LaMachine Virtual Machine or within the Docker container:

    $ sudo mkdir /var/piccldata
    $ cd /var/piccldata
    $ sudo nextflow LanguageMachines/PICCL/download-data.nf
    $ sudo nextflow LanguageMachines/PICCL/download-examples.nf

In the LaMachine Local Virtual Environment:

    (lamachine)$ mkdir $VIRTUAL_ENV/piccldata
    (lamachine)$ cd $VIRTUAL_ENV/piccldata
    (lamachine)$ nextflow LanguageMachines/PICCL/download-data.nf
    (lamachine)$ nextflow LanguageMachines/PICCL/download-examples.nf

### Usage

In the LaMachine Local Virtual Environment:

    (lamachine)$ clamservice picclservice.picclservice

This will launch a development server on port 8080 and is not suitable for production use!

In LaMachine VM, just reboot the VM after having downloaded the data and the webservice will be available when
connecting to http://127.0.0.1:8080 .
In LaMachine Docker container, explicitly start the webservices after having downloaded the data for PICCL: ``sudo /usr/src/LaMachine/startwebservices.sh``, and access the aforementioned URL.

For any kind of production use, you will want to enable some form of authentication in ``webservice/picclservice/picclservice.py`` (rerun ``setup.py install`` after editing) and hook it up to an existing webserver.




















