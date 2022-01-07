#!/usr/bin/env bash


AUTOCONF=$(command -v autoconf)
AUTOMAKE=$(command -v automake)
LIBTOOL=$(command -v libtool)
LIBTOOLIZE=$(command -v libtoolize)
AUTORECONF=$(command -v autoreconf)
PKG_CONFIG=$(command -v pkg-config)

if test -z $AUTOCONF; then
    echo "autoconf is missing: please install it and try again"
    exit
fi

if test -z $AUTOMAKE; then
    echo "automake is missing: please install it and try again"
    exit
fi

if test -z $LIBTOOL && test -z $LIBTOOLIZE ; then
    echo "libtool and libtoolize is missing: please install it and try again"
    exit
fi

if test -z $AUTORECONF; then
    echo "autoreconf is missing: please install it and try again"
    exit
fi

if test -z $PKG_CONFIG; then
    echo "pkg-config is missing: please install it (apt-get install pkg-config) and try again"
    exit
fi

rm -f config.h config.h.in *~ #*

echo "Wait please..."
autoreconf -if
echo ""
echo "Now run ./configure"
