# Gnu Makefile for Win32 target
# for use with MingW32 gcc or Metrowerks CodeWarrior compiler
# use with: make -f Makefile [help|all|clean|dev|devclean|dist|distclean]
#
# $id: $
#

DESCR	= Round Robin Database Tool
COPYR	= Copyright (c) 1997-2007 by Tobias Oetiker
WWWURL	= http://www.rrdtool.org/
ICON	= $(PROOT)/favicon.ico

# You can set the default font used in graphs.
# If not set here RRD defaults to DejaVuSansMono-Roman.ttf
#RRD_DEFAULT_FONT = "arial.ttf"
#RRD_DEFAULT_FONT = "VeraMono.ttf"

# Vertical label angle: 90.0 (default) or 270.0
RRDGRAPH_YLEGEND_ANGLE = 90.0

# Set to one if you want to have piecharts.
WITH_PIECHART = 0

# Set the extension used for rrdcgi.
ifndef CGIEXT
CGIEXT	= exe
endif

# Base for the lib sources
ifndef LIBBASE
LIBBASE	= ../..
endif
# All library code is statically linked to avoid problems with other lib DLLs.
# Edit the path below to point to your libpng sources or set environment var.
ifndef LIBPNG
LIBPNG	= $(LIBBASE)/libpng-1.2.16
endif
# Edit the path below to point to your freetype sources or set environment var.
ifndef LIBFT2
#LIBFT2	= $(LIBBASE)/freetype-2.3.4
LIBFT2	= $(LIBBASE)/../mingw32/freetype-2.3.4
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
DISTDIR	= rrdtool-$(RRD_VERSION_STR)-w32
endif
DISTARC = $(DISTDIR).zip

# Edit the path below to point to your distribution folder.
ifndef DEVLDIR
DEVLDIR	= rrdtool-$(RRD_VERSION_STR)-sdk-w32
endif
DEVLARC = $(DEVLDIR).zip

# whatever...
NO_NULL_REALLOC = 1

# The following line defines your compiler.
ifdef METROWERKS
	CC = mwcc
else
	CC = gcc
endif
# RM	= rm -f
CP	= cp -afv
# Here you can find a native Win32 binary of the original awk:
# http://www.gknw.net/development/prgtools/awk.zip
AWK	= awk
ZIP	= zip -qzr9

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
CFLAGS	= $(OPT) -D$(DB) -DHAVE_CONFIG_H

ifeq ($(CC),mwcc)
LD	= mwld
RC	= mwwinrc
LDFLAGS	= -nostdlib
AR	= $(LD)
ARFLAGS	= -type library -w nocmdline $(OBJS) -o
LIBEXT	= lib
LIBPATH	+= -lr "$(METROWERKS)/MSL" -lr "$(METROWERKS)/Win32-x86 Support"
LDLIBS	+= -lkernel32.lib -luser32.lib
LDLIBS	+= -lMSL_Runtime_x86.lib -lMSL_C_x86.lib -lMSL_Extras_x86.lib
RCFLAGS	=
CFLAGS	+= -DWIN32
CFLAGS	+= -nostdinc -gccinc -msgstyle gcc -inline off -opt nointrinsics -proc 586
CFLAGS	+= -ir "$(METROWERKS)/MSL" -ir "$(METROWERKS)/Win32-x86 Support"
CFLAGS	+= -w on,nounused,nounusedexpr # -ansi strict
else
LD	= gcc
RC	= windres
LDFLAGS	= -s
AR	= ar
ARFLAGS	= -cq
LIBEXT	= a
RCFLAGS	= -O coff -i
CFLAGS	+= -fno-strict-aliasing
CFLAGS	+= -Wall -Wno-unused # -pedantic
endif

ifeq ($(findstring msys,$(OSTYPE)),msys)
DL	= '
DS	= /
else
DS	= \\
endif

ifndef DESCR
	DESCR = $(notdir $(@:.rc=)) Command Extension
endif
DESCR += - $(CC) build

INCLUDES += -I$(PROOT) -I$(PROOT)/src -I$(LIBPNG) -I$(LIBFT2)/include -I$(LIBART) -I$(ZLIBSDK)

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
	$(OBJDIR)/rrd_thread_safe_nt.o \
	$(EOLIST)

