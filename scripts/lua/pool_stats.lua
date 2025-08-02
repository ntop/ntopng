--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"

local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require("template_utils")
local page = _GET["page"]

local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')

-- if not nedge use hosts_pools
local menu = not ntop.isnEdge() and page_utils.menu_entries.host_pools or page_utils.menu_entries.users
local title = have_nedge and i18n("nedge.users_list") or i18n("pool_stats.host_pool_list")

page_utils.print_header_and_set_active_menu_entry(menu)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("pools.host_pools"), ntop.getHttpPrefix() .. "/lua/pool_stats_vue.lua", {{
    active = page == "overview" or not page,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("pools.host_pools") .. "\"></i>"
}})

local context = {
    csrf = ntop.getRandomCSRFValue(),
    ifid = interface.getId()
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageHostPools",
    page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")


