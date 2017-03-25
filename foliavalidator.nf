#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

params.dir = "./corpus"
params.extension = "folia.xml"
params.virtualenv = ""
params.outreport = "./foliavalidation.report"
params.outsummary = "./foliavalidation.summary"

log.info "FoLiA Validator"

documents = Channel.fromPath(params.dir + "/**." + params.extension)

validationresults = Channel.create()
report = Channel.create()
summary = Channel.create()

process foliavalidator {
    validExitStatus 0,1

    input:
    file doc from documents
    val virtualenv from params.virtualenv

    output:
    file "*.foliavalidator" into validationresults

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u
    foliavalidator ${doc} 2> ${doc}.foliavalidator
    if [ \$? -eq 0 ]; then
        echo \$(readlink ${doc})"\tOK" >> ${doc}.foliavalidator
    else
        echo \$(readlink ${doc})"\tFAILED" >> ${doc}.foliavalidator
    fi
    """
}


//split channel
validationresults_report = Channel.create()
validationresults_summary = Channel.create()
validationresults.into { validationresults_report; validationresults_summary }

process report {
    input:
    file "*.foliavalidator" from validationresults_report.collect()

    output:
    file "foliavalidation.report" into report

    script:
    """
    find -name "*.foliavalidator" | xargs -n 1 cat > foliavalidation.report
    """
}

process summary {
    input:
    file "*.foliavalidator" from validationresults_summary.collect()

    output:
    file "foliavalidation.summary" into summary

    script:
    """
    find -name "*.foliavalidator" | xargs -n 1 tail -n 1 > foliavalidation.summary
    """
}
//validationresults.subscribe { print it.text }

report
    .collectFile(name: params.outreport)

summary
    .collectFile(name: params.outsummary)
    .println { it.text }
