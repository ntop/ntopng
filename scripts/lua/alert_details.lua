--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local ui_utils = require "ui_utils"
local json = require "dkjson"
local dscp_consts = require "dscp_consts"
local template_utils = require "template_utils"

local alert_entities = require "alert_entities"
local alert_consts = require "alert_consts"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ######################################

local ifid = interface.getId()

local row_id = _GET["row_id"]

-- ######################################

local url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?"

local pages = {
   {
      active = true,
      page_name = "overview",
      label = i18n("overview"),
   }
}

-- #######################################

local alert = nil -- TODO get alert by row_id

local label = i18n("alerts_dashboard.alert")
if alert then
   -- label = label .. ": " .. getAlertLabel(alert)
end

page_utils.print_navbar(label, url, pages)

-- #######################################

local details = {}

if alert then

   -- TODO fill details

end -- alert

-- #######################################

local context = {
   ifid = ifid,
   json = json,
   alert = alert,
   details = details,
}

template_utils.render("pages/alerts/alert_details.template", context)

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
