#!/bin/bash
export PICCLSERVICEDIR=`python -c 'import picclservice; print(picclservice.__path__[0])'`
if [ ! -z $VIRTUAL_ENV ]; then
    uwsgi --plugin python3 --virtualenv $VIRTUAL_ENV --socket 127.0.0.1:8888 --chdir $VIRTUAL_ENV --wsgi-file $PICCLSERVICEDIR/picclservice.wsgi --logto picclservice.uwsgi.log --log-date --log-5xx --master --processes 2 --threads 2 --need-app
else
    uwsgi --plugin python3 --socket 127.0.0.1:8888 --wsgi-file $PICCLSERVICEDIR/picclservice.wsgi --logto picclservice.uwsgi.log --log-date --log-5xx --master --processes 2 --threads 2 --need-app
fi
