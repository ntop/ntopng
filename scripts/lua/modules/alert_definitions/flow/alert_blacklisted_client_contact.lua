--
-- (C) 2019-26 - ntop.org
--
-- ##############################################
local flow_alert_keys = require "flow_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local blacklist_debug = 'ntopng.debug.alerts.blacklisted_flow'

-- ##############################################

local alert_blacklisted_client_contact = classes.class(alert)

-- ##############################################

alert_blacklisted_client_contact.meta = {
    alert_key = flow_alert_keys.flow_alert_blacklisted_client_contact,
    i18n_title = "flow_checks_config.blacklist_client_contact",
    icon = "fas fa-fw fa-exclamation",

    has_victim = true,
    has_attacker = true
}

-- ##############################################

-- @brief Return the name of the blacklist that matched the flow
-- @param alert_json The decoded alert JSON. Since the alert serialization rework the
--        check info (custom_cat_file) is under alerts.<alert_key>; the flow-level
--        "blacklist" field and the old top-level custom_cat_file are used as fallbacks
-- @return The blacklist name, or an empty string when unknown
local function get_blacklist_name(alert_json)
    if not alert_json then
        return ""
    end

    local alert_key = tostring(alert_blacklisted_client_contact.meta.alert_key)
    local check_info = alert_json.alerts and alert_json.alerts[alert_key]

    if check_info and not isEmptyString(check_info.custom_cat_file) then
        return check_info.custom_cat_file
    elseif not isEmptyString(alert_json.custom_cat_file) then
        return alert_json.custom_cat_file
    elseif not isEmptyString(alert_json.blacklist) then
        return alert_json.blacklist
    end

    return ""
end

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param info A flow info table fetched with `flow.getBlacklistedInfo()`
-- @return A table with the alert built
function alert_blacklisted_client_contact:init()
    -- Call the parent constructor
    self.super:init()
end

-- ##############################################

function alert_blacklisted_client_contact:add_extra_info(alert_json)
    local blacklist = get_blacklist_name(alert_json)

    if not isEmptyString(blacklist) then
        return " [ " .. i18n("flow_details.blacklist", { blacklist = blacklist }) .. " ] "
    end
    return ""
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_blacklisted_client_contact.format(ifid, alert, alert_type_params)
    local blacklist = get_blacklist_name(alert_type_params)
    -- The client is blacklisted, so simply use the Client as who description    
    local res = i18n("flow_details.blacklisted_flow_detailed", {
        who = i18n("client"),
        blacklist = blacklist
    })

    return res
end

-- #######################################################

return alert_blacklisted_client_contact
