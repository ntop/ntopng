--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_black_hole_contacts = classes.class(alert)

-- ##############################################

host_alert_black_hole_contacts.meta = {
  alert_key = host_alert_keys.host_alert_black_hole_contacts, -- host_alert_keys.lua
  i18n_title = "alerts_dashboard.blackhole_contacts",
  icon = "fas fa-fw fa-life-ring",
  has_attacker = true,
}

-- ##############################################

function host_alert_black_hole_contacts:init()
   -- Call the parent constructor
   self.super:init()

end

-- #######################################################

function host_alert_black_hole_contacts.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
  
  return i18n("alert_messages.blackhole_contacts",{
    entity = entity,
    as_client = alert_type_params.as_client
  })
  
end

-- #######################################################

return host_alert_black_hole_contacts
