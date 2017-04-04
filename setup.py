#! /usr/bin/env python
# -*- coding: utf8 -*-

from __future__ import print_function

import os
from setuptools import setup


def read(fname):
    return open(os.path.join(os.path.dirname(__file__), fname)).read()

setup(
    name = "PICCL",
    version = "0.4",
    author = "Martin Reynaert",
    author_email = "reynaert@uvt.nl",
    description = ("Webservice for PICCL"),
    license = "GPL",
    keywords = "rest nlp computational_linguistics rest",
    url = "https://github.com/LanguageMachines/PICCL",
    packages=['picclservice'],
    long_description=read('README.md'),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Topic :: Internet :: WWW/HTTP :: WSGI :: Application",
        "Topic :: Text Processing :: Linguistic",
        "Programming Language :: Python :: 2.7",
        "Programming Language :: Python :: 3.3", #3.0, 3.1 and 3.2 are not supported by flask
        "Programming Language :: Python :: 3.4", #3.0, 3.1 and 3.2 are not supported by flask
        "Programming Language :: Python :: 3.5", #3.0, 3.1 and 3.2 are not supported by flask
        "Operating System :: POSIX",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
    ],
    package_data = {'picclservice':['picclservice/*.wsgi'] },
    include_package_data=True,
    install_requires=['CLAM >= 2.1.7']
)
