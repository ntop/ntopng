--
-- (C) 2019-24 - ntop.org
--
-- ##############################################
local flow_alert_keys = require "flow_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local blacklist_debug = 'ntopng.debug.alerts.blacklisted_flow'

-- ##############################################

local alert_blacklisted_server_contact = classes.class(alert)

-- ##############################################

alert_blacklisted_server_contact.meta = {
    alert_key = flow_alert_keys.flow_alert_blacklisted_server_contact,
    i18n_title = "flow_checks_config.blacklist_server_contact",
    icon = "fas fa-fw fa-exclamation",

    has_victim = true,
    has_attacker = true
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param info A flow info table fetched with `flow.getBlacklistedInfo()`
-- @return A table with the alert built
function alert_blacklisted_server_contact:init()
    -- Call the parent constructor
    self.super:init()
end

-- ##############################################

function alert_blacklisted_server_contact:add_extra_info(alert_json)
   if alert_json and alert_json.custom_cat_file and not isEmptyString(alert_json.custom_cat_file) then
        return " [ " .. i18n("flow_details.blacklist", { blacklist = alert_json.custom_cat_file or "" }) .. " ] "
    end
    return ""
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_blacklisted_server_contact.format(ifid, alert, alert_type_params)
    local blacklist = ""
    if not isEmptyString(alert_type_params["custom_cat_file"]) then
        blacklist = alert_type_params["custom_cat_file"]
    end
    -- The client is blacklisted, so simply use the Client as who description    
    local res = i18n("flow_details.blacklisted_flow_detailed", {
        who = i18n("server"),
        blacklist = blacklist
    })

    return res
end

-- #######################################################

return alert_blacklisted_server_contact
