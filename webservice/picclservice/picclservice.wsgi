#/usr/bin/env python3
import sys
from picclservice import picclservice
import clam.clamservice
application = clam.clamservice.run_wsgi(picclservice)