XLIBOBJS	= \
	$(OBJDIR)/rrd_getopt.o \
	$(OBJDIR)/rrd_getopt1.o \
	$(OBJDIR)/art_rgba_svp.o \
	$(OBJDIR)/hash_32.o \
	$(OBJDIR)/parsetime.o \
	$(OBJDIR)/pngsize.o \
	$(OBJDIR)/strftime.o \
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

LDLIBS	+= $(LIBFT2)/objs/freetype.$(LIBEXT)


all: rrdtool rrdcgi

rrdtool: $(OBJDIR) $(PROOT)/rrd_config.h $(OBJDIR)/rrdtool.exe
rrdcgi: $(OBJDIR) $(PROOT)/rrd_config.h $(OBJDIR)/rrdcgi.$(CGIEXT)
librrd: $(OBJDIR) $(PROOT)/rrd_config.h $(OBJDIR)/librrd.$(LIBEXT)

FORCE: ;

dist: all $(DISTDIR) $(DISTDIR)/readme.txt
	@-$(CP) $(OBJDIR)/rrdcgi.$(CGIEXT) $(DISTDIR)
	@-$(CP) $(OBJDIR)/rrdtool.exe $(DISTDIR)
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

$(OBJDIR)/rrdcgi.$(CGIEXT): $(OBJCGI) $(OBJDIR)/rrdcgi.res
	@echo Linking $@
	@-$(RM) $@
	@$(LD) $(LDFLAGS) $^ -o $@ $(LIBPATH) $(LDLIBS)

$(OBJDIR)/rrdtool.exe: $(OBJTOOL) $(OBJDIR)/rrdtool.res
	@echo Linking $@
	@-$(RM) $@
	@$(LD) $(LDFLAGS) $^ -o $@ $(LIBPATH) $(LDLIBS)

$(OBJDIR)/librrd.$(LIBEXT): $(OBJS)
	@echo Creating $@
	@-$(RM) $@
	@$(AR) $(ARFLAGS) $@ $^

$(OBJDIR)/%.res: $(OBJDIR)/%.rc
	@echo Creating $@
	@$(RC) $(RCFLAGS) $< -o $@

$(OBJDIR)/%.rc: Makefile $(OBJDIR)/version.inc
	@echo $(DL)1 VERSIONINFO$(DL) > $@
	@echo $(DL) FILEVERSION $(RRD_VERSION),0$(DL) >> $@
	@echo $(DL) PRODUCTVERSION $(RRD_VERSION),0$(DL) >> $@
	@echo $(DL) FILEFLAGSMASK 0x3fL$(DL) >> $@
	@echo $(DL) FILEOS 0x40004L$(DL) >> $@
	@echo $(DL) FILEFLAGS 0x0L$(DL) >> $@
	@echo $(DL) FILETYPE 0x1L$(DL) >> $@
	@echo $(DL) FILESUBTYPE 0x0L$(DL) >> $@
	@echo $(DL)BEGIN$(DL) >> $@
	@echo $(DL)  BLOCK "StringFileInfo"$(DL) >> $@
	@echo $(DL)  BEGIN$(DL) >> $@
	@echo $(DL)    BLOCK "040904E4"$(DL) >> $@
	@echo $(DL)    BEGIN$(DL) >> $@
	@echo $(DL)      VALUE "LegalCopyright","$(COPYR)\0"$(DL) >> $@
ifdef COMPANY
	@echo $(DL)      VALUE "CompanyName","$(COMPANY)\0"$(DL) >> $@
