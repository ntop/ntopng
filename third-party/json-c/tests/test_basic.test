#!/bin/sh

# Common definitions
if test -z "$srcdir"; then
    srcdir="${0%/*}"
    test "$srcdir" = "$0" && srcdir=.
    test -z "$srcdir" && srcdir=.
fi
. "$srcdir/test-defs.sh"

filename=$(basename "$0")
filename="${filename%.*}"

# This is only for the test_util_file.test ;
# more stuff could be extended
cp -f "$srcdir/valid.json" .

run_output_test $filename "$srcdir"
exit $?
