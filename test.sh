#!/bin/bash

####################################################### INITIALISATION ##################################################

if [[ "$USER" == "travis" ]]; then
   #special handling for travis-ci
   cd /home/travis/build/LanguageMachines/PICCL
   export PATH="/home/travis/build/LanguageMachines/PICCL:$PATH"
   source lamachine-${CONF_NAME}-activate
   if [ -z "$VIRTUAL_ENV" ]; then
       echo "LaMachine did not activate properly"
       exit 2
   fi
   touch .test #test write permission
   ls -l
fi

PICCL="nextflow run LanguageMachines/PICCL"
if [ -d /vagrant ] || [ ! -z "$VIRTUAL_ENV" ] || [ -f /usr/bin/TICCL-anahash ] || [ -f /usr/local/bin/TICCL-anahash ]; then
    #we are in LaMachine, no need for docker
    WITHDOCKER=""
    PICCLDIR=$(dirname "${BASH_SOURCE[0]}")
    if [ -f $PICCLDIR/ticcl.nf ]; then
        PICCL=$PICCLDIR #run piccl scripts directly
        echo "PICCL directory is $PICCLDIR"
    fi
else
    #we are not in LaMachine so use the docker LaMachine:
    WITHDOCKER="-with-docker proycon/lamachine:piccl"
fi

if [ -z "$WITHDOCKER" ]; then
    if [ ! -d data ]; then
        echo -e "\n\n======= Downloading data =======">&2
        $PICCL/download-data.nf $WITHDOCKER || exit 2
    fi

    if [ ! -d corpora ]; then
        echo -e "\n\n======= Downloading examples ========">&2
        $PICCL/download-examples.nf $WITHDOCKER || exit 2
    fi
else
    echo -e "\n\n======= Copying data and examples from container  =======">&2
    docker run -ti -d proycon/lamachine:piccl /bin/bash
    CONTAINER_ID=$(docker ps -alq)
    docker cp $CONTAINER_ID:/usr/local/opt/PICCL/data data
    docker cp $CONTAINER_ID:/usr/local/opt/PICCL/corpora corpora
    docker stop $CONTAINER_ID
fi

checkfolia () {
    if [ -f "$1" ] && [ -s "$1" ]; then
       folialint $1 >/dev/null || exit 2
    fi
}

if [ ! -z "$1" ]; then
    TEST=$1
else
    TEST="all"
fi


#################################################### PREPARATION #######################################################

# Setting up some input texts to be used by tests

if [ ! -d text_input ]; then
    mkdir -p text_input || exit 2
    cd text_input
    #prepare a small test text:
    echo "Magnetisme is een natuurkundig verschijnsel dat zich uit in krachtwerking tussen magneten of andere gemagnetiseerde of magnetiseerbare voorwerpen, en een krachtwerking heeft op bewegende elektrische ladingen, zoals in stroomvoerende leidingen. De krachtwerking vindt plaats door middel van een magnetisch veld, dat door de voorwerpen zelf of anderszins wordt opgewekt.

Al in de Oudheid ontdekte men dat magnetietkristallen magnetisch zijn. Magnetiet is, evenals magnesium genoemd naar Magnesia, een gebied in Thessalië in het oude Griekenland. Verantwoordelijk voor het magnetisme van magnetiet is het aanwezige ijzer. Veel ijzerlegeringen vertonen magnetisme. Naast ijzer vertonen ook nikkel, kobalt en gadolinium magnetische eigenschappen.

Er zijn natuurlijke en kunstmatige magneten (bijvoorbeeld Alnico, Fernico, ferrieten). Alle magneten hebben twee polen die de noordpool en de zuidpool worden genoemd. De noordpool van een magneet stoot de noordpool van een andere magneet af, en trekt de zuidpool van een andere magneet aan. Twee zuidpolen stoten elkaar ook af. Omdat ook de aarde een magneetveld heeft, met z'n magnetische zuidpool vlak bij de geografische noordpool en z'n magnetische noordpool vlak bij de geografische zuidpool, zal een vrij ronddraaiende magneet altijd de noord-zuidrichting aannemen. De benamingen van de polen van een magneet zijn hiervan afgeleid. Overigens wordt gemakshalve, maar wel enigszins verwarrend, de zuidpool van de \"aardemagneet\" de magnetische noordpool genoemd en de noordpool van de \"aardemagneet\" de magnetische zuidpool. Dit is iets waar zelden bij stilgestaan wordt, maar de noordpool van een kompasnaald wijst immers naar het noorden, dus wordt deze aangetrokken door wat feitelijk een magnetische zuidpool is.

