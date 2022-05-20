--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local json = require "dkjson"
local template_utils = require "template_utils"

local alert_entities = require "alert_entities"
local alert_store = require "alert_store"
local alert_store_utils = require "alert_store_utils"
local alert_store_instances = alert_store_utils.all_instances_factory()

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ######################################

local ifid = interface.getId()

local page = _GET["page"]
local status = _GET["status"] or "historical"
local row_id = _GET["row_id"]
local tstamp = _GET["tstamp"]

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

local label = i18n("alerts_dashboard.alert")
local details = {}
local alert = nil

if page and row_id and tstamp and alert_entities[page] then
   local alert_store_instance = alert_store_instances[alert_entities[page].alert_store_name]

   if alert_store_instance then
      alerts, recordsFiltered = alert_store_instance:select_request(nil, "*")
      if #alerts >= 1 then
         alert = alerts[1]
         -- formatted_alert = alert_store_instance:format_record(alert, false)
         details = alert_store_instance:get_alert_details(alert)
         label = label .. ": " .. alert_store_instance:get_alert_label(alert)
      end
   end
end

page_utils.print_navbar(label, url, pages)

-- #######################################

local context = {
   ifid = ifid,
   json = json,
   alert = alert,
   details = details,
}

template_utils.render("pages/alerts/alert_details.template", context)

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
