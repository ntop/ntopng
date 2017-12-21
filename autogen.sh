#!/usr/bin/env bash

TODAY=`date +%y%m%d`
NOW=`date +%s`
MAJOR_RELEASE="3"
MINOR_RELEASE="3"
SHORT_VERSION="$MAJOR_RELEASE.$MINOR_RELEASE"
VERSION="$SHORT_VERSION.$TODAY"

if test -d ".git"; then :
GIT_TAG=`git rev-parse HEAD`
GIT_DATE=`date +%Y%m%d`
GIT_RELEASE="$GIT_TAG:$GIT_DATE"
GIT_BRANCH=`git rev-parse --abbrev-ref HEAD | sed "s/heads\///g"`
else
GIT_RELEASE="$VERSION"
GIT_DATE=`date`
GIT_BRANCH=""
fi

if test -d "pro"; then :
PRO_GIT_RELEASE=`cd pro; git log --pretty=oneline | wc -l`
PRO_GIT_RELEASE=${PRO_GIT_RELEASE//[[:blank:]]/}
PRO_GIT_DATE=`cd pro; git log --pretty=medium -1 | grep "^Date:"|cut -d " " -f 4-`
else
PRO_GIT_RELEASE=""
PRO_GIT_DATE=""
fi

cat configure.seed | sed "s/@VERSION@/$VERSION/g" | sed "s/@SHORT_VERSION@/$SHORT_VERSION/g" | sed "s/@GIT_TAG@/$GIT_TAG/g" | sed "s/@GIT_DATE@/$GIT_DATE/g" | sed "s/@GIT_RELEASE@/$GIT_RELEASE/g" | sed "s/@GIT_BRANCH@/$GIT_BRANCH/g"  | sed "s/@PRO_GIT_RELEASE@/$PRO_GIT_RELEASE/g" | sed "s/@PRO_GIT_DATE@/$PRO_GIT_DATE/g" > configure.ac

/bin/rm -f config.h config.h.in *~ #*

echo "Wait please..."
autoreconf -if
echo ""
echo "Now run ./configure"
