--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local template_utils = require("template_utils")
local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local json = require("dkjson")

local base_url = ntop.getHttpPrefix() .. "/lua/network_stats.lua"
local ifid = interface.getId()
local page = _GET["page"] or "networks"

sendHTTPContentTypeHeader("text/html")

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.networks)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("network_stats.networks"), base_url, {
	{
		active = (page == "networks"),
		page_name = "networks",
		label = i18n("network_stats.networks"),
	},
	{
		active = (page == "sites"),
		page_name = "sites",
		label = i18n("sites_page.sites"),
	},
})
-- ##############################

if page == "networks" then
	-- render network maps tile chart
	if ntop.isPro and ntop.isPro() then
		local networks_stats = interface.getNetworksStats()
		local numNetworks = table.len(networks_stats)

		if numNetworks > 0 then
			local template_utils = require("template_utils")

			template_utils.render("pages/networks_map.html", {
				url = ntop.getHttpPrefix() .. "/lua/pro/rest/v2/get/host/top/network_hosts_score.lua",
				prefix = ntop.getHttpPrefix(),
			})
		end
	end

	-- ##############################
	-- render vue component

	local context = {
		ifid = ifid,
		csrf = ntop.getRandomCSRFValue(),
		areTsEnabled = areInterfaceTimeseriesEnabled(ifid), -- The networks timeseries are available when the Interface Timeseries are enabled
	}

	local json_context = json.encode(context)

	template_utils.render("pages/vue_page.template", {
		vue_page_name = "PageNetworks",
		page_context = json_context,
	})
elseif page == "sites" then
	-- ##############################
	-- render vue component

	local context = {
		ifid = ifid,
		csrf = ntop.getRandomCSRFValue(),
	}

	local json_context = json.encode(context)

	template_utils.render("pages/vue_page.template", {
		vue_page_name = "PageSites",
		page_context = json_context,
	})
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
