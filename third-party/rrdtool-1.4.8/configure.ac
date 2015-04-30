dnl RRDtool AutoConf script ... 
dnl ---------------------------
dnl $Id$
dnl
dnl Created by Jeff Allen, Tobi Oetiker, Blair Zajac
dnl
dnl Inspiration from http://autoconf-archive.cryp.to
 
dnl tell automake the this script is for rrdtool

dnl Minimum Autoconf version required.
AC_PREREQ(2.59)

dnl the official version number is
dnl a.b.c
AC_INIT([rrdtool],[1.4.8])

dnl for testing a numberical version number comes handy
dnl the released version are
dnl a.bccc
dnl the devel versions will be something like
dnl a.b999yymmddhh 
NUMVERS=1.4008
AC_SUBST(NUMVERS)

dnl for the linker to understand which versions the library are compatible with
dnl each other we must keep a separate library version cout of the format c:r:a.
dnl - if only implementation changed but all interfaces are kept, do r++
dnl - if only functionality was added do c++,r=0,a++
dnl - if any functionality was removed do c++,r=0,a=0.
dnl
dnl see http://sourceware.org/autobook/autobook/autobook_91.html
dnl 
LIBVERS=6:1:2
AC_SUBST(LIBVERS)

AC_CANONICAL_TARGET
m4_version_prereq(2.60, [AC_USE_SYSTEM_EXTENSIONS], [#])
AM_INIT_AUTOMAKE
AM_MAINTAINER_MODE
# Enable silent build rules by default, requires at least
# Automake-1.11. Disable by either passing --disable-silent-rules to
# configure or passing V=1 to make
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])
AC_CONFIG_HEADERS([rrd_config.h])
AC_CONFIG_MACRO_DIR([m4])

dnl all our local stuff like install scripts and include files
dnl is in there


dnl determine the type of system we are running on

AC_SUBST(VERSION)

AC_PREFIX_DEFAULT( /opt/rrdtool-$PACKAGE_VERSION )

dnl At the TOP of the HEADER

AH_TOP([
#ifndef RRD_CONFIG_H
#define RRD_CONFIG_H

/* IEEE can be prevented from raising signals with fpsetmask(0) */
#undef MUST_DISABLE_FPMASK

/* IEEE math only works if SIGFPE gets actively set to IGNORE */
#undef MUST_DISABLE_SIGFPE

/* realloc does not support NULL as argument */
#undef NO_NULL_REALLOC

/* lets enable madvise defines in NetBSD */ 
#if defined(__NetBSD__)
# if !defined(_NETBSD_SOURCE)
#  define _NETBSD_SOURCE
# endif
#endif

])

AH_BOTTOM([

#ifdef MUST_HAVE_MALLOC_MALLOC_H
#  include <malloc/malloc.h>
#endif

#include "src/rrd_config_bottom.h"

#endif
])

dnl Process Special Options
dnl -----------------------------------

dnl How the vertical axis label is printed
AC_ARG_VAR(RRDGRAPH_YLEGEND_ANGLE, 
 [Vertical label angle: -90.0 (default) or 90.0])
AC_DEFINE_UNQUOTED(RRDGRAPH_YLEGEND_ANGLE,${RRDGRAPH_YLEGEND_ANGLE:-90.0},
 [Vertical label angle: -90.0 (default) or 90.0])

AC_ARG_ENABLE(rrdcgi,AS_HELP_STRING([--disable-rrdcgi],[disable building of rrdcgi]),
[],[enable_rrdcgi=yes])

AM_CONDITIONAL(BUILD_RRDCGI,[test $enable_rrdcgi != no])

AC_ARG_ENABLE(rrd_graph,AS_HELP_STRING([--disable-rrd_graph],[disable all rrd_graph functions]),
[enable_rrdcgi=no],[enable_rrd_graph=yes])

if test $enable_rrd_graph != no; then
 AC_DEFINE([HAVE_RRD_GRAPH], [], [is rrd_graph supported by this install])
fi

dnl Check if we run on a system that has fonts
AC_ARG_WITH(rrd-default-font,
[  --with-rrd-default-font=[OPTIONS]  set the full path to your default font.],
[RRD_DEFAULT_FONT=$withval],[
  if test -d ${WINDIR:-nodir}/cour.ttf ; then
	RRD_DEFAULT_FONT=`cd $WINDIR;pwd`/cour.ttf
  else
	RRD_DEFAULT_FONT='"DejaVu Sans Mono,Bitstream Vera Sans Mono,monospace,Courier"'
  fi
])

dnl Use mmap in rrd_update instead of seek+write
AC_ARG_ENABLE([mmap],
AS_HELP_STRING([--disable-mmap],[disable mmap in rrd_update, use seek+write instead]),
[],
[enable_mmap=yes])

AC_ARG_ENABLE(pthread,AS_HELP_STRING([--disable-pthread],[disable multithread support]),
[],[enable_pthread=yes])

AC_ARG_ENABLE(static-programs,
     AS_HELP_STRING([--enable-static-programs],[Build static programs]),
     [case "${enableval}" in
       yes) staticprogs=yes ;;
       no)  staticprogs=no ;;
       *) AC_MSG_ERROR(bad value ${enableval} for --enable-static-programs) ;;
     esac],[staticprogs=no])
AM_CONDITIONAL(STATIC_PROGRAMS,[test "x$staticprogs" = "xyes"])


CONFIGURE_PART(Audit Compilation Environment)


dnl Check for the compiler and static/shared library creation.
AC_PROG_CPP
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_LIBTOOL

dnl Try to detect/use GNU features
CFLAGS="$CFLAGS -D_GNU_SOURCE"

