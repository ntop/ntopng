# Gnu Makefile for NetWare target
# for use with gcc/nlmconv or Metrowerks CodeWarrior compiler
# use with: make -f Makefile [help|all|clean|dev|devclean|dist|distclean]
#
# $id: $
#

DESCR	= Round Robin Database Tool $(RRD_VERSION_STR)
COPYR	= Copyright (c) 1997-2007 by Tobias Oetiker
WWWURL	= http://www.rrdtool.org/
MTSAFE	= YES
#SCREEN	= $(DESCR)
STACK	= 65535
# Comment the line below if you dont want to load protected automatically.
#LDRING	= 3

# You can set the default font used in graphs.
# If not set here RRD defaults to DejaVuSansMono-Roman.ttf
#RRD_DEFAULT_FONT = "sys:/java/nwgfx/lib/x11/fonts/ttf/tt0003m_.ttf"
#RRD_DEFAULT_FONT = "VeraMono.ttf"

# Vertical label angle: 90.0 (default) or 270.0
RRDGRAPH_YLEGEND_ANGLE = 90.0

# Set to one if you want to have piecharts.
WITH_PIECHART = 0

# Set the extension used for rrdcgi.
ifndef CGIEXT
CGIEXT	= nlm
endif

# Edit the path below to point to your Novell NDK.
ifndef NDKBASE
NDKBASE	= c:/novell
endif

# Base for the lib sources
ifndef LIBBASE
LIBBASE	= ../..
endif
# All library code is statically linked to avoid problems with other lib NLMs.
# Edit the path below to point to your libpng sources or set environment var.
ifndef LIBPNG
LIBPNG	= $(LIBBASE)/libpng-1.2.16
endif
# Edit the path below to point to your freetype sources or set environment var.
ifndef LIBFT2
LIBFT2	= $(LIBBASE)/freetype-2.3.4
endif
# Edit the path below to point to your libart sources or set environment var.
ifndef LIBART
LIBART	= $(LIBBASE)/libart_lgpl-2.3.17
endif
# Edit the path below to point to your zlib sources or set environment var.
ifndef ZLIBSDK
ZLIBSDK	= $(LIBBASE)/zlib-1.2.3
endif

# Edit the path below to point to your distribution folder.
ifndef DISTDIR
DISTDIR	= rrdtool-$(RRD_VERSION_STR)-nw
endif
DISTARC = $(DISTDIR).zip

# Edit the path below to point to your distribution folder.
ifndef DEVLDIR
DEVLDIR	= rrdtool-$(RRD_VERSION_STR)-sdk-nw
endif
DEVLARC = $(DEVLDIR).zip

# whatever...
# NO_NULL_REALLOC = 1

# Edit the var below to point to your lib architecture.
ifndef LIBARCH
# LIBARCH = CLIB
LIBARCH = LIBC
endif

# The following line defines your compiler.
ifdef METROWERKS
	CC = mwccnlm
else
	CC = gcc
endif
# RM	= rm -f
CP	= cp -afv
# if you want to mark the target as MTSAFE you will need a tool for
# generating the xdc data for the linker; here's a minimal tool:
# http://www.gknw.net/development/prgtools/mkxdc.zip
MPKXDC	= mkxdc
# CodeWarrior is too stupid to set the internal name properly when
# the extension is not a NLM and not a registered type. So we need
# to fix that after linking (since CGI isnt a known type - argh!):
# http://www.gknw.net/development/prgtools/fixnlmname.zip
FIXNLMN	= fixnlmname #-q
# Here you can find a native Win32 binary of the original awk:
# http://www.gknw.net/development/prgtools/awk.zip
AWK	= awk
ZIP	= zip -qzr9
MV	= mv -fv

# must be equal to DEBUG or NDEBUG
DB	= NDEBUG
# DB	= DEBUG
# Optimization: -O<n> or debugging: -g
ifeq ($(DB),NDEBUG)
	OPT	= -O2
	OBJDIR	= release
else
	OPT	= -g
	OBJDIR	= debug
endif

# Project root
PROOT	= ..

# Include the version info retrieved from source.
-include $(OBJDIR)/version.inc

# Global flags for all compilers
CFLAGS	= $(OPT) -D$(DB) -nostdinc -DNETWARE -DN_PLAT_NLM -D_POSIX_SOURCE
CFLAGS	+= -DHAVE_CONFIG_H

