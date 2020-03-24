--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

local page_utils = require("page_utils")

local country        = _GET["country"]
local page           = _GET["page"]

interface.select(ifname)
local ifstats = interface.getStats()
local ifId = ifstats.id
local ts_utils = require("ts_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.countries)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(country == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> ".. i18n("country_details.country_parameter_missing_message") .. "</div>")
    return
end

if(not ts_utils.exists("country:traffic", {ifid=ifId, country=country})) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("country_details.no_available_stats_for_country",{country=country}) .. "</div>")
    return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/country_details.lua?country="..country
local title = i18n("country_details.country") .. ": "..country

   page_utils.print_navbar(title, nav_url,
			   {
			      {
				 active = page == "historical" or not page,
				 page_name = "historical",
				 label = "<i class='fas fa-lg fa-chart-area'></i>",
			      },
			   }
   )

--[[
Selectively render information pages
--]]
if page == "historical" then
    local schema = _GET["ts_schema"] or "country:traffic"
    local selected_epoch = _GET["epoch"] or ""
    local url = ntop.getHttpPrefix()..'/lua/country_details.lua?ifid='..ifId..'&country='..country..'&page=historical'

    local tags = {
      ifid = ifId,
      country = country,
    }

    drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = {
        {schema="country:traffic",             label=i18n("traffic")},
      }
    })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
