#!/bin/sh

TODAY=`date +%y%m%d`
NOW=`date +%s`
MAJOR_RELEASE="1"
MINOR_RELEASE="99"
SHORT_VERSION="$MAJOR_RELEASE.$MINOR_RELEASE"
VERSION="$SHORT_VERSION.$TODAY"


cat configure.seed | sed "s/@VERSION@/$VERSION/g" | sed "s/@SHORT_VERSION@/$SHORT_VERSION/g" > configure.ac

/bin/rm -f config.h config.h.in *~ #*

echo "Wait please..."
autoreconf -if
echo ""
echo "Now run ./configure"