ifeq ($(CC),mwccnlm)
LD	= mwldnlm
LDFLAGS	= -nostdlib $^ $(PRELUDE) $(LDLIBS) -o $@ -commandfile
AR	= $(LD)
ARFLAGS	= -nostdlib -type library -o
LIBEXT	= lib
#RANLIB	=
CFLAGS	+= -gccinc -inline off -opt nointrinsics -proc 586
CFLAGS	+= -relax_pointers
#CFLAGS	+= -w on,nounused,nounusedexpr # -ansi strict
ifeq ($(LIBARCH),LIBC)
	PRELUDE = $(SDK_LIBC)/imports/libcpre.o
	CFLAGS += -align 4
else
	PRELUDE = "$(METROWERKS)/Novell Support/libraries/runtime/prelude.obj"
	CFLAGS += -include "$(METROWERKS)/Novell Support/headers/nlm_prefix.h"
	CFLAGS += -align 1
endif
else
LD	= nlmconv
LDFLAGS	= -T
AR	= ar
ARFLAGS	= -cq
LIBEXT	= a
RANLIB	= ranlib
CFLAGS	+= -fno-builtin -fpcc-struct-return -fno-strict-aliasing
CFLAGS	+= -Wall -Wno-unused # -pedantic
ifeq ($(LIBARCH),LIBC)
	PRELUDE = $(SDK_LIBC)/imports/libcpre.gcc.o
else
	PRELUDE = $(NDK_ROOT)/pre/prelude.o
	CFLAGS += -include $(NDKBASE)/nlmconv/genlm.h
endif
endif

ifeq ($(findstring linux,$(OSTYPE)),linux)
#include $(NDKBASE)/nlmconv/ncpfs.inc
DL	= '
DS	= /
else
DS	= \\
endif

ifeq ($(MTSAFE),YES)
	XDCOPT = -n
endif
ifeq ($(MTSAFE),NO)
	XDCOPT = -u
endif
ifndef DESCR
	DESCR = $(notdir $(@:.def=)) Command Extension
endif
DESCR += ($(LIBARCH)) - $(CC) build

NDK_ROOT = $(NDKBASE)/ndk
SDK_CLIB = $(NDK_ROOT)/nwsdk
SDK_LIBC = $(NDK_ROOT)/libc

INCLUDES += -I$(PROOT) -I$(PROOT)/src -I$(LIBPNG) -I$(LIBFT2)/include -I$(LIBART) -I$(ZLIBSDK)

ifeq ($(LIBARCH),LIBC)
	INCLUDES += -I$(SDK_LIBC)/include -I$(SDK_LIBC)/include/nks
else
	INCLUDES += -I$(SDK_CLIB)/include/nlm -I$(SDK_CLIB)/include
endif

CFLAGS += $(INCLUDES)

vpath %.c $(PROOT)/src $(LIBPNG) $(LIBART)/libart_lgpl $(ZLIBSDK)

RRDLIBOBJS	= \
	$(OBJDIR)/rrd_afm.o \
	$(OBJDIR)/rrd_afm_data.o \
	$(OBJDIR)/rrd_create.o \
	$(OBJDIR)/rrd_diff.o \
	$(OBJDIR)/rrd_dump.o \
	$(OBJDIR)/rrd_error.o \
	$(OBJDIR)/rrd_fetch.o \
	$(OBJDIR)/rrd_first.o \
	$(OBJDIR)/rrd_format.o \
	$(OBJDIR)/rrd_gfx.o \
	$(OBJDIR)/rrd_graph.o \
	$(OBJDIR)/rrd_graph_helper.o \
	$(OBJDIR)/rrd_hw.o \
	$(OBJDIR)/rrd_info.o \
	$(OBJDIR)/rrd_last.o \
	$(OBJDIR)/rrd_lastupdate.o \
	$(OBJDIR)/rrd_nan_inf.o \
	$(OBJDIR)/rrd_open.o \
	$(OBJDIR)/rrd_resize.o \
	$(OBJDIR)/rrd_restore.o \
	$(OBJDIR)/rrd_rpncalc.o \
	$(OBJDIR)/rrd_tune.o \
	$(OBJDIR)/rrd_update.o \
	$(OBJDIR)/rrd_version.o \
	$(OBJDIR)/rrd_xport.o \
	$(OBJDIR)/rrd_thread_safe.o \
	$(EOLIST)

