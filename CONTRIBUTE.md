Technical Details
======================

At the core, PICCL consists of various independent
[Nextflow](https://nextflow.io) pipeline scripts (the ``*.nf`` scripts). These pipeline scripts provide the logic to connect a number of inter-dependent **processes** and determines the data flow between them. Within these processes, any language may be use to define the scripts that performs the tasks (bash/python/perl/etc...). Typically, a process script invokes a single external tool.

The underlying tools that are invoked are not provided by PICCL itself,
but installation and distribution thereof is delegated to
[LaMachine](https://proycon.github.io/LaMachine), upon which PICCL
depends. A notable example is the
[TICCLtools](https://github.com/LanguageMachines/Ticcltools) toolset which
provides a variety of tools invoked by the TICCL workflow (``ticcl.nf``).

The exception to the above are some scripts (shell/perl/python/etc) that are
not otherwise distributed nor can be considered proper reusable tools out of
the scope of PICCL. These are distributed as part of PICCL in in ``scripts/``.
This is a fall-back solution that be preferably be kept to a minimum.

PICCL features a RESTful webservice which doubles as a simple webapplication.
This provides an interface that exposes *some* (currently not all!) of the
workflows. This webservice is implemented in
[CLAM](https://proycon.github.io/clam). Note that CLAM provides a fairly
generic and simplistic user-interface. Considering the envisioned audience for
PICCL, a more user-oriented interface that communicates with the PICCL
webservice may be desireable but is not currently provided by this project.

For linguistic annotation, the pivot format in PICCL is [FoLiA](https://proycon.github.io/folia).


Contributor Guidelines
=========================

* The PICCL codebase is maintained in git at https://github.com/LanguageMachines/PICCL
    * Never do any development outside of version control!!!
    * Pull requests welcome!! (direct push access for main project contributors)
    * the ``master`` branch corresponds to the latest development version and should serve as the basis for all development
        * do not use this branch for production, always use the latest release (LaMachine takes care of this for you automatically)
        * keep the master branch in a workable state, use separate git branches for intensive development cycles.
        * Regarding development of TICCL, the PICCL ``master`` branch is assumed to be compatible with the ``master`` branch of TICCL-tools (https://github.com/LanguageMachines/PICCL/issues/35)
* For development of workflows, consult the [Nextflow Documentation](https://www.nextflow.io/docs/latest/index.html). The Nextflow scripting language is an extension of the Groovy programming language (runs on the Java VM) whose syntax has been specialized to ease the writing of computational pipelines in a declarative manner.
    * ``ticcl.nf`` has been commented extra to serve as an example
    * The process scripts within Nextflow pipeline scripts should typically invoke only a single external tool, or at least perform a single well-defined task (if you want to invoke a series of tools, use separate processes)
* To make additional tools available for use in PICCL, consult the documentation on [adding new software to LaMachine](https://github.com/proycon/LaMachine/blob/master/CONTRIBUTING.md), installing tools should *never* be the responsibility of the end-user and rarely that of PICCL itself.
* To add pipelines to the webinterface, edit the PICCL's webservice configuration script (``webservice/picclservice/picclservice.py``), where you can define profiles, and wrapper script (``webservice/picclservice/picclservice_wrapper.py``). Consult the [CLAM Documentation](https://proycon.github.io/clam) for details on how to do this.
    * The RESTful API is auto-documented at the ``/piccl/info`` endpoint of where PICCL is hosted. (e.g. https://webservices-lst.science.ru.nl/piccl/info/)
* Report all bugs and feature requests pertaining to pipelines and webservice (or in case you simply don't know) to https://github.com/LanguageMachines/PICCL/issues
    * If it is clear that a problem is caused by an underlying tool, report it to the respective developer
        * For installation/deployment problems, use https://github.com/proycon/LaMachine
        * For the TICCL tools use https://github.com/LanguageMachines/Ticcltools/issues
        * For CLAM use https://github.com/proycon/clam/issues
        * For Tesseract (3rd party) use https://github.com/tesseract-ocr/tesseract/issues
* Integration tests are defined in ``test.sh`` and will automatically be run on our continuous integration platform at
    https://travis-ci.org/LanguageMachines/PICCL after each git push.
    * If you add a feature, we strongly recommend you to add a test.
    * The coverage of the tests is currently seriously sub-optimal!!
    * Tests should be limited in scope so they can be performed quickly, often and with limited resources (no OCRing of whole books!!)
    * Tests on a lower (unit) level are the responsibility of the underlying tools, rather than PICCL
* Martin Reynaert is the project leader with the final say on what functionality is accepted into PICCL or not.

Setting up a Development Environment
---------------------------------------

* Install the *development* version of [LaMachine](https://proycon.github.io/LaMachine), in any flavour, and enable
    PICCL in the installation manifest during the bootstrap procedure (or just run ``lamachine-add piccl`` after the
    fact)
* The PICCL git repository will be cloned in ``$LM_SOURCEPATH/PICCL``. If you do not have direct push access to the
    PICCL repository,  we recommend you fork
    https://github.com/LanguageMachines/PICCL and add do a ``git remote add`` to track your own branch there.
* You can always upgrade your LaMachine environment with ``lamachine-update``, but make sure you don't have uncommitted
    changes (they will be stashed away automatically)!!
* Run the *development* webservice as follows: ``cd $LM_SOURCEPATH/PICCL/webservice && ./startserver_development.sh``
    and connect at ``http://127.0.0.1:8080``. If you are running the LaMachine VM, you may need to stop the
    automatically started production webserver first with ``lamachine-stop-webserver`` as it shares the same port.
