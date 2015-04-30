#!/bin/sh
autoreconf -v --install || exit 1

# If there are any options, assume the user wants to run configure.
# To run configure w/o any options, use ./autogen.sh --configure
if [ $# -gt 0 ] ; then
	case "$1" in
	--conf*)
		shift 1
		;;
	esac
    exec ./configure  "$@"
fi