XLIBOBJS	= \
	$(OBJDIR)/rrd_getopt.o \
	$(OBJDIR)/rrd_getopt1.o \
	$(OBJDIR)/art_rgba_svp.o \
	$(OBJDIR)/hash_32.o \
	$(OBJDIR)/rrd_parsetime.o \
	$(OBJDIR)/pngsize.o \
	$(EOLIST)

PNGLIBOBJS	= \
	$(OBJDIR)/png.o \
	$(OBJDIR)/pngerror.o \
	$(OBJDIR)/pngget.o \
	$(OBJDIR)/pngmem.o \
	$(OBJDIR)/pngpread.o \
	$(OBJDIR)/pngread.o \
	$(OBJDIR)/pngrio.o \
	$(OBJDIR)/pngrtran.o \
	$(OBJDIR)/pngrutil.o \
	$(OBJDIR)/pngset.o \
	$(OBJDIR)/pngtrans.o \
	$(OBJDIR)/pngwio.o \
	$(OBJDIR)/pngwrite.o \
	$(OBJDIR)/pngwtran.o \
	$(OBJDIR)/pngwutil.o \
	$(EOLIST)
ifeq "$(wildcard $(LIBPNG)/pnggccrd.c)" "$(LIBPNG)/pnggccrd.c"
PNGLIBOBJS	+= \
	$(OBJDIR)/pnggccrd.o \
	$(OBJDIR)/pngvcrd.o \
	$(EOLIST)
endif

ZLIBOBJS	= \
	$(OBJDIR)/adler32.o \
	$(OBJDIR)/compress.o \
	$(OBJDIR)/crc32.o \
	$(OBJDIR)/deflate.o \
	$(OBJDIR)/inflate.o \
	$(OBJDIR)/inffast.o \
	$(OBJDIR)/inftrees.o \
	$(OBJDIR)/trees.o \
	$(OBJDIR)/zutil.o \
	$(EOLIST)
ifeq "$(wildcard $(ZLIBSDK)/infblock.c)" "$(ZLIBSDK)/infblock.c"
ZLIBOBJS	+= \
	$(OBJDIR)/infblock.o \
	$(OBJDIR)/infcodes.o \
	$(OBJDIR)/infutil.o \
	$(EOLIST)
endif

ARTLIBOBJS	= \
	$(patsubst $(LIBART)/libart_lgpl/%.c,$(OBJDIR)/%.o,$(wildcard $(LIBART)/libart_lgpl/art_*.c))

OBJS	:= $(RRDLIBOBJS) $(XLIBOBJS) $(PNGLIBOBJS) $(ARTLIBOBJS) $(ZLIBOBJS)
OBJCGI	:= $(OBJS) $(OBJDIR)/rrd_cgi.o
OBJTOOL	:= $(OBJS) $(OBJDIR)/rrd_tool.o

LDLIBS	+= $(LIBFT2)/builds/netware/libc/libft2.$(LIBEXT)


all: rrdtool rrdcgi

rrdtool: $(OBJDIR) $(PROOT)/rrd_config.h $(OBJDIR)/rrdtool.nlm
rrdcgi: $(OBJDIR) $(PROOT)/rrd_config.h $(OBJDIR)/rrdcgi.$(CGIEXT)
librrd: $(OBJDIR) $(PROOT)/rrd_config.h $(OBJDIR)/librrd.$(LIBEXT)

FORCE: ;

