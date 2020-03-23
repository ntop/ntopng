--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')
page_utils.manage_system_interface()

page_utils.print_header()

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/menu.inc")

print('<div class="alert alert-danger"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Page not found</div>')

print ("<center><H4>Unable to find URL <i>")

print(_GET["url"])

print("</i></center></H4>\n")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")


