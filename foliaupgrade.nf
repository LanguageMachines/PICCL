#!/usr/bin/env nextflow

/*
vim: syntax=groovy
-*- mode: groovy;-*-
*/

log.info "--------------------------"
log.info "FoLiA Upgrade Pipeline"
log.info "--------------------------"
def env = System.getenv()

params.extension = "folia.xml"
params.virtualenv =  env.containsKey('VIRTUAL_ENV') ? env['VIRTUAL_ENV'] : ""
params.outreport = "./foliaupgrade.report"
params.outsummary = "./foliaupgrade.summary"

if (params.containsKey('help') || !params.containsKey('inputdir')) {
    log.info "Usage:"
    log.info "  foliaupgrade.nf --inputdir DIRECTORY [OPTIONS]"
    log.info ""
    log.info "Options:"
    log.info "  --inputdir DIRECTORY     Path to the corpus directory"
    log.info "  --extension EXTENSION    Extension of FoLiA documents (default: folia.xml)"
    log.info "  --virtualenv PATH        Path to Python Virtual Environment to load (usually path to LaMachine)"
    exit 2
}


documents = Channel.fromPath(params.inputdir + "/**." + params.extension)

upgraderesults = Channel.create()
report = Channel.create()
summary = Channel.create()

process foliaupgrade {
    //validExitStatus 0,1

    input:
    file doc from documents
    val virtualenv from params.virtualenv

    output:
    file "*.foliaupgrade" into upgraderesults
    file "output/${doc.simpleName}.folia.xml" into outputdocuments

    script:
    """
    set +u
    if [ ! -z "${virtualenv}" ]; then
        source ${virtualenv}/bin/activate
    fi
    set -u
    date=\$(date +"%Y-%m-%d %H:%M:%S")
    echo "--------------- \$date ---------------" > "${doc}.foliaupgrade"
    echo "md5 checksum: "\$(md5sum ${doc}) >> "${doc}.foliaupgrade"
    mkdir output
    foliaupgrade -n "${doc}" > output/${doc.simpleName}.folia.xml 2>> "${doc}.foliaupgrade"
    if [ \$? -eq 0 ]; then
        echo \$(readlink "${doc}")"\tOK" >> "${doc}.foliaupgrade"
    else
        echo \$(readlink "${doc}")"\tFAILED" >> "${doc}.foliaupgrade"
    fi
    """
}


//split channel
upgraderesults_report = Channel.create()
upgraderesults_summary = Channel.create()
upgraderesults.into { upgraderesults_report; upgraderesults_summary }

process report {
    input:
    file "*.foliaupgrade" from upgraderesults_report.collect()

    output:
    file "foliaupgrade.report" into report

    script:
    """
    find -name "*.foliaupgrade" | xargs -n 1 cat > foliaupgrade.report
    """
}

process summary {
    input:
    file "*.foliaupgrade" from upgraderesults_summary.collect()

    output:
    file "foliaupgrade.summary" into summary

    script:
    """
    find -name "*.foliaupgrade" | xargs -n 1 tail -n 1 > foliaupgrade.summary
    """
}
//upgraderesults.subscribe { print it.text }

report
    .collectFile(name: params.outreport)

summary
    .collectFile(name: params.outsummary)
    .println { it.text }

outputdocuments.subscribe { "Upgraded " + it.name }
