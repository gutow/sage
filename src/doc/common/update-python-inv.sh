#!/usr/bin/env bash
# The file python-inv.txt contains the database of Sphinx hyperlink targets
# used by the intersphinx extension. See
#    http://sphinx.pocoo.org/latest/ext/intersphinx.html
# To be able to compile Sage without accessing the net, we use a local copy of
# this database. Here is how to update it:

rm -f python-inv.txt
wget http://docs.python.org/release/`sage -python --version 2>&1| cut -d " " --fields=2`/objects.inv -O - > python.inv
