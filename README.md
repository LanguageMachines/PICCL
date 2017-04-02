# PICCL: Philosophical Integrator of Computational and Corpus Libraries

PICCL offers a workflow for corpus building and builds on a variety of tools.
The primary component of PICCL is TICCL; a Text-induced Corpus Clean-up system, which
performs spelling correction and OCR post-correction (normalisation of spelling
variants etc).

PICCL and TICCL constitute original research by Martin Reynaert (Tilburg University & Radboud University Nijmegen), and
is currently developed in the scope of the [CLARIAH](https://www.clariah.nl) project.

This repository hosts the relevant workflows that constitute PICCL, powered by
[Nextflow](https://www.nextflow.io). These will be shipped as part of our
[LaMachine](https://proycon.github.io/LaMachine) software distribution.

The modules that make up TICCL are part of the [TicclTools](https://github.com/LanguageMachines/ticcltools) collection.

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
next section. In addition, you can also download example corporai(>300MB), which will be placed in a ``corpora/`` directory:

    $ nextflow run LanguageMachines/PICCL/download-examples.nf

# Usage

PICCL comes with the following complementary workflows:

 * ``ocr.nf``   - A pipeline for Optical Character Recognition using [Tesseract](https://github.com/tesseract-ocr/tesseract); takes PDF documents or images of scanned pages and produces [FoLiA](https://proycon.github.io/folia) documents.
 * ``ticcl.nf`` - The Text-induced Corpus Clean-up system: performs OCR-postcorrection, takes as input the result from
   ``ocr.nf`` and produces further enriched [FoLiA](https://proycon.github.io/folia) documents.

The workflows can be explicitly invoked through NextFlow as follows (add the ``-with-docker proycon/LaMachine`` parameter if you
are not already in LaMachine), running with the ``--help`` parameter or absence of any parameters will output usage
information.

    $ nextflow run LanguageMachines/PICCL/ocr.nf



This will generate a ``data/`` directory in your current directory, and will be referenced in the usage examples in the
next section.