dnl check for -Werror separatly
dnl (quite a few autotool checks do not work with -Werror; also, the
dnl check for -Werror fails after checking and adding the other flags)
AC_CACHE_CHECK([if gcc likes the -Werror flag], rd_cv_gcc_flag__Werror,
  [AC_COMPILE_IFELSE(
    [AC_LANG_PROGRAM([[]], [[return 0 ]])],
    [rd_cv_gcc_flag__Werror="yes"],
    [rd_cv_gcc_flag__Werror="no"])])
if test "x$rd_cv_gcc_flag__Werror" = "xyes"; then
  WERROR="-Werror"
else
  WERROR=""
fi
AC_SUBST(WERROR)

dnl which flags does the compiler support?
if test "x$GCC" = "xyes"; then
  for flag in -fno-strict-aliasing -Wall -std=gnu99 -pedantic -Wundef -Wshadow -Wpointer-arith -Wcast-align -Wmissing-prototypes -Wmissing-declarations -Wnested-externs -Winline -Wold-style-definition -W; do
    oCFLAGS="$CFLAGS"
    CFLAGS="$CFLAGS $flag"
    cachename=rd_cv_gcc_flag_`echo $flag|sed 's/[[^A-Za-z]]/_/g'`
    AC_CACHE_CHECK([if gcc likes the $flag flag], $cachename,
       [AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[]], [[return 0 ]])],[eval $cachename=yes],[eval $cachename=no])])
    if eval test \$$cachename = no; then
         CFLAGS="$oCFLAGS"
    fi
  done
fi



AC_SUBST(RRD_DEFAULT_FONT)

CONFIGURE_PART(Checking for Header Files)
 
dnl Checks for header files.
AC_HEADER_STDC
AC_HEADER_DIRENT
AC_CHECK_HEADERS(langinfo.h stdint.h inttypes.h libgen.h features.h sys/stat.h sys/types.h fcntl.h fp_class.h malloc.h unistd.h ieeefp.h math.h sys/times.h sys/param.h sys/resource.h signal.h float.h stdio.h stdlib.h errno.h string.h ctype.h)

dnl Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST
AC_HEADER_TIME
AC_STRUCT_TM

CONFIGURE_PART(Test Library Functions)

dnl Checks for libraries.
AC_CHECK_FUNC(acos, , AC_CHECK_LIB(m, acos))


dnl add pic flag in any case this makes sure all our code is relocatable
eval `./libtool --config | grep pic_flag=` 
CFLAGS="$CFLAGS $pic_flag"


dnl Checks for library functions.
AC_FUNC_STRFTIME
AC_FUNC_VPRINTF

AC_C_BIGENDIAN

dnl for each function found we get a definition in config.h 
dnl of the form HAVE_FUNCTION

AC_CHECK_FUNCS(nl_langinfo tzset round rint fsync mbstowcs opendir readdir chdir chroot getuid strerror snprintf vsnprintf vasprintf fpclass class fp_class isnan memmove strchr mktime getrusage gettimeofday)

AC_FUNC_STRERROR_R

CONFIGURE_PART(Map/Fadvis/Madvise checking)

dnl Could use these to know if we need to provide a prototype
dnl AC_CHECK_DECLS(fdatasync, [], [], [#include <unistd.h>])

dnl check for fdatasync. Solaris has fdatasync in the librt

AC_CHECK_FUNCS(fdatasync, [],  AC_CHECK_LIB(rt, fdatasync, [LIBS="${LIBS} -lrt"; AC_DEFINE(HAVE_FDATASYNC)],[]))
dnl if there is no fdatasync we may get lucky with fsync
AC_CHECK_FUNCS(fsync)

dnl check for socket and nsl solaris again ... we need this for the new rrd_daemon stuff

AC_CHECK_FUNCS(socket, [],  AC_CHECK_LIB(socket, socket, [LIBS="${LIBS} -lsocket"; AC_DEFINE(HAVE_SOCKET)],[]))
AC_CHECK_FUNCS(getaddrinfo, [],  AC_CHECK_LIB(nsl, getaddrinfo, [LIBS="${LIBS} -lnsl"; AC_DEFINE(HAVE_GETADDRINFO)],[]))



dnl XXX: dunno about windows.. add AC_CHECK_FUNCS(munmap) there too?
if test "x$enable_mmap" = "xyes"; then
  case "$host" in
  *cygwin*)
    # the normal mmap test does not work in cygwin
    AC_CHECK_FUNCS(mmap)
    if test "x$ac_cv_func_mmap" = "xyes"; then
      ac_cv_func_mmap_fixed_mapped=yes
    fi
  ;;
  *)
    AC_CHECK_HEADERS(sys/mman.h)
    AC_FUNC_MMAP
    AC_CHECK_FUNCS(mmap munmap msync)
    AC_CHECK_DECLS(madvise, [], [], [#ifdef HAVE_SYS_MMAN_H
				     # include <sys/mman.h>
				     #endif])
    if test "x$ac_cv_have_decl_madvise" = "xyes";
    then
      AC_CHECK_FUNCS(madvise)
    else
      AC_CHECK_FUNCS(posix_madvise)
      if test "x$ac_cv_func_posix_madvise" != "xyes"; then
        AC_MSG_WARN([madvise() nor posix_madvise() found.])
      fi
    fi
  ;;
  esac
  if test "x$ac_cv_func_mmap" != "xyes";
  then
    AC_MSG_ERROR([--enable-mmap requested but mmap() was not detected])
dnl enable_mmap="no"
  fi
fi

dnl can we use posix_fadvise
AC_CHECK_DECLS(posix_fadvise, [], [], [#define _XOPEN_SOURCE 600
#include <fcntl.h>])
AC_CHECK_FUNCS(posix_fadvise)

dnl can we use posix_fallocate
AC_CHECK_FUNCS(posix_fallocate)

CONFIGURE_PART(Libintl Processing)

AM_GNU_GETTEXT_VERSION(0.17)
AM_GNU_GETTEXT(external)

CONFIGURE_PART(IEEE Math Checks)
 

dnl actual code to check if this works
AC_CHECK_FUNCS(fpclassify, ,
  [AC_MSG_CHECKING(for fpclassify with <math.h>)
    AC_LINK_IFELSE([AC_LANG_PROGRAM([[#include <math.h>
volatile int x;volatile float f; ]], [[x = fpclassify(f)]])],[AC_MSG_RESULT(yes)
      AC_DEFINE(HAVE_FPCLASSIFY)],[AC_MSG_RESULT(no)])])

AC_CHECK_FUNCS(isinf, ,
  [AC_MSG_CHECKING(for isinf with <math.h>)
    AC_LINK_IFELSE([AC_LANG_PROGRAM([[#include <math.h>
volatile int x;volatile float f;  ]], [[x = isinf(f)]])],[AC_MSG_RESULT(yes)
      AC_DEFINE(HAVE_ISINF)],[AC_MSG_RESULT(no)])])

dnl finite is BSD, isfinite is C99, so prefer the latter
AC_CACHE_CHECK([whether isfinite is broken],[ac_cv_have_broken_isfinite],[
AC_TRY_RUN([
#ifdef HAVE_MATH_H
#include <math.h>
#endif
#ifdef HAVE_FLOAT_H
#include <float.h>
#endif
int main ()
{
#ifdef isfinite
#ifdef LDBL_MAX
  if (!isfinite(LDBL_MAX)) return 1;
#endif
#ifdef DBL_MAX
  if (!isfinite(DBL_MAX)) return 1;
#endif
#endif
return 0;
}],[ac_cv_have_broken_isfinite=no],[ac_cv_have_broken_isfinite=yes],[
case "${target}" in
  hppa*-*-hpux*) ac_cv_have_broken_isfinite=yes ;;
  *-solaris2.8) ac_cv_have_broken_isfinite=yes ;;
  *-solaris2.9) ac_cv_have_broken_isfinite=yes ;;
  *) ac_cv_have_broken_isfinite=no ;;
esac])
])