Een verwant verschijnsel is elektromagnetisme, magnetisme dat ontstaat door een elektrische stroom. In wezen wordt alle magnetisme veroorzaakt door zowel roterende als revolverende elektrische ladingen in kringstromen." > magnetisme.txt    #source: https://nl.wikipedia.org/wiki/Magnetisme
    cd ..
fi

if [ ! -d text_input_ticcl ]; then
    mkdir -p text_input_ticcl || exit 2
    cd text_input_ticcl
    echo "The barbarian invasion put an end, for six centuries, to the
civilization of western Europe. It lingered in Ireland until the
Danes destroyed it in the ninth century; before its extinction
there it produced one notable figure, Scotus Erigena. In the
Eastern Empire, Greek civilization, in a desiccated form, survived,
as in a museum, till the fall of Constantinople in 1453, but nothing
of importance to the world came out of Constantinople except an
artistic tradition and Justinian's Codes of Roman law.

During the period of darkness, from the end of the fifth century
to the middle of the eleventh, the western Roman world under-
went some very interesting changes. The conflict between duty to

1 This opinion was not unknown in earlier times: it is stated, for
example, in the Antigone of Sophocles. But before the Stoics those who
held it were fei%.

* That is why the modem Russian does not think that we ought to
obey dialectical materialism rather than Stalin." > ticcltest.txt
    cd ..
fi

###################################################### TESTS ###########################################################

if [[ "$TEST" == "toktxt" ]] || [[ "$TEST" == "all" ]]; then
    echo -e "\n\n======== Testing tokenisation pipeline from plain text ========= ">&2
    if [ -d tokenized_output ]; then rm -Rf tokenized_output; fi  #cleanup previous results if they're still lingering around
    $PICCL/tokenize.nf --inputdir text_input --inputformat text --language nld $WITHDOCKER || exit 2
    checkfolia tokenized_output/magnetisme.tok.folia.xml
fi

if [[ "$TEST" == "frogtxt" ]] || [[ "$TEST" == "all" ]]; then
    echo -e "\n\n========= Testing frog pipeline from plain text ========= ">&2
    if [ -d frog_output ]; then rm -Rf frog_output; fi  #cleanup previous results if they're still lingering around
    $PICCL/frog.nf --inputdir text_input --inputformat text --language nld $WITHDOCKER || exit 2
    checkfolia frog_output/magnetisme.frogged.folia.xml
fi

if [[ "$TEST" == "ocrpdf-eng" ]] || [[ "$TEST" == "ticcl-eng" ]] || [[ "$TEST" == "all" ]]; then
    echo -e "\n\n======== Testing OCR (eng) with inputtype pdf ======">&2
    if [ -d ocr_output ]; then rm -Rf ocr_output; fi  #cleanup previous results if they're still lingering around
    $PICCL/ocr.nf --inputdir corpora/PDF/ENG/ --language eng --inputtype pdf $WITHDOCKER || exit 2
    checkfolia ocr_output/OllevierGeets.folia.xml
fi

if [[ "$TEST" == "ticcl-eng" ]] || [[ "$TEST" == "all" ]]; then
    echo -e "\n\n======== Testing TICCL (eng) =========">&2
    if [ -d ticcl_output ]; then rm -Rf ticcl_output; fi
    $PICCL/ticcl.nf --inputdir ocr_output/ --lexicon data/int/eng/eng.aspell.dict --alphabet data/int/eng/eng.aspell.dict.lc.chars --charconfus data/int/eng/eng.aspell.dict.c0.d2.confusion $WITHDOCKER || exit 2
    checkfolia ticcl_output/OllevierGeets.ticcl.folia.xml
