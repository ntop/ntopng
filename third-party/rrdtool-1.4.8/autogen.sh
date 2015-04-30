#!/bin/bash

# On MAC OS X, GNU libtoolize is named 'glibtoolize':
if [ `(uname -s) 2>/dev/null` == 'Darwin' ]
then
	glibtoolize
else
	libtoolize
fi

autoreconf --force --install --verbose -I m4
