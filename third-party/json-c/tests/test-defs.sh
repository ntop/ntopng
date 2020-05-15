#!/bin/sh

if [ ! -z "$JSONC_TEST_TRACE" ] ; then
	VERBOSE=1
	set -x
	set -v
fi
# Make sure srcdir is an absolute path.  Supply the variable
# if it does not exist.  We want to be able to run the tests
# stand-alone!!
#
srcdir=${srcdir-.}
if test ! -d $srcdir ; then
    echo "test-defs.sh: installation error" 1>&2
    exit 1
fi

# Use absolute paths
case "$srcdir" in
    /* | [A-Za-z]:\\*) ;;
    *) srcdir=`\cd $srcdir && pwd` ;;
esac

case "$top_builddir" in
    /* | [A-Za-z]:\\*) ;;
    *) top_builddir=`\cd ${top_builddir-..} && pwd` ;;
esac

top_builddir=${top_builddir}/tests

progname=`echo "$0" | sed 's,^.*/,,'`
testname=`echo "$progname" | sed 's,-.*$,,'`
testsubdir=${testsubdir-testSubDir}
testsubdir=${testsubdir}/${progname}

# User can set VERBOSE to cause output redirection
case "$VERBOSE" in
[Nn]|[Nn][Oo]|0|"")
	VERBOSE=0
	exec > /dev/null
	;;
[Yy]|[Yy][Ee][Ss])
	VERBOSE=1
	;;
esac

rm -rf "$testsubdir" > /dev/null 2>&1
mkdir -p "$testsubdir"
CURDIR=$(pwd)
cd "$testsubdir" \
   || { echo "Cannot make or change into $testsubdir"; exit 1; }

echo "=== Running test $progname"

CMP="${CMP-cmp}"

use_valgrind=${USE_VALGRIND-1}
case "${use_valgrind}" in
	[0Nn]*)
		use_valgrind=0
		;;
	*)
		use_valgrind=1
		;;
esac
valgrind_path=$(which valgrind 2> /dev/null)
if [ -z "${valgrind_path}" -o ! -x "${valgrind_path}" ] ; then
	use_valgrind=0
fi

#
# This is a common function to check the results of a test program
# that is intended to generate consistent output across runs.
#
# ${top_builddir} must be set to the top level build directory.
#
# Output will be written to the current directory.
#
# It must be passed the name of the test command to run, which must be present
#  in the ${top_builddir} directory.
#
# It will compare the output of running that against <name of command>.expected
#
run_output_test()
{
	if [ "$1" = "-o" ] ; then
		TEST_OUTPUT="$2"
		shift
		shift
	fi
	TEST_COMMAND="$1"
	shift
	if [ -z "${TEST_OUTPUT}" ] ; then
		TEST_OUTPUT=${TEST_COMMAND}
	fi

	REDIR_OUTPUT="> \"${TEST_OUTPUT}.out\""
	if [ $VERBOSE -gt 1 ] ; then
		REDIR_OUTPUT="| tee \"${TEST_OUTPUT}.out\""
	fi

	if [ $use_valgrind -eq 1 ] ; then
		eval valgrind --tool=memcheck \
			--trace-children=yes \
			--demangle=yes \
			--log-file="${TEST_OUTPUT}.vg.out" \
			--leak-check=full \
			--show-reachable=yes \
			--run-libc-freeres=yes \
		"\"${top_builddir}/${TEST_COMMAND}\"" \"\$@\" ${REDIR_OUTPUT}
		err=$?

	else
		eval "\"${top_builddir}/${TEST_COMMAND}"\" \"\$@\" ${REDIR_OUTPUT}
		err=$?
	fi

	if [ $err -ne 0 ] ; then
		echo "ERROR: \"${TEST_COMMAND} $@\" exited with non-zero exit status: $err" 1>&2
	fi

	if [ $use_valgrind -eq 1 ] ; then
		if ! tail -1 "${TEST_OUTPUT}.vg.out" | grep -q "ERROR SUMMARY: 0 errors" ; then
			echo "ERROR: valgrind found errors during execution:" 1>&2
			cat "${TEST_OUTPUT}.vg.out"
			err=1
		fi
	fi

	if ! "$CMP" -s "${srcdir}/${TEST_OUTPUT}.expected" "${TEST_OUTPUT}.out" ; then
		echo "ERROR: \"${TEST_COMMAND} $@\" (${TEST_OUTPUT}) failed (set VERBOSE=1 to see full output):" 1>&2
		(cd "${CURDIR}" ; set -x ; diff "${srcdir}/${TEST_OUTPUT}.expected" "$testsubdir/${TEST_OUTPUT}.out")
		echo "cp \"$testsubdir/${TEST_OUTPUT}.out\" \"${srcdir}/${TEST_OUTPUT}.expected\"" 1>&2

		err=1
	fi

	return $err
}