dist: all $(DISTDIR) $(DISTDIR)/readme.txt
	@-$(CP) $(OBJDIR)/rrdcgi.$(CGIEXT) $(DISTDIR)
	@-$(CP) $(OBJDIR)/rrdtool.nlm $(DISTDIR)
	@-$(CP) $(PROOT)/src/*.ttf $(DISTDIR)
	@-$(CP) $(PROOT)/CHANGES $(DISTDIR)
	@-$(CP) $(PROOT)/COPYING $(DISTDIR)
	@-$(CP) $(PROOT)/COPYRIGHT $(DISTDIR)
	@-$(CP) $(PROOT)/NEWS $(DISTDIR)
	@-$(CP) $(PROOT)/README $(DISTDIR)
	@echo Creating $(DISTARC)
	@$(ZIP) $(DISTARC) $(DISTDIR)/* < $(DISTDIR)/readme.txt

dev: librrd $(DEVLDIR) $(DEVLDIR)/readme.txt
	@-mkdir $(DEVLDIR)$(DS)include
	@-mkdir $(DEVLDIR)$(DS)lib
	@-mkdir $(DEVLDIR)$(DS)src
	@-$(CP) $(OBJDIR)/librrd.$(LIBEXT) $(DEVLDIR)/lib
	@-$(CP) $(PROOT)/rrd_config.h $(DEVLDIR)/include
	@-$(CP) $(PROOT)/src/rrd.h $(DEVLDIR)/include
	@-$(CP) $(PROOT)/src/*.ttf $(DEVLDIR)/src
	@-$(CP) $(PROOT)/CHANGES $(DEVLDIR)
	@-$(CP) $(PROOT)/COPYING $(DEVLDIR)
	@-$(CP) $(PROOT)/COPYRIGHT $(DEVLDIR)
	@-$(CP) $(PROOT)/NEWS $(DEVLDIR)
	@-$(CP) $(PROOT)/README $(DEVLDIR)
	@echo Creating $(DEVLARC)
	@$(ZIP) $(DEVLARC) $(DEVLDIR)/* < $(DEVLDIR)/readme.txt

clean:
	-$(RM) -r $(OBJDIR)
	-$(RM) $(PROOT)/rrd_config.h

distclean: clean
	-$(RM) -r $(DISTDIR)
	-$(RM) $(DISTARC)

devclean: clean
	-$(RM) -r $(DEVLDIR)
	-$(RM) $(DEVLARC)

$(OBJDIR):
	@mkdir $@

$(DISTDIR):
	@mkdir $@

$(DEVLDIR):
	@mkdir $@

$(OBJDIR)/version.inc: $(PROOT)/configure.ac $(OBJDIR) $(PROOT)/src/get_ver.awk
	@echo Creating $@
	@$(AWK) -f $(PROOT)/src/get_ver.awk $< > $@

$(OBJDIR)/%.o: %.c
	@echo Compiling $<
	@$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/rrdcgi.$(CGIEXT): $(OBJCGI) $(OBJDIR)/rrdcgi.def $(OBJDIR)/rrdcgi.xdc
	@echo Linking $@
	@-$(RM) $@
	@$(LD) $(LDFLAGS) $(@:.$(CGIEXT)=.def)
ifeq ($(LD),nlmconv)
	@$(MV) $(notdir $@) $@
endif
ifneq ($(CGIEXT),nlm)
ifeq ($(LD),mwldnlm)
	@$(FIXNLMN) $@
endif
endif

$(OBJDIR)/rrdtool.nlm: $(OBJTOOL) $(OBJDIR)/rrdtool.def $(OBJDIR)/rrdtool.xdc
	@echo Linking $@
	@-$(RM) $@
	@$(LD) $(LDFLAGS) $(@:.nlm=.def)
ifeq ($(LD),nlmconv)
	@$(MV) $(notdir $@) $@
endif

$(OBJDIR)/librrd.$(LIBEXT): $(OBJS)
	@echo Creating $@
	@-$(RM) $@
	@$(AR) $(ARFLAGS) $@ $^
ifdef RANLIB
	@$(RANLIB) $@
endif

$(OBJDIR)/%.xdc: Makefile
	@echo Creating $@
	@$(MPKXDC) $(XDCOPT) $@

$(OBJDIR)/%.def: Makefile $(OBJDIR)/version.inc
	@echo $(DL)# DEF Linker File for use with gcc and nlmconv$(DL) > $@
	@echo $(DL)# or with Codewarrior command line compiler.$(DL) >> $@
	@echo $(DL)# Do not edit this file - it is created by make!$(DL) >> $@
	@echo $(DL)# All your changes will be lost!!$(DL) >> $@
	@echo $(DL)#$(DL) >> $@
	@echo $(DL)copyright "$(COPYR)"$(DL) >> $@
	@echo $(DL)description "$(DESCR)"$(DL) >> $@
	@echo $(DL)version $(RRD_VERSION)$(DL) >> $@
ifdef NLMTYPE
	@echo $(DL)type $(NLMTYPE)$(DL) >> $@
else
	@echo $(DL)type 0$(DL) >> $@
endif
ifdef STACK
	@echo $(DL)stack $(STACK)$(DL) >> $@
endif
	@echo $(DL)threadname "$(notdir $(@:.def=))"$(DL) >> $@
ifdef SCREEN
	@echo $(DL)screenname "$(SCREEN)"$(DL) >> $@
else
	@echo $(DL)screenname "DEFAULT"$(DL) >> $@
endif
ifeq ($(DB),DEBUG)
	@echo $(DL)debug$(DL) >> $@
endif
ifeq ($(LIBARCH),CLIB)
	@echo $(DL)start _Prelude$(DL) >> $@
	@echo $(DL)exit _Stop$(DL) >> $@
	@echo $(DL)import @$(NDK_ROOT)/nwsdk/imports/clib.imp$(DL) >> $@
	@echo $(DL)import @$(NDK_ROOT)/nwsdk/imports/threads.imp$(DL) >> $@
	@echo $(DL)import @$(NDK_ROOT)/nwsdk/imports/nlmlib.imp$(DL) >> $@
	@echo $(DL)module clib$(DL) >> $@
else
	@echo $(DL)start _LibCPrelude$(DL) >> $@
	@echo $(DL)exit _LibCPostlude$(DL) >> $@
	@echo $(DL)check _LibCCheckUnload$(DL) >> $@
	@echo $(DL)import @$(NDK_ROOT)/libc/imports/libc.imp$(DL) >> $@
	@echo $(DL)import @$(NDK_ROOT)/libc/imports/netware.imp$(DL) >> $@
	@echo $(DL)module libc$(DL) >> $@
	@echo $(DL)pseudopreemption$(DL) >> $@
	@echo $(DL)flag_on 64$(DL) >> $@
endif
ifeq ($(LDRING),0)
	@echo $(DL)flag_on 16$(DL) >> $@
endif
ifeq ($(LDRING),3)
	@echo $(DL)flag_on 512$(DL) >> $@
endif
ifdef XDCOPT
	@echo $(DL)xdcdata $(@:.def=.xdc)$(DL) >> $@
endif
ifeq ($(LD),nlmconv)
	@echo $(DL)input $(OBJS) $(LDLIBS)$(DL) >> $@
	@echo $(DL)input $(PRELUDE)$(DL) >> $@
	@echo $(DL)output $(notdir $(@:.def=.nlm))$(DL) >> $@
endif

$(PROOT)/rrd_config.h: FORCE Makefile $(OBJDIR)/version.inc
	@echo Creating $@
	@echo $(DL)/* $(notdir $@) for NetWare target.$(DL) > $@
	@echo $(DL)** Do not edit this file - it is created by make!$(DL) >> $@
	@echo $(DL)** All your changes will be lost!!$(DL) >> $@
	@echo $(DL)*/$(DL) >> $@
	@echo $(DL)#ifndef NETWARE$(DL) >> $@
	@echo $(DL)#error This $(notdir $@) is created for NetWare platform!$(DL) >> $@
	@echo $(DL)#endif$(DL) >> $@
	@echo $(DL)#ifndef RRD_CONFIG_H$(DL) >> $@
	@echo $(DL)#define RRD_CONFIG_H$(DL) >> $@
	@echo $(DL)#define OS "i586-pc-NetWare"$(DL) >> $@
	@echo $(DL)#define PACKAGE_VERSION "$(RRD_VERSION_STR)"$(DL) >> $@
	@echo $(DL)#define PACKAGE_BUGREPORT "tobi@oetiker.ch"$(DL) >> $@
	@echo $(DL)#define NUMVERS $(RRD_NUMVERS)$(DL) >> $@
	@echo $(DL)#define HAVE_ASSERT_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_DLFCN_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_DLOPEN 1$(DL) >> $@
	@echo $(DL)#define HAVE_ERR_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_ERRNO_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_FCNTL_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_FIONBIO 1$(DL) >> $@
	@echo $(DL)#define HAVE_FLOAT_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_GETTIMEOFDAY 1$(DL) >> $@
	@echo $(DL)#define HAVE_INTTYPES_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_LIMITS_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_LONGLONG 1$(DL) >> $@
	@echo $(DL)#define HAVE_LOCALE_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_MALLOC_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_MATH_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_MBSTOWCS 1$(DL) >> $@
	@echo $(DL)#define HAVE_MEMMOVE 1$(DL) >> $@
	@echo $(DL)#define HAVE_MKTIME 1$(DL) >> $@
	@echo $(DL)#define HAVE_SELECT 1$(DL) >> $@
	@echo $(DL)#define HAVE_SETLOCALE 1$(DL) >> $@
	@echo $(DL)#define HAVE_SETJMP_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_SNPRINTF 1$(DL) >> $@
	@echo $(DL)#define HAVE_STDARG_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_STDDEF_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_STDINT_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_STDLIB_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_STRCASECMP 1$(DL) >> $@
	@echo $(DL)#define HAVE_STRDUP 1$(DL) >> $@
	@echo $(DL)#define HAVE_STRFTIME 1$(DL) >> $@
	@echo $(DL)#define HAVE_STRING_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_STRLCAT 1$(DL) >> $@
	@echo $(DL)#define HAVE_STRLCPY 1$(DL) >> $@
	@echo $(DL)#define HAVE_STRSTR 1$(DL) >> $@
	@echo $(DL)#define HAVE_SYS_PARAM_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_SYS_SELECT_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_SYS_STAT_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_SYS_TIME_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_SYS_TYPES_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_TIME_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_TZSET 1$(DL) >> $@
	@echo $(DL)#define HAVE_UNAME 1$(DL) >> $@
	@echo $(DL)#define HAVE_VSNPRINTF 1$(DL) >> $@
	@echo $(DL)#define STDC_HEADERS 1$(DL) >> $@
	@echo $(DL)#define TIME_WITH_SYS_TIME 1$(DL) >> $@
	@echo $(DL)#define HAVE_ZLIB_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_LIBZ 1$(DL) >> $@
