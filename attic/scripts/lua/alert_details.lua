--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local json = require "dkjson"
local template_utils = require "template_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.detected_alerts)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ######################################

local page = _GET["page"]

-- ######################################

local url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?"

local pages = {
   {
      active = false,
      page_name = page,
      label = "<i class=\"fas fa-lg fa-home\"></i>"
   }
}

-- #######################################

local label = i18n("alerts_dashboard.alert")
page_utils.print_navbar(label, url, pages)

-- #######################################

local json_context = json.encode({
   url = "/lua/rest/v2/get/" .. page .. "/alert/alert_details.lua"
})

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageHistoricalFlow",
   page_context = json_context
})

-- #######################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
