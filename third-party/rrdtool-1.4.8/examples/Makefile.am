## Process this file with automake to produce Makefile.in

#AUTOMAKE_OPTIONS        =  foreign

#ACLOCAL_M4 = $(top_srcdir)/config/aclocal.m4

SUBDIRS = rrdcached

EXTRA_DIST = cgi-demo.cgi.in

examplesdir = $(pkgdatadir)/examples
examples_SCRIPTS = cgi-demo.cgi piped-demo.pl shared-demo.pl \
	stripes.pl bigtops.pl minmax.pl 4charts.pl perftest.pl

cgi-demo.cgi: @srcdir@/cgi-demo.cgi.in $(top_builddir)/config.status
	sed 's,@''exec_prefix@,$(exec_prefix),' @srcdir@/cgi-demo.cgi.in > $@
	chmod a+x $@

