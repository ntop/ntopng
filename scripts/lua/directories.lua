--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local page_utils = require "page_utils"
local os_utils = require "os_utils"
local user_scripts = require "user_scripts"
local flow_consts = require "flow_consts"
local alert_consts = require "alert_consts"

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

print("<tr><th nowrap rowspan=4>"..i18n("about.callback_directories").."</th><td><a href='"..ntop.getHttpPrefix().."/lua/if_stats.lua?page=callbacks&tab=flows'>"..i18n("about.flow_callbacks_directory").."</a></td><td>".. user_scripts.getSubdirectoryPath(user_scripts.script_types.flow, "flow") .."</td></tr>\n")
print("<td>"..i18n("about.host_callbacks_directory").."</td><td>".. user_scripts.getSubdirectoryPath(user_scripts.script_types.traffic_element, "host") .."</td></tr>\n")
print("<td>"..i18n("about.network_callbacks_directory").."</td><td>".. user_scripts.getSubdirectoryPath(user_scripts.script_types.traffic_element, "network") .."</td></tr>\n")
print("<td>"..i18n("about.interface_callbacks_directory").."</td><td>".. user_scripts.getSubdirectoryPath(user_scripts.script_types.traffic_element, "interface") .."</td></tr>\n")

print("<tr><th nowrap rowspan=2>"..i18n("about.defs_directories").."</th><td>"..i18n("show_alerts.alerts").."</td><td>".. alert_consts.getDefinititionsDir() .."</td></tr>\n")
print("<td>"..i18n("flow_details.flow_status").."</td><td>".. flow_consts.getDefinititionsDir() .."</td></tr>\n")

print("</table>\n")


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
