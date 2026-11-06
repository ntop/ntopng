--
-- (C) 2026 - ntop.org
--
-- Helpers shared by the blacklist-related alert definitions.
-- Keep this module free of heavy dependencies (e.g. alert_consts, alert_utils):
-- it is required from alert definitions, which alert_consts loads, so pulling
-- those modules in here would create a circular require.
--

local blacklist_utils = {}

-- ##############################################

-- @brief Return the name of the blacklist that matched a flow alert
-- @param alert_json The decoded alert JSON. Since the alert serialization rework the
--        check info (custom_cat_file) is under alerts.<alert_key>; the old top-level
--        custom_cat_file and the flow-level "blacklist" field are used as fallbacks
-- @param alert_key The alert key of the calling alert definition, used to locate its check info
-- @return The blacklist name, or an empty string when unknown
function blacklist_utils.get_blacklist_name(alert_json, alert_key)
    if not alert_json then
        return ""
    end

    local check_info = alert_json.alerts and alert_json.alerts[tostring(alert_key)]

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

return blacklist_utils
