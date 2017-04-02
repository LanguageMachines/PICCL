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

Subsequently ensure to always run it with the ``-with-docker proycon/LaMachine`` parameter:

    $ nextflow run LanguageMachines/PICCL -with-docker proycon/LaMachine

We have prepared PICCL for work in many languages, mainly on the basis of available open source lexicons due to [Aspell](http://aspell.net), these data files serve as the input TICCL and have to be downloaded once as follows;

    $ nextflow run LanguageMachines/PICCL/download-data.nf

This will generate a ``data/`` directory in your current directory, and will be referenced in the usage examples in the
next section. In addition, you can also download example corpora (>300MB), which will be placed in a ``corpora/`` directory:

    $ nextflow run LanguageMachines/PICCL/download-examples.nf

# Usage

## Command line interface

PICCL comes with the following workflows, most of them complement one or more others:

 * ``ocr.nf``   - A pipeline for Optical Character Recognition using [Tesseract](https://github.com/tesseract-ocr/tesseract); takes PDF documents or images of scanned pages and produces [FoLiA](https://proycon.github.io/folia) documents.
 * ``ticcl.nf`` - The Text-induced Corpus Clean-up system: performs OCR-postcorrection, takes as input the result from
   ``ocr.nf`` and produces further enriched [FoLiA](https://proycon.github.io/folia) documents.
 * ``tokenize.nf`` - A tokenisation workflow using the [ucto](https://LanguageMachines.github.io/ucto) tokeniser; takes either plaintext or untokenised FoLiA documents (e.g. output from ticcl), and produces tokenised FoLiA documents.
 * ``frog.nf`` - An NLP workflow for Dutch using the [frog](https://LanguageMachines.github.io/frog) tokeniser; takes either plaintext or untokenised FoLiA documents (e.g. output from ticcl), and produces linguistically enriched FoLiA documents, takes care of tokenisation as well.
 * ``foliavalidator.nf`` - A simple validation workflow to validate FoLiA documents.

The workflows can be explicitly invoked through NextFlow as follows (add the ``-with-docker proycon/LaMachine`` parameter if you
are not already in LaMachine, this applies to all examples in this section), running with the ``--help`` parameter or absence of any parameters will output usage
information.

    $ nextflow run LanguageMachines/PICCL/ocr.nf --help
    $ nextflow run LanguageMachines/PICCL/ticcl.nf --help

An example of an OCR workflow for English is provided below, it assumes the sample data are installed in the ``corpora/``
directory. It OCRs the ``OllevierGeets.pdf`` file, which contains scanned image data, therefore we choose the
``pdfimages`` input type.

    $ nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/PDF/ENG/ --inputtype pdfimages --language eng

Alternative input types are images per page, in which case ``inputtype`` is set to either ``tif``, ``jpg``, ``gif`` or ``png``. These input files should be placed in the designated input directory and follow the naming convention
``$documentname-$sequencenumber.$extension``, for example ``harrypotter-032.png``. An example invocation on dutch
scanned pages in the example collection would be:

    $ nextflow run LanguageMachines/PICCL/ocr.nf --inputdir corpora/TIFF/NLD/ --inputtype tif --language nld

In case of the first example the result will be a file ``OllevierGeets.folia.xml`` in the ``folia_ocr_output/`` directory. This in turn can serve as
input for the TICCL workflow, which will attempt to correct OCR errors:

    $ nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir folia_ocr_output/ --lexicon data/int/eng/eng.aspell.dict --alphabet data/int/eng/eng.aspell.dict.lc.chars --charconfus data/int/eng/eng.aspell.dict.c0.d2.confusion

Note that here we pass a language-specific lexicon file, alphabet file, and character confusion file from the data files obtained by
``download-data.nf``. Result will be file ``OllevierGeets.folia.ticcl.xml`` in the ``folia_ticcl_output/`` directory,
containing enriched corrections. The second example, on the dutch corpus data, can be run as follows:

    $ nextflow run LanguageMachines/PICCL/ticcl.nf --inputdir folia_ocr_output/ --lexicon data/int/nld/nld.aspell.dict --alphabet data/int/nld/nld.aspell.dict.lc.chars --charconfus data/int/eng/nld.aspell.dict.c20.d2.confusion


## Webapplication / RESTful webservice

PICCL will also become available as a webapplication and RESTful webservice soon, powered by
[CLAM](https://proycon.github.io/clam).










