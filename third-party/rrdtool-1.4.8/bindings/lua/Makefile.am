# These files are not mentioned in any other Makefile
# compat-5.1.lua is only necessary for Lua 5.0 in distros where
# it's not already installed.
EXTRA_DIST = README test.lua.bottom compat-5.1r5/compat-5.1.lua

LIB_VERSION_INFO=0:0:0

LUA                 = @LUA@
LUA_INSTALL_CMOD    = @LUA_INSTALL_CMOD@
LUA_INSTALL_LMOD    = @LUA_INSTALL_LMOD@
LUA_DEFINES         = @LUA_DEFINES@
LUA_CFLAGS          = @LUA_CFLAGS@
LUA_LFLAGS          = @LUA_LFLAGS@

CLEANFILES = rrd.o rrd.so test.lua test.rrd test.png

lualibdir=$(LUA_INSTALL_CMOD)
lualib_LTLIBRARIES = rrd.la
if LUA_NEED_OUR_COMPAT51
  rrd_la_SOURCES = rrdlua.c compat-5.1r5/compat-5.1.c compat-5.1r5/compat-5.1.h
  compatdir = $(LUA_INSTALL_LMOD)
  compat_DATA = compat-5.1r5/compat-5.1.lua
else
  rrd_la_SOURCES = rrdlua.c
endif
rrd_la_LIBADD = -lrrd -lm
rrd_la_LDFLAGS = -module -version-info $(LIB_VERSION_INFO) $(LUA_LFLAGS) -L$(top_builddir)/src/.libs
rrd_la_CFLAGS = -I$(top_srcdir)/src -I$(top_srcdir) $(LUA_CFLAGS) $(LUA_DEFINES) -DLIB_VERSION=\"$(LIB_VERSION)\"

.PHONY: test.lua

test.lua: test.lua.bottom
	@echo "-- Created by Makefile." > test.lua
	@echo "-- Test script adapted from the one in the Ruby binding." > test.lua
	@echo >> test.lua
if LUA50
	@echo "--- compat-5.1.lua is only required for Lua 5.0 ----------" >> test.lua
if LUA_NEED_OUR_COMPAT51
if !LUA_SITE_LINSTALL
	@echo "original_LUA_PATH = LUA_PATH" >> test.lua
	@echo "-- try only compat-5.1.lua installed with RRDtool" >> test.lua
	@echo "LUA_PATH = '$(LUA_INSTALL_LMOD)/?.lua'" >> test.lua
endif
endif
	@echo "local r = pcall(require, 'compat-5.1')" >> test.lua
	@echo "if not r then" >> test.lua
	@echo "  print('** compat-5.1.lua not found')" >> test.lua
	@echo "  os.exit(1)" >> test.lua
	@echo "end" >> test.lua
if LUA_NEED_OUR_COMPAT51
if !LUA_SITE_LINSTALL
	@echo "LUA_PATH = original_LUA_PATH" >> test.lua
	@echo "original_LUA_PATH = nil" >> test.lua
endif
endif
	@echo "----------------------------------------------------------" >> test.lua
	@echo >> test.lua
endif
if !LUA_SITE_CINSTALL
	@echo "package.cpath = '$(LUA_INSTALL_CMOD)/?.so;' .. package.cpath" >> test.lua
endif
	@cat test.lua.bottom >> test.lua

test: test.lua
	$(LUA) test.lua

