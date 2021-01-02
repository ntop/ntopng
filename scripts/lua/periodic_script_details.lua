--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   local snmp_utils = require "snmp_utils"
end

require "lua_utils"
local graph_utils = require "graph_utils"
local page_utils = require("page_utils")
local internals_utils = require "internals_utils"

local ifstats = interface.getStats()
local ifId = ifstats.id

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.interface, {ifname = getHumanReadableInterfaceName(ifId)})

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local nav_url = ntop.getHttpPrefix().."/lua/periodic_script_details.lua?ifid="..ifId
local title = i18n("internals.iface_periodic_scripts", {iface = getHumanReadableInterfaceName(ifId)})

page_utils.print_navbar(title, nav_url,
			{
			   {
			      active = true,
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			}
)

internals_utils.printPeriodicActivityDetails(_GET["ifid"] or ifId, nav_url)

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