endif
	@echo $(DL)      VALUE "ProductName","$(notdir $(@:.rc=.exe))\0"$(DL) >> $@
	@echo $(DL)      VALUE "ProductVersion","$(RRD_VERSION_STR)\0"$(DL) >> $@
	@echo $(DL)      VALUE "License","Released under GPL.\0"$(DL) >> $@
	@echo $(DL)      VALUE "FileDescription","$(DESCR)\0"$(DL) >> $@
	@echo $(DL)      VALUE "FileVersion","$(RRD_VERSION_STR)\0"$(DL) >> $@
	@echo $(DL)      VALUE "InternalName","$(notdir $(@:.rc=))\0"$(DL) >> $@
	@echo $(DL)      VALUE "OriginalFilename","$(notdir $(@:.rc=.exe))\0"$(DL) >> $@
	@echo $(DL)      VALUE "WWW","$(WWWURL)\0"$(DL) >> $@
	@echo $(DL)    END$(DL) >> $@
	@echo $(DL)  END$(DL) >> $@
	@echo $(DL)  BLOCK "VarFileInfo"$(DL) >> $@
	@echo $(DL)  BEGIN$(DL) >> $@
	@echo $(DL)    VALUE "Translation", 0x409, 1252$(DL) >> $@
	@echo $(DL)  END$(DL) >> $@
	@echo $(DL)END$(DL) >> $@
ifdef ICON
	@echo $(DL)10 ICON DISCARDABLE "$(ICON)"$(DL) >> $@
endif

$(PROOT)/rrd_config.h: FORCE Makefile $(OBJDIR)/version.inc
	@echo Creating $@
	@echo $(DL)/* $(notdir $@) for Win32 target.$(DL) > $@
	@echo $(DL)** Do not edit this file - it is created by make!$(DL) >> $@
	@echo $(DL)** All your changes will be lost!!$(DL) >> $@
	@echo $(DL)*/$(DL) >> $@
	@echo $(DL)#ifndef WIN32$(DL) >> $@
	@echo $(DL)#error This $(notdir $@) is created for Win32 platform!$(DL) >> $@
	@echo $(DL)#endif$(DL) >> $@
	@echo $(DL)#ifndef RRD_CONFIG_H$(DL) >> $@
	@echo $(DL)#define RRD_CONFIG_H$(DL) >> $@
	@echo $(DL)#define OS "i586-pc-Win32"$(DL) >> $@
	@echo $(DL)#define PACKAGE_VERSION "$(RRD_VERSION_STR)"$(DL) >> $@
	@echo $(DL)#define PACKAGE_BUGREPORT "tobi@oetiker.ch"$(DL) >> $@
	@echo $(DL)#define NUMVERS $(RRD_NUMVERS)$(DL) >> $@
	@echo $(DL)#define HAVE_ASSERT_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_DLFCN_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_DLOPEN 1$(DL) >> $@
	@echo $(DL)#define HAVE_ERRNO_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_FCNTL_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_FIONBIO 1$(DL) >> $@
	@echo $(DL)#define HAVE_INTTYPES_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_LIMITS_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_LONGLONG 1$(DL) >> $@
	@echo $(DL)#define HAVE_LOCALE_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_MALLOC_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_MATH_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_MBSTOWCS 1$(DL) >> $@
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
	@echo $(DL)#define HAVE_SYS_STAT_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_SYS_TIME_H 1$(DL) >> $@
	@echo $(DL)#define HAVE_TIME_H 1$(DL) >> $@
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
	@echo $(DL)#define strftime strftime_$(DL) >> $@
ifdef WITH_PIECHART
	@echo $(DL)#define WITH_PIECHART $(WITH_PIECHART)$(DL) >> $@
endif
	@echo $(DL)#endif /* RRD_CONFIG_H */$(DL) >> $@

$(DISTDIR)/readme.txt: Makefile
	@echo Creating $@
	@echo $(DL)This is a binary distribution for Win32 platform.$(DL) > $@
	@echo $(DL)RRDTool version $(RRD_VERSION_STR)$(DL) >> $@
	@echo $(DL)Please download the complete RRDTool package for$(DL) >> $@
	@echo $(DL)any further documentation:$(DL) >> $@
	@echo $(DL)$(WWWURL)$(DL) >> $@

$(DEVLDIR)/readme.txt: Makefile
	@echo Creating $@
	@echo $(DL)This is a development distribution for Win32 platform.$(DL) > $@
	@echo $(DL)RRDTool version $(RRD_VERSION_STR)$(DL) >> $@
	@echo $(DL)Please download the complete RRDTool package for$(DL) >> $@
	@echo $(DL)any further documentation:$(DL) >> $@
	@echo $(DL)$(WWWURL)$(DL) >> $@

help:
	@echo $(DL)===========================================================$(DL)
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


