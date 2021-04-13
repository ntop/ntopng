--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local MODES = require("hosts_map_utils").MODES

local widget_gui_utils = require("widget_gui_utils")
local Datasource = widget_gui_utils.datasource

local show_remote  = true
local map_endpoint = "/lua/rest/v1/charts/host/map.lua"
local bubble_mode  = tonumber(_GET["bubble_mode"]) or 0
local current_label = MODES[bubble_mode + 1].label
local widget_name = 'hosts-map'

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.hosts_map)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/hosts_map.lua?bubble_mode=" .. bubble_mode
page_utils.print_navbar(i18n("hosts_map"), url, {
    {
        active = true,
        page_name = "home",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = url
    }
})

-- print the modes inside the dropdown
local select_options = {}

-- generate the dropdown menu
for i,v in pairs(MODES) do
   select_options[#select_options+1] = '<option '.. (bubble_mode == v.mode and 'selected' or '') ..' value="'..tostring(v.mode)..'">'..v.label..'</option>'
end

-- register the bubble chart for the hosts map
widget_gui_utils.register_bubble_chart(widget_name, 0, {
	Datasource(map_endpoint, {bubble_mode = bubble_mode})
})

template_utils.render("pages/hosts_map.template", {
	widget_gui_utils = widget_gui_utils,
	hosts_map = {
		select_options = table.concat(select_options, ''),
		bubble_mode = bubble_mode,
		current_label = current_label,
		widget_name = widget_name,
		map_endpoint = map_endpoint
	}
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
