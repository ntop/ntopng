
EXTRA_DIST = README tclrrd.c

VERSION = @VERSION@

AM_CFLAGS = @CFLAGS@
### no including this by default @WERROR@

TCL_PREFIX = @TCL_PREFIX@
TCL_SHLIB_LD = @TCL_SHLIB_LD@
TCL_SHLIB_CFLAGS = @TCL_SHLIB_CFLAGS@
TCL_SHLIB_SUFFIX = @TCL_SHLIB_SUFFIX@
TCL_PACKAGE_PATH = @TCL_PACKAGE_PATH@
TCL_LD_SEARCH_FLAGS = @TCL_LD_SEARCH_FLAGS@
TCL_STUB_LIB_SPEC = @TCL_STUB_LIB_SPEC@
TCL_INCLUDE_SPEC = @TCL_INCLUDE_SPEC@

CLEANFILES = tclrrd.o tclrrd.so

SRC_DIR            = $(top_srcdir)/src
AM_CPPFLAGS        = $(TCL_INCLUDE_SPEC) -I$(SRC_DIR) -DUSE_TCL_STUBS
LIBDIRS            = -L$(top_builddir)/src/.libs -L$(top_builddir)/src -L$(libdir)
LIB_RUNTIME_DIR    = $(libdir)

if BUILD_TCL_SITE
tclpkgdir = @TCL_PACKAGE_DIR@
tclpkg_DATA = pkgIndex.tcl
tclpkg_SCRIPTS = ifOctets.tcl
else
pkgdata_DATA = pkgIndex.tcl
pkgdata_SCRIPTS = ifOctets.tcl
endif

# Automake doen't like `tclrrd$(VERSION)$(TCL_SHLIB_SUFFIX)' as
# library name. So we build and install this library `by hand'.
#
# We do, however, specify a lib_LIBRARIES target such that
# automake creates the directory (if neecessary).
#
TCL_RRD_LIB = tclrrd$(VERSION)$(TCL_SHLIB_SUFFIX)

lib_LIBRARIES =

all-local: $(TCL_RRD_LIB)

$(TCL_RRD_LIB): tclrrd.o
	$(TCL_SHLIB_LD) $(TCL_LD_SEARCH_FLAGS) $(LIBDIRS) $< -o $@ -lrrd_th -lm $(TCL_STUB_LIB_SPEC) $(LDFLAGS) $(LIBS)

tclrrd.o: tclrrd.c
	$(CC) $(AM_CFLAGS) $(CFLAGS) $(TCL_SHLIB_CFLAGS) $(AM_CPPFLAGS) -c tclrrd.c -DVERSION=\"$(VERSION)\"

pkgIndex.tcl:
	echo "package ifneeded Rrd $(VERSION) \"load $(libdir)/tclrrd$(VERSION)[info sharedlibextension]\"" > $@

install-exec-local: $(TCL_RRD_LIB)
	@$(NORMAL_INSTALL)
	$(INSTALL_PROGRAM) $(TCL_RRD_LIB) $(DESTDIR)$(libdir)/$(TCL_RRD_LIB)

