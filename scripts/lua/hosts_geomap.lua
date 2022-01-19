--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template_utils = require("template_utils")

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.geo_map)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.select(ifname)
local hosts_stats = interface.getHostsInfo()
local num = hosts_stats["numHosts"]
hosts_stats = hosts_stats["hosts"]

local ifid = interface.getId()

if (num > 0) then

template_utils.render("pages/hosts_geomap.template", {})
  --page_utils.print_page_title(i18n("geo_map.hosts_geomap"))

else
   print("<div class=\"alert alert-danger\">".. "<i class='fas fa-exclamation-triangle fa-lg' style='color: #B94A48;'></i> " .. i18n("no_results_found") .. "</div>")
end

if ntop.isPro() then
  print(ui_utils.render_notes({
    {content = i18n("map_page.geo_map_notes", { prefs_link = ntop.getHttpPrefix() .. '/lua/admin/prefs.lua?tab=geo_map' })}
  }))
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
