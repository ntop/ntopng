--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/interface_stats.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
