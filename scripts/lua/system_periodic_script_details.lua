--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
local page_utils = require("page_utils")
local internals_utils = require "internals_utils"

interface.select(getSystemInterfaceId())
local ifstats = interface.getStats()
local ifId = ifstats.id

sendHTTPContentTypeHeader('text/html')
tprint(getHumanReadableInterfaceName(ifId))
page_utils.set_active_menu_entry(page_utils.menu_entries.system_status, {ifname = getSystemInterfaceName()})

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local nav_url = ntop.getHttpPrefix().."/lua/system_periodic_script_details.lua?ifid="..ifId
local title = i18n("internals.system_iface_periodic_scripts")

page_utils.print_navbar(title, nav_url,
			{
			   {
			      active = page == "historical" or not page,
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			}
)

internals_utils.printPeriodicActivityDetails(ifId, nav_url)

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