ifdef NO_NULL_REALLOC
	@echo $(DL)#define NO_NULL_REALLOC 1$(DL) >> $@
	@echo $(DL)#define rrd_realloc(a,b) ( (a) == NULL ? malloc( (b) ) : realloc( (a) , (b) ))$(DL) >> $@
else
	@echo $(DL)#define rrd_realloc(a,b) realloc((a), (b))$(DL) >> $@
endif
ifdef RRD_DEFAULT_FONT
	@echo $(DL)#define RRD_DEFAULT_FONT $(RRD_DEFAULT_FONT)$(DL) >> $@
endif
	@echo $(DL)#define RRDGRAPH_YLEGEND_ANGLE $(RRDGRAPH_YLEGEND_ANGLE)$(DL) >> $@
ifdef WITH_PIECHART
	@echo $(DL)#define WITH_PIECHART $(WITH_PIECHART)$(DL) >> $@
endif
	@echo $(DL)#endif /* RRD_CONFIG_H */$(DL) >> $@

$(DISTDIR)/readme.txt: Makefile
	@echo Creating $@
	@echo $(DL)This is a binary distribution for NetWare platform.$(DL) > $@
	@echo $(DL)RRDTool version $(RRD_VERSION_STR)$(DL) >> $@
	@echo $(DL)Please download the complete RRDTool package for$(DL) >> $@
	@echo $(DL)any further documentation:$(DL) >> $@
	@echo $(DL)$(WWWURL)$(DL) >> $@

