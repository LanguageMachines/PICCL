#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "FoLiA Validator Pipeline"
log.info "--------------------------"
def env = System.getenv()

params.extension = "folia.xml"
params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.outreport = "./foliavalidation.report"
params.outsummary = "./foliavalidation.summary"

if (params.containsKey('help') || !params.containsKey('inputdir')) {
    log.info "Usage:"
    log.info "  foliavalidator.nf --inputdir DIRECTORY [OPTIONS]"
    log.info ""
    log.info "Options:"
    log.info "  --inputdir DIRECTORY     Path to the corpus directory"
    log.info "  --extension EXTENSION    Extension of FoLiA documents (default: folia.xml)"
    log.info "  --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)"
    exit 2
}


documents = Channel.fromPath(params.inputdir + "/**." + params.extension)

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
    date=\$(date +"%Y-%m-%d %H:%M:%S")
    echo "--------------- \$date ---------------" > ${doc}.foliavalidator
    echo "md5 checksum: "\$(md5sum ${doc}) >> ${doc}.foliavalidator
    foliavalidator ${doc} 2>> ${doc}.foliavalidator
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
