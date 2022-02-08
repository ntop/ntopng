--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datasources/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local widget_gui_utils = require("widget_gui_utils")

local HostsMapMode = require("hosts_map_utils").HostsMapMode
local Datasource = widget_gui_utils.datasource

local info = ntop.getInfo() 

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product=info.product }))
print([[
  <script src="https://cdn.jsdelivr.net/npm/chart.js@2.8.0"></script>
  <script type='text/javascript' src='/js/widgets/widgets.js'></script>
]])

if not isAdministrator() then
  return
end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

widget_gui_utils.register_bubble_chart('All Flows', 0, {
  Datasource("rest/v1/charts/host/map.lua", {bubble_mode = HostsMapMode.ALL_FLOWS})
})
widget_gui_utils.register_bubble_chart('Unreachable Flows', 0, {
  Datasource("rest/v1/charts/host/map.lua", {bubble_mode = HostsMapMode.UNREACHABLE_FLOWS})
})
widget_gui_utils.register_bubble_chart('DNS Queries', 0, {
  Datasource("rest/v1/charts/host/map.lua", {bubble_mode = HostsMapMode.DNS_QUERIES})
})
widget_gui_utils.register_bubble_chart('SYN vs RST', 0, {
  Datasource("rest/v1/charts/host/map.lua", {bubble_mode = HostsMapMode.SYN_VS_RST})
})

template_utils.render("pages/test_gui_widgets.template", {
    widget_gui_utils = widget_gui_utils
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

