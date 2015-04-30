
include ../Makefile.am.inc

LIBJSON_LA=$(top_builddir)/libjson-c.la

check_PROGRAMS = test1 test1Formatted 
check_PROGRAMS += test2 test2Formatted
check_PROGRAMS += test4
check_PROGRAMS += testReplaceExisting
check_PROGRAMS += test_parse_int64
check_PROGRAMS += test_null
check_PROGRAMS += test_cast
check_PROGRAMS += test_parse
check_PROGRAMS += test_locale

test1_LDADD = $(LIBJSON_LA)

test1Formatted_LDADD= $(LIBJSON_LA)
test1Formatted_SOURCES = test1.c parse_flags.c
test1Formatted_CPPFLAGS = -DTEST_FORMATTED

test2_LDADD = $(LIBJSON_LA)

test2Formatted_LDADD= $(LIBJSON_LA)
test2Formatted_SOURCES = test2.c parse_flags.c
test2Formatted_CPPFLAGS = -DTEST_FORMATTED

test4_LDADD = $(LIBJSON_LA)

testReplaceExisting_LDADD = $(LIBJSON_LA)

test_parse_int64_LDADD = $(LIBJSON_LA)

test_null_LDADD = $(LIBJSON_LA)

test_cast_LDADD = $(LIBJSON_LA)

test_parse_LDADD = $(LIBJSON_LA)

test_locale_LDADD = $(LIBJSON_LA)

TESTS = test1.test test2.test test4.test testReplaceExisting.test parse_int64.test test_null.test test_cast.test test_parse.test test_locale.test

TESTS+= test_printbuf.test
check_PROGRAMS+=test_printbuf
test_printbuf_LDADD = $(LIBJSON_LA)

TESTS+= test_set_serializer.test
check_PROGRAMS += test_set_serializer
test_set_serializer_LDADD = $(LIBJSON_LA)

EXTRA_DIST=
EXTRA_DIST += $(TESTS)

testsubdir=testSubDir
TESTS_ENVIRONMENT       = top_builddir=$(top_builddir)

distclean-local:
	-rm -rf $(testsubdir)