fi


if [[ "$TEST" == "ocrtif-nld" ]] || [[ "$TEST" == "ticcl-nld" ]] || [[ "$TEST" == "all" ]]; then
    echo -e "\n\n======== Testing OCR (nld) with inputtype tif ==========">&2
    if [ -d ocr_output ]; then rm -Rf ocr_output; fi  #cleanup previous results if they're still lingering around
    $PICCL/ocr.nf --inputdir corpora/TIFF/NLD/ --inputtype tif --language nld $WITHDOCKER || exit 2
    checkfolia ocr_output/dpo.folia.xml
fi

if [[ "$TEST" == "ticcl-nld" ]] || [[ "$TEST" == "all" ]]; then
    echo -e "\n\n======== Testing TICCL (nld) ============ ">&2
    if [ -d ticcl_output ]; then rm -Rf ticcl_output; fi
    $PICCL/ticcl.nf --inputdir ocr_output/ --lexicon data/int/nld/nld.aspell.dict --alphabet data/int/nld/nld.aspell.dict.lc.chars --charconfus data/int/nld/nld.aspell.dict.c20.d2.confusion $WITHDOCKER || exit 2
    checkfolia ticcl_output/dpo.ticcl.folia.xml
fi


if [[ "$TEST" == "ocrpdf-deufrak" ]] || [[ "$TEST" == "all" ]]; then
    echo -e "\n\n======== Testing OCR (deu-frak) with inputtype pdf and reassembly  ======">&2
    if [ ! -d tmpinput ]; then
        mkdir -p tmpinput || exit 2
        cp corpora/PDF/DEU-FRAK/BolzanoWLfull/WL1_1.pdf corpora/PDF/DEU-FRAK/BolzanoWLfull/WL2_2.pdf corpora/PDF/DEU-FRAK/BolzanoWLfull/WL2_10.pdf tmpinput/ || exit 3
    fi
    if [ -d ocr_output ]; then rm -Rf ocr_output; fi  #cleanup previous results if they're still lingering around
    $PICCL/ocr.nf --inputdir tmpinput  --language deu_frak --inputtype pdf --pdfhandling reassemble --seqdelimiter "_" $WITHDOCKER || exit 2
fi

#if [[ "$TEST" == "ocrdvju-eng" ]] || [[ "$TEST" == "all" ]]; then
#    echo -e "\n\n======== Testing OCR (eng) with inputtype djvu ======">&2
#    if [ -d ocr_output ]; then rm -Rf ocr_output; fi  #cleanup previous results if they're still lingering around
#    $PICCL/ocr.nf --inputdir corpora/DJVU/ENG/ --language eng --inputtype djvu $WITHDOCKER || exit 2
#fi

if [[ "$TEST" == "ticcltxt-eng" ]] || [[ "$TEST" == "all" ]]; then
    echo -e "\n\n======== Testing TICCL with text input (eng) =========">&2
    if [ -d ticcl_output ]; then rm -Rf ticcl_output; fi
    $PICCL/ticcl.nf --inputdir text_input_ticcl/ --inputtype text --lexicon data/int/eng/eng.aspell.dict --alphabet data/int/eng/eng.aspell.dict.lc.chars --charconfus data/int/eng/eng.aspell.dict.c0.d2.confusion $WITHDOCKER || exit 2
    checkfolia ticcl_output/ticcltest.ticcl.folia.xml
fi

#if [[ "$TEST" == "ticcltxt-eng" ]] || [[ "$TEST" == "all" ]]; then
#    echo -e "\n\n======== Testing TICCL with PDF input (text; no OCR) (eng) =========">&2
#    if [ -d ticcl_output ]; then rm -Rf ticcl_output fi
#    $PICCL/ticcl.nf --inputdir corpora/PDF/ENG/ --inputtype pdf --lexicon data/int/eng/eng.aspell.dict --alphabet data/int/eng/eng.aspell.dict.lc.chars --charconfus data/int/eng/eng.aspell.dict.c0.d2.confusion $WITHDOCKER || exit 2
#fi

