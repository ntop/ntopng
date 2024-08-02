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
    if alert_json and alert_json.blacklist and not isEmptyString(alert_json.blacklist) then
        return " [ " .. i18n("flow_details.blacklist", { blacklist = alert_json.blacklist or "" }) .. " ] "
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
    local who = {}

    if alert_type_params["cli_blacklisted"] and alert_type_params["cli_blacklisted"] ~= "0" then
        who[#who + 1] = {
            type = i18n("client"),
            blacklist_name = alert_type_params["custom_cat_file"]
        }
    end

    if alert_type_params["srv_blacklisted"] and alert_type_params["srv_blacklisted"] ~= "0" then
        who[#who + 1] = {
            type = i18n("server"),
            blacklist_name = alert_type_params["custom_cat_file"]
        }
    end

    local who_string = ""
    local black_list_names = ""
    for _, v in ipairs(who) do
        if v.type then
            if who_string ~= "" then
                who_string = who_string .. ", "
            end
            who_string = who_string .. v.type
        end

        if v.blacklist_name then
            if black_list_names ~= "" then
                black_list_names = black_list_names .. ", "
            end
            black_list_names = black_list_names .. v.blacklist_name
        end
    end
    local res = i18n("flow_details.blacklisted_flow_detailed", {
        who = who_string,
        blacklist = black_list_names
    })

    if #who == 0 and alert_type_params["cat_blacklisted"] then
        if ntop.getCache(blacklist_debug) == '1' then
            traceError(TRACE_NORMAL, TRACE_CONSOLE, "Blacklisted flow with no blacklisted client nor server. Info:\n")
            tprint(alert)
            tprint(alert_type_params)
        end
        local l7_protocol
        if tonumber(alert["l7_master_proto"]) and tonumber(alert["l7_proto"]) then
            l7_protocol =
                interface.getnDPIFullProtoName(tonumber(alert["l7_master_proto"]), tonumber(alert["l7_proto"]))
        end
        res = i18n("blacklisted_category", {
            config_href = "<a href='" .. ntop.getHttpPrefix() .. "/lua/admin/edit_categories.lua?application=" ..
                l7_protocol .. "' target='_blank'><i class='fas fa-cog fa-sm'></i></a>"
        })
    end

    return res
end

-- #######################################################

return alert_blacklisted_server_contact
