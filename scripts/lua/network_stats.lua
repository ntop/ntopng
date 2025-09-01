--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template_utils = require("template_utils")
local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local json = require("dkjson")

function getPageTitle()
	local t = i18n("network_stats.networks")

	if not isEmptyString(_GET["version"]) then
		t = i18n("network_stats.networks_traffic_with_ipver",
				 {networks = t, ipver = _GET["version"]})
	end

	return t
end

local base_url = ntop.getHttpPrefix() .. "/lua/network_stats.lua"
local page_title = getPageTitle()
local ifid = interface.getId()

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(
    page_utils.menu_entries.networks)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(page_title, nav_url, {
    {
        active = true,
        label = page_title
    }
})
-- ##############################

-- render network maps tile chart
if (ntop.isPro()) then
    local networks_stats = interface.getNetworksStats()
    local numNetworks = table.len(networks_stats)

    if (numNetworks > 0) then
        local template_utils = require "template_utils"

        template_utils.render("pages/networks_map.html", {
            url = ntop.getHttpPrefix() ..
                '/lua/pro/rest/v2/get/host/top/network_hosts_score.lua',
            prefix = ntop.getHttpPrefix()
        })
    end
end

-- ##############################
-- render vue component


local context = {
    ifid = ifid,
    csrf = ntop.getRandomCSRFValue(),
    areTsEnabled = areInterfaceTimeseriesEnabled(ifid)
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageNetworksList",
    page_context  = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
