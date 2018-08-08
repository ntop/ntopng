--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"


interface.select(ifname)

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "home"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


local rc = interface.dumpLiveCaptures()



ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/footer.inc")
