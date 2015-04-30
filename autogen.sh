#!/bin/sh

TODAY=`date +%y%m%d`
NOW=`date +%s`
MAJOR_RELEASE="1"
MINOR_RELEASE="99"
VERSION="$MAJOR_RELEASE.$MINOR_RELEASE.$TODAY"

cat configure.seed | sed "s/@VERSION@/$VERSION/g" > configure.ac

autoreconf -ivf
echo ""
echo "Now run ./configure"