dnl the test does not seem to work on solaris 2.8
dnl so lets fix this by hand
case "${target}" in
  *-solaris2.8) ac_cv_have_broken_isfinite=yes ;;
  *-solaris2.9) ac_cv_have_broken_isfinite=yes ;;
esac

if test "x$ac_cv_have_broken_isfinite" = "xno"; then
  AC_DEFINE(HAVE_ISFINITE)
else
  AC_CHECK_FUNCS(finite,[],
      [AC_CHECK_FUNCS(isfinite,[],
         [AC_MSG_CHECKING(for isfinite with <math.h>)
          AC_LINK_IFELSE([AC_LANG_PROGRAM([[#include <math.h>
volatile int x;volatile float f;  ]],[[x = isfinite(f)]])],[AC_MSG_RESULT(yes)
	        AC_DEFINE(HAVE_ISFINITE)],[AC_MSG_RESULT(no)])])])
fi  

AC_FULL_IEEE

CONFIGURE_PART(Resolve Portability Issues)

GC_TIMEZONE()

CHECK_FOR_WORKING_MS_ASYNC

dnl do we have nl_langinfo(_NL_TIME_WEEK_1STDAY)
AC_CHECK_FUNCS(_NL_TIME_WEEK_1STDAY, ,
  [AC_MSG_CHECKING([for nl_langinfo(_NL_TIME_WEEK_1STDAY) with langinfo.h])
    AC_LINK_IFELSE([AC_LANG_PROGRAM([[#include <langinfo.h>]], [[nl_langinfo(_NL_TIME_WEEK_1STDAY)]])],[AC_MSG_RESULT(yes)
      AC_DEFINE(HAVE__NL_TIME_WEEK_1STDAY)],[AC_MSG_RESULT(no)])])

dnl Do we need getopt_long

dnl even when including our own getopt implementation
dnl we may want to make sure we use the external
dnl defined by libc to not run into linker resolve trouble

AC_CACHE_CHECK([for opterr], rd_cv_var_int_opterr,
[AC_TRY_LINK([#include <unistd.h>],
  [extern int opterr; opterr = 1;],
  [rd_cv_var_int_opterr=yes],
  [rd_cv_var_int_opterr=no])])
if test x"$rd_cv_var_int_opterr" = x"yes"; then
  AC_DEFINE(HAVE_INT_OPTERR, 1, [Define to 1 if you have the global variable 'int opterr'.])
fi

build_getopt=no
RRD_GETOPT_LONG="LIBC_HAS_GETOPT_LONG"
AC_CHECK_FUNC(getopt_long,[],[
RRD_GETOPT_LONG="getopt_long"
build_getopt=yes
])
AC_SUBST(RRD_GETOPT_LONG)
AM_CONDITIONAL(BUILD_GETOPT,[test $build_getopt = yes])

dnl what does realloc do if it gets called with a NULL pointer

AC_CACHE_CHECK([if realloc can deal with NULL], rd_cv_null_realloc,
[AC_RUN_IFELSE([AC_LANG_SOURCE([[#include <stdlib.h>
	      int main(void){
              char *x = NULL;
	      x = realloc (x,10);
	      if (x==NULL) return 1;
	      return 0;
             }]])],[rd_cv_null_realloc=yes],[rd_cv_null_realloc=nope],[:])])

if test x"$rd_cv_null_realloc" = xnope; then
AC_DEFINE(NO_NULL_REALLOC)
fi

AC_LANG_PUSH(C)
dnl solaris has some odd defines it needs in order to propperly compile ctime_r
AC_MSG_CHECKING([if ctime_r need special care to act posixly correct])
AC_LINK_IFELSE(
    AC_LANG_PROGRAM(
           [[#include <time.h>]],
           [[ctime_r(NULL,NULL,0)]]
                   ),
    [ CPPFLAGS="$CPPFLAGS -D_POSIX_PTHREAD_SEMANTICS"
      AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                [[#include <time.h>]],
                [[ctime_r(NULL,NULL)]]
    	                 ),
          [AC_MSG_RESULT([yes, this seems to be solaris style])],
          [AC_MSG_ERROR([Can't figure how to compile ctime_r])]
      )
    ],  
    [ AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                [[#include <time.h>]],
                [[ctime_r(NULL,NULL)]]
    	                 ),
          [AC_MSG_RESULT(no)],
          [AC_MSG_ERROR([Can't figure how to compile ctime_r])]
      )
    ]  
)
AC_LANG_POP(C)

dnl Check for pthreads
dnl http://autoconf-archive.cryp.to/acx_pthread.m4
 
AC_SUBST(MULTITHREAD_CFLAGS)
AC_SUBST(MULTITHREAD_LDFLAGS)

if test $enable_pthread != no; then 
 ACX_PTHREAD([
    MULTITHREAD_CFLAGS=$PTHREAD_CFLAGS
    MULTITHREAD_LDFLAGS=$PTHREAD_LIBS
	     ],
	     [])
fi

dnl since we use lots of *_r functions all over the code we better
dnl make sure they are known

if test  "x$x_rflag" != "xno"; then
   CPPFLAGS="$CPPFLAGS $x_rflag"
fi

AM_CONDITIONAL(BUILD_MULTITHREAD,[test $enable_pthread != no])

AC_LANG_PUSH(C)
dnl see if we have to include malloc/malloc.h
AC_MSG_CHECKING([do we need malloc/malloc.h])
AC_LINK_IFELSE(
    AC_LANG_PROGRAM(
           [[#include <stdlib.h>]],
           [[malloc(1)]]
                   ),
    [ AC_MSG_RESULT([nope, works out of the box]) ],
    [ AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                [[#include <stdlib.h>
                  #include <malloc/malloc.h>]],
                [[malloc(1)]]
    	                 ),[
           AC_DEFINE([MUST_HAVE_MALLOC_MALLOC_H])
           AC_MSG_RESULT([yes we do])],
          [AC_MSG_ERROR([Can not figure how to compile malloc])]
      )
    ]  
)
AC_LANG_POP(C)

dnl is time_t 32 of 64 bit ?
AC_CHECK_SIZEOF([time_t])

CONFIGURE_PART(Find 3rd-Party Libraries)

have_libdbi=no

AC_ARG_ENABLE(libdbi,AS_HELP_STRING([--disable-libdbi],[do not build in support for libdbi]),[],[
    AC_CHECK_HEADER(dbi/dbi.h, [ 
       AC_CHECK_LIB(dbi, dbi_initialize, [
           AC_DEFINE(HAVE_LIBDBI,[1],[have got libdbi installed])
           LIBS="${LIBS} -ldbi -ldl"
           have_libdbi=yes
       ])
    ])
])

AM_CONDITIONAL(BUILD_LIBDBI,[test $have_libdbi != no])

have_libwrap=no

AC_ARG_ENABLE(libwrap, AS_HELP_STRING([--disable-libwrap], [do not build in support for libwrap (tcp wrapper)]),[],[ 
    AC_CHECK_HEADER(tcpd.h,[       
        AC_CHECK_FUNCS(hosts_access, [
            AC_DEFINE(HAVE_LIBWRAP,[1],[have got libwrap installed])
            have_libwrap=yes 
        ],  
        [
            AC_CHECK_LIB(wrap, hosts_access, [
               AC_DEFINE(HAVE_LIBWRAP,[1],[have got libwrap installed])
               LIBS="${LIBS} -lwrap"
               have_libwrap=yes
            ])
        ])
    ])
])


AM_CONDITIONAL(BUILD_LIBWRAP,[test $have_libwrap != no])

AM_CONDITIONAL(BUILD_RRDGRAPH,[test $enable_rrd_graph != no])


CORE_LIBS="$LIBS"

if test $enable_rrd_graph != no; then
dnl EX_CHECK_ALL(z,          zlibVersion,               zlib.h,                 zlib,        1.2.5,  http://zlib.net/, "")
dnl EX_CHECK_ALL(png,        png_access_version_number, png.h,                  libpng,      1.4.8,  ftp://ftp.simplesystems.org/pub/libpng/png/src/, "")
dnl EX_CHECK_ALL(freetype,   FT_Init_FreeType,          ft2build.h,		freetype2,   2.4.6,  http://download.savannah.gnu.org/releases/freetype/, /usr/include/freetype2)
dnl EX_CHECK_ALL(fontconfig, FcInit,                    fontconfig.h,		fontconfig,  2.8.0,  http://www.freedesktop.org/software/fontconfig/release/, /usr/include)
EX_CHECK_ALL(cairo,      cairo_font_options_create,     cairo.h,                cairo-png,   1.10.2,  http://cairographics.org/releases/, "")
EX_CHECK_ALL(cairo,      cairo_svg_surface_create,      cairo-svg.h,            cairo-svg,   1.10.2,  http://cairographics.org/releases/, "")
EX_CHECK_ALL(cairo,      cairo_pdf_surface_create,      cairo-pdf.h,            cairo-pdf,   1.10.2,  http://cairographics.org/releases/, "")
EX_CHECK_ALL(cairo,      cairo_ps_surface_create,       cairo-ps.h,             cairo-ps,    1.10.2,  http://cairographics.org/releases/, "")
EX_CHECK_ALL(pangocairo-1.0,  pango_cairo_context_set_font_options,  pango/pango.h,  pangocairo,  1.28.4,    http://ftp.gnome.org/pub/GNOME/sources/pango/1.28, "")

fi
EX_CHECK_ALL(glib-2.0,   glib_check_version,            glib.h,                 glib-2.0,    2.28.7, ftp://ftp.gtk.org/pub/glib/2.28/, "")
EX_CHECK_ALL(xml2,       xmlParseFile,                  libxml/parser.h,        libxml-2.0,        2.7.8,  http://xmlsoft.org/downloads.html, /usr/include/libxml2)

if test "$EX_CHECK_ALL_ERR" = "YES"; then
  AC_MSG_ERROR([Please fix the library issues listed above and try again.])
fi

ALL_LIBS="$LIBS"
LIBS=

AC_SUBST(CORE_LIBS)
AC_SUBST(ALL_LIBS)

CONFIGURE_PART(Prep for Building Language Bindings)
  
dnl Check for Perl and friends
PATH=$PATH:/usr/perl5/bin
export PATH
AC_PATH_PROG(PERL, perl, no)
AC_PATH_PROG(POD2MAN, pod2man, no)
AC_PATH_PROG(POD2HTML, pod2html, no)


AC_ARG_ENABLE(perl,AS_HELP_STRING([--disable-perl],[do not build the perl modules]),
[],[enable_perl=yes])


AC_ARG_VAR(PERLCC, [C compiler for Perl modules])
AC_ARG_VAR(PERLCCFLAGS, [CC flags for Perl modules])
AC_ARG_VAR(PERLLD, [Linker for Perl modules])
AC_ARG_VAR(PERLLDFLAGS, [LD flags for Perl modules])

if test "x$PERL" = "xno" -o  x$enable_perl = xno; then
	COMP_PERL=
else
	COMP_PERL="perl_piped perl_shared"
        AC_MSG_CHECKING(for the perl version you are running)
	PERL_VERSION=`$PERL -MConfig -e 'print $Config{version}'`
	AC_MSG_RESULT($PERL_VERSION)
        if test -z "$PERLCC"; then
            AC_MSG_CHECKING(for the C compiler perl wants to use to build its modules)
	    perlcc=`$PERL -MConfig -e 'print $Config{cc}'`
	    AC_MSG_RESULT($perlcc)
	    if test ! -x "$perlcc"; then
 	        AC_PATH_PROG(PERL_CC, ${perlcc}, no)
	        if test "$PERL_CC" = "no"; then
                    AC_MSG_WARN([
I would not find the Compiler ($perlcc) that was originally used to compile
your perl binary. You should either make sure that this compiler is
available on your system, pick an other compiler and set PERLCC
appropriately, or use a different perl setup that was compiled locally.

I will disable the compilation of the RRDs perl module for now.
])
  		    COMP_PERL="perl_piped"
	        fi
            fi    
        fi
fi

AC_MSG_CHECKING(Perl Modules to build)
AC_MSG_RESULT(${COMP_PERL:-No Perl Modules will be built})

# Options to pass when configuring perl module
langpref=$prefix
test "$langpref" = '$(DESTDIR)NONE' && langpref='$(DESTDIR)'$ac_default_prefix
test "$langpref" = "NONE" && langpref=$ac_default_prefix

PERL_MAKE_OPTIONS="PREFIX=$langpref INSTALL_BASE= LIB=$langpref/lib/perl/$PERL_VERSION"

dnl pass additional perl options when generating Makefile from Makefile.PL
AC_ARG_ENABLE(perl-site-install,
AS_HELP_STRING([--enable-perl-site-install],[by default the rrdtool perl modules are installed together with rrdtool in $prefix/lib/perl. You have to put a 'use lib qw($prefix/lib/perl)' into your scripts when you want to use them. When you set this option the perl modules will get installed wherever your perl setup thinks it is best.]),
[PERL_MAKE_OPTIONS=],[])

if test ! -z "$PERLCC"; then
   PERL_MAKE_OPTIONS="$PERL_MAKE_OPTIONS CC=$PERLCC"

   if test ! -z "$PERLCCFLAGS"; then
       PERL_MAKE_OPTIONS="$PERL_MAKE_OPTIONS CCFLAGS=$PERLCCFLAGS"
   fi
   
   if test -z "$PERLLD"; then
       PERLLD=$PERLCC
   fi
   PERL_MAKE_OPTIONS="$PERL_MAKE_OPTIONS LD=$PERLLD"
  
   if test ! -z "$PERLLDFLAGS"; then
       PERL_MAKE_OPTIONS="$PERL_MAKE_OPTIONS LDFLAGS=$PERLLDFLAGS"
   fi
fi
        
AC_ARG_WITH(perl-options,
[  --with-perl-options=[OPTIONS]  options to pass on command-line when
                          generating Makefile from Makefile.PL. If you set this
                          option, interesting things may happen unless you know
                          what you are doing!],
[PERL_MAKE_OPTIONS=$withval])

AC_SUBST(PERL_MAKE_OPTIONS)
AC_SUBST(PERL)
AC_SUBST(COMP_PERL)
AC_SUBST(PERL_VERSION)

dnl Check for Ruby.
AC_PATH_PROG(RUBY, ruby, no)

AC_ARG_ENABLE(ruby,AS_HELP_STRING([--disable-ruby],[do not build the ruby modules]),
[],[enable_ruby=yes])

AC_MSG_CHECKING(if ruby modules can be built)

if test "x$RUBY" = "xno" -o  x$enable_ruby = xno; then
	COMP_RUBY=
 	AC_MSG_RESULT(No .. Ruby not found or disabled)
else
	if $RUBY -e 'require "mkmf"' >/dev/null 2>&1; then
		COMP_RUBY="ruby"
	 	AC_MSG_RESULT(YES)
	else
		COMP_RUBY=
	 	AC_MSG_RESULT(Ruby found but mkmf is missing! Install the -dev package)		
	fi				
fi

dnl pass additional ruby options when generating Makefile from Makefile.PL
AC_ARG_ENABLE(ruby-site-install,
AS_HELP_STRING([--enable-ruby-site-install],[by default the rrdtool ruby modules are installed together with rrdtool in $prefix/lib/ruby. You have to add $prefix/lib/ruby/$ruby_version/$sitearch to your $: variable for ruby to find the RRD.so file.]),
[RUBY_MAKE_OPTIONS=],[RUBY_MAKE_OPTIONS="sitedir=$langpref/lib/ruby"])

    
AC_ARG_WITH(ruby-options,
[  --with-ruby-options=[OPTIONS]  options to pass on command-line when
                          generating Makefile from extconf.rb. If you set this
                          option, interesting things may happen unless you know
                          what you are doing!],
[RUBY_MAKE_OPTIONS=$withval])

AC_SUBST(RUBY_MAKE_OPTIONS)
AC_SUBST(RUBY)
AC_SUBST(COMP_RUBY)

dnl Check for Lua.
AC_PATH_PROG(LUA, lua, no)

AC_ARG_ENABLE(lua,AS_HELP_STRING([--disable-lua],[do not build the lua modules]),
[],[enable_lua=yes])

COMP_LUA=
if test "$LUA" = "no" -o "$enable_lua" = "no"; then
  enable_lua=no
else
  AC_MSG_CHECKING(for lua >= 5.0)
  read LUA_MAJOR LUA_MINOR LUA_POINT <<LUA_EOF
    $($LUA -v 2>&1 | cut -f2 -d' ' | sed -e 's/\./ /g')
LUA_EOF
  if test 0$LUA_MAJOR -lt 5; then
    AC_MSG_RESULT([no, version found is $LUA_MAJOR.$LUA_MINOR])
  else
    AC_MSG_RESULT([$LUA_MAJOR.$LUA_MINOR found])
    lua_vdot=$LUA_MAJOR.$LUA_MINOR
    lua_vndot=$LUA_MAJOR$LUA_MINOR
    lua_version=$LUA_MAJOR.$LUA_MINOR.$LUA_POINT
    AC_CHECK_HEADERS(lua$lua_vndot/lua.h,
      [AC_CHECK_HEADERS(lua$lua_vndot/lualib.h,
        [AC_CHECK_HEADER(lua$lua_vndot/lauxlib.h,
          [lua_headerdir=lua$lua_vndot],
          [])],
        [])],
      [AC_CHECK_HEADERS(lua$lua_vdot/lua.h,
        [AC_CHECK_HEADERS(lua$lua_vdot/lualib.h,
          [AC_CHECK_HEADER(lua$lua_vdot/lauxlib.h,
            [lua_headerdir=lua$lua_vdot],
            [])],
          [])],
        [AC_CHECK_HEADERS(lua.h,
          [AC_CHECK_HEADERS(lualib.h,
            [AC_CHECK_HEADER(lauxlib.h,
              [lua_headerdir=""],
              [lua_headerdir="no"])],
            [])],
          [])])])

    if test "$lua_headerdir" = "no"; then
      enable_lua=no
    else
      COMP_LUA=lua
    fi

    if test "$COMP_LUA" != "lua"; then
      enable_lua=no
      AC_MSG_WARN([Lua $lua_vdot found but not lua.h, lualib.h and lauxlib.h! Please install the -dev packages for Lua $lua_vdot])
    else
      # OK, headers found, let's check the libraries (LIBS is not used)
      LIBS=
      lua_havelib=no
      LUA_HAVE_COMPAT51=DONT_HAVE_COMPAT51
      AC_SEARCH_LIBS(lua_call, lua$lua_vdot lua$lua_vndot lua,
        [AC_SEARCH_LIBS(luaL_register, lua$lua_vdot lua$lua_vndot lua,
          [lua_havelib=LUA$lua_vndot],
          [AC_SEARCH_LIBS(luaL_module, lualib$lua_vndot lualib$lua_vdot lualib,
            [lua_havelib=$lua_vndot; $LUA -l compat-5.1 2>/dev/null;
             test "$?" = "0" && LUA_HAVE_COMPAT51=HAVE_COMPAT51],
            [AC_SEARCH_LIBS(luaL_openlib, lualib$lua_vdot lualib$lua_vndot lualib,
              [lua_havelib=$lua_vndot],
              [COMP_LUA=], [-lm])], [-lm])], [-lm])],
        [COMP_LUA=], [-lm])
      lua_libs=$LIBS
      LIBS=

      # Options to pass when configuring Lua module
      if test  "$lua_havelib" != "no"; then
        # OK, headers and libs found. Try to set lua flags
        # and modules installation dirs with pkg-config
        if test "$PKGCONFIG" != "no"; then
          if test "$lua_vndot" = "50"; then
            lua_pkg_prefix=lualib
          else
            lua_pkg_prefix=lua
          fi
          # try with dot, without dot and finally without version
          for f in $lua_pkg_prefix$lua_vdot $lua_pkg_prefix$lua_vndot $lua_pkg_prefix; do
            lua_exec_prefix=`$PKGCONFIG --variable=prefix $f 2>/dev/null`
            # same binaries?
            if test "$lua_exec_prefix/bin/lua" = "$LUA"; then 
                # OK, found CFLAGS. Get Lua LFLAGS and modules install dir
                LUA_CFLAGS=`$PKGCONFIG --cflags $f 2>/dev/null`
                LUA_LFLAGS=`$PKGCONFIG --libs $f 2>/dev/null`
                LUA_INSTALL_CMOD=`$PKGCONFIG --variable=INSTALL_CMOD $f 2>/dev/null`
                LUA_INSTALL_LMOD=`$PKGCONFIG --variable=INSTALL_LMOD $f 2>/dev/null`
                break
            fi
          done
        fi

        LUA_RRD_LIBDIR="$langpref/lib/lua/$lua_vdot"
        # if lua 5.0 can't find compat-5.1, force installation of
        # compat-5.1.lua together with RRDtool.
        if test "$lua_vdot" = "5.0" -a "$LUA_HAVE_COMPAT51" != "HAVE_COMPAT51"; then
          lua_need_compat51=1 
          LUA_INSTALL_LMOD="$LUA_RRD_LIBDIR"
        fi

        # if not set with pkg-config, use default values in src packages compat-5.1, lua 5.1
        if test "$LUA_CFLAGS" = ""; then
          AC_MSG_WARN(Setting Lua include and lib flags to defaults in compat-5.1 and lua 5.1 sources)
          LUA_CFLAGS="-I/usr/local/include -I/usr/local/include/lua -I/usr/local/include/lua/$lua_vdot"
          LUA_LFLAGS="-L/usr/local/lib -L/usr/local/lib/lua -L/usr/local/lib/lua/$lua_vdot $lua_libs"
          LUA_INSTALL_CMOD="/usr/local/lib/lua/$lua_vdot"
        fi

        dnl pass additional lua options
        dnl if lua-site-install is not set, overwrite LUA_INSTALL_CMOD already
        dnl found and install together with RRDtool, under $langpref.
        AC_ARG_ENABLE(lua-site-install,
        AS_HELP_STRING([--enable-lua-site-install],[by default the lua module is installed together with rrdtool in $prefix/lib/lua/$lua_version. You have to add $prefix/lib/lua/$lua_version/?.so to package.cpath for lua to find 'rrd.so'. For lua 5.0 you may also need to change LUA_PATH to the same dir, to require 'compat-5.1'. When you set this option the lua modules will get installed wherever your Lua setup thinks it is best. WARNING: if you set this option, system lua modules compat-5.1.lua and rrd.so, if any, may be overwritten.]),
        [],
        [LUA_INSTALL_CMOD="$LUA_RRD_LIBDIR"; LUA_INSTALL_LMOD="$LUA_RRD_LIBDIR"])

        LUA_DEFINES="-DLUA$lua_vndot -D$LUA_HAVE_COMPAT51"
        AC_SUBST(LUA)
        AC_SUBST(COMP_LUA)
        AC_SUBST(LUA_INSTALL_CMOD)
        AC_SUBST(LUA_INSTALL_LMOD)
        AC_SUBST(LUA_CFLAGS)
        AC_SUBST(LUA_LFLAGS)
	AC_SUBST(LUA_DEFINES)
      else
        enable_lua=no
        AC_MSG_RESULT([Lua headers found but not the libraries! Please reinstall the dev packages for Lua $LUA_MAJOR.$LUA_MINOR])
      fi
    fi
  fi
fi
dnl If Lua 5.0, we need compat-5.1. Add ours unless already
dnl integrated as in Debian/Ubuntu 5.0 -dev packages.
AM_CONDITIONAL(LUA_NEED_OUR_COMPAT51,
      [test "$lua_vdot" = "5.0" -a "$LUA_HAVE_COMPAT51" != "HAVE_COMPAT51"])
AM_CONDITIONAL(LUA_SITE_CINSTALL, [test "$LUA_INSTALL_CMOD" != "$LUA_RRD_LIBDIR"])
AM_CONDITIONAL(LUA_SITE_LINSTALL, [test "$LUA_INSTALL_LMOD" != "$LUA_RRD_LIBDIR"])
AM_CONDITIONAL(LUA50, [test "$lua_vndot" = "50"])
AM_CONDITIONAL(BUILD_LUA, [test "$enable_lua" = "yes"])

enable_tcl_site=no

AC_ARG_ENABLE(tcl,AS_HELP_STRING([--disable-tcl],[do not build the tcl modules]),
[],[enable_tcl=yes])

if test  "$enable_tcl" = "yes"; then
  dnl Check for Tcl.
  withval=""
  AC_ARG_WITH(tcllib,[  --with-tcllib=DIR       location of the tclConfig.sh])
  enable_tcl=no
  for dir in $withval /usr/lib /usr/lib64 /usr/local/lib /usr/lib/tcl8.4 /usr/lib/tcl8.3 ; do
    AC_MSG_CHECKING(for tclConfig.sh in $dir)
    if test -f "$dir/tclConfig.sh" ; then
    	tcl_config=$dir/tclConfig.sh
        enable_tcl=yes
        AC_MSG_RESULT(yes)
        break
    else
        AC_MSG_RESULT(no)
    fi
  done

  if test "$enable_tcl" = "no"; then
        AC_MSG_WARN([tclConfig.sh not found - Tcl interface will not be built])
  else
	. $tcl_config
	TCL_PACKAGE_DIR="$TCL_PACKAGE_PATH/tclrrd$VERSION"
	if test -n "$TCL_INC_DIR"; then
	  TCL_INCLUDE_SPEC="$TCL_INCLUDE_SPEC -I$TCL_INC_DIR"
	fi
  fi
  AC_ARG_ENABLE(tcl-site,AS_HELP_STRING([--enable-tcl-site],[install the tcl extension in the tcl tree]),
  [],[enable_tcl_site=yes])

fi

AM_CONDITIONAL(BUILD_TCL, test "$enable_tcl" = "yes" )
AM_CONDITIONAL(BUILD_TCL_SITE, test "$enable_tcl_site" = "yes" )


AC_SUBST(TCL_PREFIX)
AC_SUBST(TCL_SHLIB_CFLAGS)
AC_SUBST(TCL_SHLIB_LD)
AC_SUBST(TCL_SHLIB_SUFFIX)
AC_SUBST(TCL_PACKAGE_PATH)
AC_SUBST(TCL_LD_SEARCH_FLAGS)
AC_SUBST(TCL_STUB_LIB_SPEC)
AC_SUBST(TCL_VERSION)
AC_SUBST(TCL_PACKAGE_DIR)
AC_SUBST(TCL_INCLUDE_SPEC)

AC_ARG_ENABLE(python,AS_HELP_STRING([--disable-python],[do not build the python modules]),
[],[enable_python=yes])

if test  "$enable_python" = "yes"; then
dnl Check for python
AM_PATH_PYTHON(2.3,[],[enable_python=no])
AM_CHECK_PYTHON_HEADERS(,[enable_python=no;AC_MSG_WARN(could not find Python headers)])
fi

if test  x$enable_python = xno; then
	COMP_PYTHON=
else
	COMP_PYTHON="python"
fi

AC_SUBST(COMP_PYTHON)

dnl Check for nroff
AC_ARG_VAR(NROFF, [path to the local nroff version])
AC_PATH_PROGS(NROFF, [gnroff nroff])
if test x$NROFF = x; then
  AC_MSG_ERROR([I need a copy of *nroff to format the documentation])
fi
AC_ARG_VAR(TROFF, [path to the local troff version])
AC_PATH_PROGS(TROFF, [groff troff])
if test x$TROFF = x; then
  AC_MSG_ERROR([I need a copy of *troff to format the documentation])
fi

AC_ARG_VAR(RRDDOCDIR, [[DATADIR/doc/PACKAGE-VERSION] Documentation directory])
if test -z "$RRDDOCDIR"; then
   RRDDOCDIR='${datadir}/doc/${PACKAGE}-${VERSION}'; fi


CONFIGURE_PART(Apply Configuration Information)
 
AC_CONFIG_FILES([examples/shared-demo.pl])
AC_CONFIG_FILES([examples/piped-demo.pl])
AC_CONFIG_FILES([examples/stripes.pl])
AC_CONFIG_FILES([examples/bigtops.pl])
AC_CONFIG_FILES([examples/minmax.pl])
AC_CONFIG_FILES([examples/4charts.pl])
AC_CONFIG_FILES([examples/perftest.pl])
AC_CONFIG_FILES([examples/Makefile])
AC_CONFIG_FILES([examples/rrdcached/Makefile])
AC_CONFIG_FILES([doc/Makefile])
AC_CONFIG_FILES([po/Makefile.in]) 
AC_CONFIG_FILES([src/Makefile])
AC_CONFIG_FILES([src/librrd.sym.in])
AC_CONFIG_FILES([src/librrd.pc])
AC_CONFIG_FILES([bindings/Makefile])
AC_CONFIG_FILES([bindings/tcl/Makefile])
AC_CONFIG_FILES([bindings/tcl/ifOctets.tcl])
AC_CONFIG_FILES([Makefile])          
AC_CONFIG_FILES([bindings/lua/Makefile])

AC_CONFIG_COMMANDS([default],[[ chmod +x examples/*.pl]],[[]])

dnl intl requires our config to be called config.h. indulge it.
AC_CONFIG_COMMANDS_POST([ test -f config.h || ln -s rrd_config.h config.h ])

AC_OUTPUT

AC_MSG_CHECKING(in)
AC_MSG_RESULT(and out again)

echo $ECHO_N "ordering CD from http://tobi.oetiker.ch/wish $ECHO_C" 1>&6
sleep 1
echo $ECHO_N ".$ECHO_C" 1>&6
sleep 1
echo $ECHO_N ".$ECHO_C" 1>&6
sleep 1
echo $ECHO_N ".$ECHO_C" 1>&6
sleep 1
echo $ECHO_N ".$ECHO_C" 1>&6
sleep 1
AC_MSG_RESULT([ just kidding ;-)])
echo
echo "----------------------------------------------------------------"
echo "Config is DONE!"
echo
echo "          With MMAP IO: $enable_mmap"
echo "      Build rrd_getopt: $build_getopt"
echo "       Build rrd_graph: $enable_rrd_graph"
echo "       Static programs: $staticprogs"
echo "          Perl Modules: $COMP_PERL"
echo "           Perl Binary: $PERL"
echo "          Perl Version: $PERL_VERSION"
echo "          Perl Options: $PERL_MAKE_OPTIONS"
echo "          Ruby Modules: $COMP_RUBY"
echo "           Ruby Binary: $RUBY"
echo "          Ruby Options: $RUBY_MAKE_OPTIONS"
echo "    Build Lua Bindings: $enable_lua"
if test "$enable_lua" = "yes"; then
echo "            Lua Binary: $LUA"
echo "           Lua Version: $lua_version"
echo "     Lua C-modules dir: $LUA_INSTALL_CMOD"
if test "$lua_need_compat51" = "1"; then
echo "   Lua Lua-modules dir: $LUA_INSTALL_LMOD"
fi
fi
echo "    Build Tcl Bindings: $enable_tcl"
echo " Build Python Bindings: $enable_python"
echo "          Build rrdcgi: $enable_rrdcgi"
echo "       Build librrd MT: $enable_pthread"
echo "           Use gettext: $USE_NLS"
echo "           With libDBI: $have_libdbi"
echo "          With libwrap: $have_libwrap"
echo
echo "             Libraries: $ALL_LIBS"
echo
echo "Type 'make' to compile the software and use 'make install' to "
echo "install everything to: $prefix."
echo 
echo "       ... that wishlist is NO JOKE. If you find RRDtool useful"
echo "make me happy. Go to http://tobi.oetiker.ch/wish and"
echo "place an order."
echo 
echo "                               -- Tobi Oetiker <tobi@oetiker.ch>"
echo "----------------------------------------------------------------"