$(DEVLDIR)/readme.txt: Makefile
	@echo Creating $@
	@echo $(DL)This is a development distribution for NetWare platform.$(DL) > $@
	@echo $(DL)RRDTool version $(RRD_VERSION_STR)$(DL) >> $@
	@echo $(DL)Please download the complete RRDTool package for$(DL) >> $@
	@echo $(DL)any further documentation:$(DL) >> $@
	@echo $(DL)$(WWWURL)$(DL) >> $@

help:
	@echo $(DL)===========================================================$(DL)
	@echo $(DL)Novell NDK Base = $(NDKBASE)$(DL)
	@echo $(DL)libpng Source   = $(LIBPNG)$(DL)
	@echo $(DL)libart Source   = $(LIBART)$(DL)
	@echo $(DL)Freetype 2 SDK  = $(LIBFT2)$(DL)
	@echo $(DL)Zlib SDK        = $(ZLIBSDK)$(DL)
	@echo $(DL)===========================================================$(DL)
	@echo $(DL)RRDTool $(RRD_VERSION_STR) - available targets are:$(DL)
	@echo $(DL)$(MAKE) all$(DL)
	@echo $(DL)$(MAKE) rrdtool$(DL)
	@echo $(DL)$(MAKE) rrdcgi$(DL)
	@echo $(DL)$(MAKE) librrd$(DL)
	@echo $(DL)$(MAKE) clean$(DL)
	@echo $(DL)$(MAKE) dev$(DL)
	@echo $(DL)$(MAKE) devclean$(DL)
	@echo $(DL)$(MAKE) dist$(DL)
	@echo $(DL)$(MAKE) distclean$(DL)
	@echo $(DL)===========================================================$(DL)


