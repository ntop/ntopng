# $Id: extconf.rb,v 1.2 2001/11/28 18:30:16 miles Exp $
# Lost ticket pays maximum rate.

require 'mkmf'

if /linux/ =~ RUBY_PLATFORM
   $LDFLAGS += ' -Wl,--rpath -Wl,$(EPREFIX)/lib'
elsif /solaris/ =~ RUBY_PLATFORM
   $LDFLAGS += ' -R$(EPREFIX)/lib'
elsif /hpux/ =~ RUBY_PLATFORM
   $LDFLAGS += ' +b$(EPREFIX)/lib'
elsif /aix/ =~ RUBY_PLATFORM
   $LDFLAGS += ' -blibpath:$(EPREFIX)/lib'
end

dir_config("rrd","../../src","../../src/.libs")
have_library("rrd", "rrd_create")
create_makefile("RRD")
