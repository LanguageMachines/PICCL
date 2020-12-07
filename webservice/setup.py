#! /usr/bin/env python
# -*- coding: utf8 -*-

from __future__ import print_function

import os
from setuptools import setup



setup(
    name = "PICCL",
    version = "0.9.5", #also change in codemeta.json and picclservice.py
    author = "Martin Reynaert, Maarten van Gompel",
    author_email = "reynaert@uvt.nl",
    description = ("Webservice for PICCL; a set of workflows for corpus building through OCR, post-correction, modernization of historic language and Natural Language Processing"),
    license = "GPL",
    keywords = "rest nlp computational_linguistics rest",
    url = "https://github.com/LanguageMachines/PICCL",
    packages=['picclservice'],
    long_description="A set of workflows for OCR and post-correction",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Topic :: Internet :: WWW/HTTP :: WSGI :: Application",
        "Topic :: Text Processing :: Linguistic",
        "Programming Language :: Python :: 3.3", #3.0, 3.1 and 3.2 are not supported by flask
        "Programming Language :: Python :: 3.4", #3.0, 3.1 and 3.2 are not supported by flask
        "Programming Language :: Python :: 3.5", #3.0, 3.1 and 3.2 are not supported by flask
        "Operating System :: POSIX",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
    ],
    package_data = {'picclservice':['picclservice/*.wsgi','picclservice/*.yml'] },
    include_package_data=True,
    install_requires=['CLAM >= 3.0']
)
