## Process this file with automake to produce Makefile.in

SUFFIXES = .pod .pl .1 .3 .man .html .txt .pm .pdf .inc

AUTOMAKE_OPTIONS        =  foreign

#ACLOCAL_M4 = $(top_srcdir)/config/aclocal.m4

CLEANFILES = *.1 *.3 *.html *.txt *-dircache RRD?.pod *.pdf *~ core *itemcache *.rej *.orig *.tmp

POD = bin_dec_hex.pod        rrddump.pod            rrdgraph_examples.pod  rrdrestore.pod         rrdupdate.pod  \
      cdeftutorial.pod       rrdfetch.pod           rrdgraph_graph.pod     rrdthreads.pod         rrdxport.pod   \
      rpntutorial.pod        rrdfirst.pod           rrdgraph_rpn.pod       rrdtool.pod            rrdcached.pod  \
      rrd-beginners.pod      rrdinfo.pod            rrdtune.pod            rrdbuild.pod           rrdflushcached.pod   \
      rrdcgi.pod             rrdgraph.pod           rrdlast.pod            rrdlastupdate.pod                     \
      rrdcreate.pod          rrdgraph_data.pod      rrdresize.pod          rrdtutorial.pod

if BUILD_LIBDBI
  POD += rrdgraph_libdbi.pod
endif

if BUILD_LUA
  POD += rrdlua.pod
endif

POD3 = librrd.pod

PMP = RRDs.pod RRDp.pod

MAN = $(POD:.pod=.1)
MAN3 = $(POD3:.pod=.3)
TXT = $(MAN:.1=.txt) $(MAN3:.3=.txt)
HTML = $(POD:.pod=.html) $(POD3:.pod=.html) $(PMP:.pod=.html)
PDF = $(MAN:.1=.pdf) $(MAN3:.3=.pdf)

# what should go into the distribution
EXTRA_DIST= $(POD) $(POD3) $(HTML) $(MAN) $(MAN3) $(TXT) rrdtool-dump.dtd rrdtool-xport.dtd rrdgraph_libdbi.pod rrdlua.pod

idocdir = $(RRDDOCDIR)/txt
idoc_DATA = $(POD) $(TXT)
ihtmldir = $(RRDDOCDIR)/html
ihtml_DATA = $(HTML)
imandir = $(mandir)/man1
iman_DATA = $(MAN)
iman3dir = $(mandir)/man3
iman3_DATA = $(MAN3)

all-local: link man txt html-local

.src.pod:
	perl -n -e 'if (/^=include\s+(\S+)/){open F,"$$1.inc" || die $$?;print <F>; close F} else {print}'  $<  > $@

.pod.1 .pm.1 .pl.1:
	$(AM_V_GEN)@POD2MAN@ --release=$(VERSION) --center=rrdtool $<  > $@

.pod.3:
	$(AM_V_GEN)@POD2MAN@ --release=$(VERSION) --center=rrdtool --section=3 $< > $@

.1.txt .3.txt:
	$(AM_V_GEN)GROFF_NO_SGR=1 @NROFF@ -man -Tlp $< > $@

.1.pdf .3.pdf:
	$(AM_V_GEN)@TROFF@ -man $< | ps2pdf - $@

.pm.html .pod.html .pl.html:
	$(AM_V_GEN)@POD2HTML@ --infile=$< --outfile=$@ --noindex --htmlroot=. --podpath=. --title=$*

RRDs.pod:
	$(AM_V_GEN)$(LN_S) $(top_srcdir)/bindings/perl-shared/RRDs.pm RRDs.pod

RRDp.pod:
	$(AM_V_GEN)$(LN_S) $(top_srcdir)/bindings/perl-piped/RRDp.pm RRDp.pod

link: RRDp.pod RRDs.pod

man: $(MAN) $(MAN3)

html-local: $(HTML)

txt: $(TXT)

pdf-local: $(PDF)

pod: $(POD) $(POD3)

install-data-hook:
	$(AM_V_GEN)cd $(DESTDIR)$(ihtmldir) && rm -f index.html && $(LN_S) rrdtool.html index.html
