--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local page_utils = require "page_utils"
local os_utils = require "os_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.directories"))

active_page = "directories"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(_POST["ntopng_license"] ~= nil) then
   ntop.setCache('ntopng.license', trimSpace(_POST["ntopng_license"]))
   ntop.checkLicense()
end

print("<hr /><h2>"..i18n("about.directories").."</h2>")

print("<table class=\"table table-bordered table-striped\">\n")

print("<tr><th nowrap rowspan=2>"..i18n("about.directories").."</th><td>"..i18n("about.data_directory").."</td><td>"..dirs.workingdir.."</td></tr>\n")
print("<td>"..i18n("about.scripts_directory").."</td><td>"..dirs.scriptdir.."</td></tr>\n")

print("<tr><th nowrap rowspan=4>"..i18n("about.callback_directories").."</th><td><a href='"..ntop.getHttpPrefix().."/lua/if_stats.lua?page=callbacks&tab=flows'>"..i18n("about.flow_callbacks_directory").."</a></td><td>"..os_utils.fixPath(dirs.callbacksdir.."/interface/alerts/flow/").."</td></tr>\n")
print("<td>"..i18n("about.host_callbacks_directory").."</td><td>"..os_utils.fixPath(dirs.callbacksdir.."/interface/alerts/host/").."</td></tr>\n")
print("<td>"..i18n("about.network_callbacks_directory").."</td><td>"..os_utils.fixPath(dirs.callbacksdir.."/interface/alerts/network/").."</td></tr>\n")
print("<td>"..i18n("about.interface_callbacks_directory").."</td><td>"..os_utils.fixPath(dirs.callbacksdir.."/interface/alerts/interface/").."</td></tr>\n")

print("</table>\n")


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
