--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require("dkjson")
local alert_creators = require "alert_creators"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_tcp_syn_scan_victim = classes.class(alert)

-- ##############################################

alert_tcp_syn_scan_victim.meta = {
  alert_key = other_alert_keys.alert_tcp_syn_scan_victim,
  i18n_title = "alerts_dashboard.tcp_syn_scan_victim",
  icon = "fas fa-fw fa-life-ring",
  entities = {
    alert_entities.network,
  },
  has_victim = true,
}

-- ##############################################

function alert_tcp_syn_scan_victim:init(metric, value, operator, threshold)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = alert_creators.createThresholdCross(metric, value, operator, threshold)
end

-- #######################################################

function alert_tcp_syn_scan_victim.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["entity_id"]), alert["name"])

  return i18n("alert_messages.syn_scan_victim", {
    entity = firstToUpper(entity),
    value = string.format("%u", math.ceil(alert_type_params.value)),
    threshold = alert_type_params.threshold,
  })
end

-- #######################################################

return alert_tcp_syn_scan_victim
