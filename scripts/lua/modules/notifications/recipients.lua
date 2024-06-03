--
-- (C) 2017-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "check_redis_prefs"
require "locales_utils"
require "label_utils"

local alert_consts = require "alert_consts"
local json = require "dkjson"
local alert_entity_builders = require "alert_entity_builders"


-- #################################
-- These are structs
local alert_severities = require "alert_severities"
local alert_entities = require "alert_entities"
local alert_categories = require "alert_categories"

-- #################################

local last_error_notification = 0
local MIN_ERROR_DELAY = 60 -- 1 minute
local ERROR_KEY = "ntopng.cache.%s.error_time"

local do_trace = false

-- Enable debug with:
-- redis-cli set "ntopng.prefs.vs.notifications_debug_enabled" "1"
-- systemctl restart ntopng
local debug_vs = ntop.getCache("ntopng.prefs.vs.notifications_debug_enabled") == "1"

-- ##############################################

local recipients = {}

-- ##############################################

recipients.MAX_NUM_RECIPIENTS = 64 -- Keep in sync with ntop_defines.h MAX_NUM_RECIPIENTS

-- ##############################################

recipients.FIRST_RECIPIENT_CREATED_CACHE_KEY = "ntopng.prefs.endpoint_hints.recipient_created"

local default_builtin_minimum_severity = alert_severities.notice.severity_id -- minimum severity is notice (to avoid flooding) (*****)

-- ##############################################

function recipients.get_notification_types()
    local notification_types = {
        alerts = {
            title = i18n('endpoint_notifications.alerts'),
            icon = 'fas fa-lg fa-exclamation-triangle text-warning'
        },
        reports = {
            title = i18n('report.reports'),
            icon = 'fa-regular fa-newspaper'
        },
        vulnerability_scans = {
            title = i18n('hosts_stats.page_scan_hosts.vulnerability_scan_reports'),
            icon = 'fa-solid fa-clipboard'
        }
    }

    return notification_types
end

-- ##############################################

local function debug_print(msg)
    if not do_trace then
        return
    end

    traceError(TRACE_NORMAL, TRACE_CONSOLE, msg)
end

-- ##############################################

-- Processes queued alerts and returns the information necessary to store them.
-- Alerts are only enqueued by AlertsQueue in C. From lua, the alerts_api
-- can be called directly as slow operations will be postponed
local function processStoreAlertFromQueue(alert)
    require "lua_utils_get"
    local entity_info = nil
    local type_info = nil

    interface.select(tostring(alert.ifid))

    if (alert.alert_id == "misconfigured_dhcp_range") then
        local router_info = {
            host = alert.router_ip,
            vlan = alert.vlan_id
        }
        entity_info = alert_entity_builders.hostAlertEntity(alert.client_ip, alert.vlan_id)
        type_info = alert_consts.alert_types.alert_ip_outsite_dhcp_range.new(router_info, alert.mac_address,
            alert.client_mac, alert.sender_mac)
        type_info:set_score_warning()
        type_info:set_subtype(string.format("%s_%s_%s", hostinfo2hostkey(router_info), alert.client_mac,
            alert.sender_mac))
    elseif (alert.alert_id == "mac_ip_association_change") then
        local name = getDeviceName(alert.new_mac)
        entity_info = alert_entity_builders.macEntity(alert.new_mac)
        type_info = alert_consts.alert_types.alert_mac_ip_association_change.new(name, alert.ip, alert.old_mac,
            alert.new_mac)

        type_info:set_score(100)
        type_info:set_subtype(string.format("%s_%s_%s", alert.ip, alert.old_mac, alert.new_mac))
    elseif (alert.alert_id == "login_failed") then
        entity_info = alert_entity_builders.userEntity(alert.user)
        type_info = alert_consts.alert_types.alert_login_failed.new()
        type_info:set_score_warning()
    elseif (alert.alert_id == "broadcast_domain_too_large") then
        entity_info = alert_entity_builders.macEntity(alert.src_mac)
        type_info = alert_consts.alert_types.alert_broadcast_domain_too_large.new(alert.src_mac, alert.dst_mac,
            alert.vlan_id, alert.spa, alert.tpa)
        type_info:set_score_warning()
        type_info:set_subtype(string.format("%u_%s_%s_%s_%s", alert.vlan_id, alert.src_mac, alert.spa, alert.dst_mac,
            alert.tpa))
    elseif ((alert.alert_id == "user_activity") and (alert.scope == "login")) then
        entity_info = alert_entity_builders.userEntity(alert.user)
        type_info = alert_consts.alert_types.alert_user_activity.new("login", nil, nil, nil, "authorized")
        type_info:set_score_notice()
        type_info:set_subtype("login//")
    elseif (alert.alert_id == "nfq_flushed") then
        entity_info = alert_entity_builders.interfaceAlertEntity(alert.ifid)
        type_info = alert_consts.alert_types.alert_nfq_flushed.new(getInterfaceName(alert.ifid), alert.pct, alert.tot,
            alert.dropped)

        type_info:set_score_error()
    else
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown alert type " .. (alert.alert_id or ""))
    end
    local category = alert_consts.get_category_by_id(alert.alert_category or 0)
    type_info:set_category(category)

    return entity_info, type_info
end


-- ##############################################

-- @brief Process notifications arriving from the internal C queue
--        Such notifications are transformed into stored alerts
local function process_notifications_from_c_queue()
    local budget = 1024 -- maximum 1024 alerts per call
    local budget_used = 0

    -- Check for alerts pushed by the datapath to an internal queue (from C)
    -- and store them (push them to the SQLite and Notification queues).
    -- NOTE: this is executed in a system VM, with no interfaces references
    while budget_used <= budget do
        local alert = ntop.popInternalAlerts()

        if alert == nil then
            break
        end

        if (verbose) then
            tprint(alert)
        end

        local entity_info, type_info = processStoreAlertFromQueue(alert)

        if type_info and entity_info then
            type_info:store(entity_info)
        end

        budget_used = budget_used + 1
    end
end

-- ##############################################

-- @brief Performs Initialization operations performed during startup
function recipients.initialize()
    local endpoints = require "endpoints"
    -- Initialize builtin recipients, that is, recipients always existing an not editable from the UI
    -- For each builtin configuration type, a configuration and a recipient is created

    -- Add categories
    local all_categories = {}
    for _, category in pairs(alert_categories) do
        all_categories[#all_categories + 1] = category.id
    end

    -- Add entities
    local all_entities = {}
    for _, entity_info in pairs(alert_entities) do
        all_entities[#all_entities + 1] = entity_info.entity_id
    end

    local host_pools = require "host_pools":create()
    -- Add host pools
    local all_host_pools = {}
    local pools = host_pools:get_all_pools()
    for _, pool in pairs(pools) do
        all_host_pools[#all_host_pools + 1] = pool.pool_id
    end

    -- Add active monitoring hosts
    local all_am_hosts = {} -- No hosts by default

    for endpoint_key, endpoint in pairs(endpoints.get_types()) do
        if endpoint.builtin then
            -- Delete (if existing) the old, string-keyed endpoint configuration
            endpoints.delete_config("builtin_config_" .. endpoint_key)

            -- Add the configuration
            local res = endpoints.add_config(endpoint_key --[[ the type of the endpoint--]] ,
                "builtin_endpoint_" .. endpoint_key --[[ the name of the endpoint configuration --]] , {} --[[ no default params --]] )

            -- Endpoint successfully created (or existing)
            if res and res.endpoint_id then
                -- And the recipient

                local recipient_res = recipients.add_recipient(res.endpoint_id --[[ the id of the endpoint --]] ,
                    "builtin_recipient_" .. endpoint_key --[[ the name of the endpoint recipient --]] , all_categories,
                    all_entities, default_builtin_minimum_severity, all_host_pools, -- host pools
                    all_am_hosts, -- active monitoring hosts
                    {} --[[ no recipient params --]] )

            end
        end
    end

    -- Delete (if existing) the old, string-keyed recipient and endpoint
    local sqlite_recipient = recipients.get_recipient_by_name("builtin_recipient_sqlite")
    if sqlite_recipient then
        recipients.delete_recipient(sqlite_recipient.recipient_id)
    end

    endpoints.delete_config("builtin_config_sqlite")

    -- Register all existing recipients in C to make sure ntopng can start with all the
    -- existing recipients properly loaded and ready for notification enqueues/dequeues

    local alert_store_db_recipient = recipients.get_recipient_by_name("builtin_recipient_alert_store_db")

    if (alert_store_db_recipient.recipient_id ~= 0) then
        print("WARNING ntopng found some inconsistencies in your recipient configuration\n")
        print("WARNING Please factory reset the recipient and endpoint configuration\n")
        alert_store_db_recipient.recipient_id = 0 -- setting it to the default value
    end
    for _, recipient in pairs(recipients.get_all_recipients()) do
        local flow_alert_types = nil
        local host_alert_types = nil
        local other_alert_types = nil
        local notifications_type = recipient.notifications_type or "alerts"

        if recipient.checks and table.len(recipient.checks) > 0 then
            for family, alerts in pairs(recipient.checks) do
                if #alerts > 0 then
                    if family == "flow" then
                        flow_alert_types = table.concat(alerts, ",")
                    elseif family == "host" then
                        host_alert_types = table.concat(alert, ",")
                    else -- other
                        if not isEmptyString(other_alert_types) then
                            other_alert_types = other_alert_types .. "," .. table.concat(alerts, ",")
                        else
                            other_alert_types = table.concat(alerts, ",")
                        end
                    end
                end
            end
        end

        ntop.recipient_register(recipient.recipient_id, recipient.minimum_severity,
            table.concat(recipient.check_categories, ','), table.concat(recipient.host_pools, ','),
            table.concat(recipient.check_entities, ','), flow_alert_types, host_alert_types, other_alert_types,
                ternary((notifications_type ~= "alerts"), true --[[skip alerts]] , false --[[dont skip alerts]] ))
    end
end

-- ##############################################

local function _get_recipients_lock_key()
    local key = string.format("ntopng.cache.recipients.recipients_lock")

    return key
end

-- ##############################################

local function _lock()
    local max_lock_duration = 5 -- seconds
    local max_lock_attempts = 5 -- give up after at most this number of attempts
    local lock_key = _get_recipients_lock_key()

    for i = 1, max_lock_attempts do
        local value_set = ntop.setnxCache(lock_key, "1", max_lock_duration)

        if value_set then
            return true -- lock acquired
        end

        ntop.msleep(1000)
    end

    return false -- lock not acquired
end

-- ##############################################

local function _unlock()
    ntop.delCache(_get_recipients_lock_key())
end

-- ##############################################

local function _get_recipients_prefix_key()
    local key = string.format("ntopng.prefs.recipients")

    return key
end

-- ##############################################

local function _get_recipient_ids_key()
    local key = string.format("%s.recipient_ids", _get_recipients_prefix_key())

    return key
end

-- ##############################################

local function _get_recipient_details_key(recipient_id)
    recipient_id = tonumber(recipient_id)

    if not recipient_id then
        -- A recipient id is always needed
        return nil
    end

    local key = string.format("%s.recipient_id_%d.details", _get_recipients_prefix_key(), recipient_id)

    return key
end

-- ##############################################

-- @brief Returns an array with all the currently assigned recipient ids
local function _get_assigned_recipient_ids()
    local res = {}

    local cur_recipient_ids = ntop.getMembersCache(_get_recipient_ids_key())

    for _, cur_recipient_id in pairs(cur_recipient_ids) do
        cur_recipient_id = tonumber(cur_recipient_id)
        res[#res + 1] = cur_recipient_id
    end

    return res
end

-- ##############################################

local function _assign_recipient_id()
    local cur_recipient_ids = _get_assigned_recipient_ids()
    local next_recipient_id

    -- Create a Lua table with currently assigned recipient ids as keys
    -- to ease the lookup
    local ids_by_key = {}
    for _, recipient_id in pairs(cur_recipient_ids) do
        ids_by_key[recipient_id] = true
    end

    -- Lookup for the first (smallest) available recipient id.
    -- This is to effectively recycle recipient ids no longer used, that is,
    -- belonging to deleted recipients
    for i = 0, recipients.MAX_NUM_RECIPIENTS - 1 do
        if not ids_by_key[i] then
            next_recipient_id = i
            break
        end
    end

    if next_recipient_id then
        -- Add the atomically assigned recipient id to the set of current recipient ids (set wants a string)
        ntop.setMembersCache(_get_recipient_ids_key(), string.format("%d", next_recipient_id))
    else
        -- All recipient ids exhausted
    end

    return next_recipient_id
end

-- ##############################################

-- @brief Coherence checks for the endpoint configuration parameters
-- @param endpoint_key A string with the notification endpoint key
-- @param recipient_params A table with endpoint recipient params that will be possibly sanitized
-- @return false with a description of the error, or true, with a table containing sanitized configuration params.
local function check_endpoint_recipient_params(endpoint_key, recipient_params)
    local endpoints = require "endpoints"
    if not recipient_params or not type(recipient_params) == "table" then
        return false, {
            status = "failed",
            error = {
                type = "invalid_recipient_params"
            }
        }
    end

    -- Create a safe_params table with only expected params
    local safe_params = {}
    -- So iterate across all expected params of the current endpoint
    for _, param in ipairs(endpoints.get_types()[endpoint_key].recipient_params) do
        -- param is a lua table so we access its elements
        local param_name = param["param_name"]
        if param_name then
            local optional = param["optional"]

            if recipient_params and recipient_params[param_name] and not safe_params[param_name] then
                safe_params[param_name] = recipient_params[param_name]
            elseif not optional then
                return false, {
                    status = "failed",
                    error = {
                        type = "missing_mandatory_param",
                        missing_param = param_name
                    }
                }
            end
        end
    end

    return true, {
        status = "OK",
        safe_params = safe_params
    }
end

-- ##############################################

-- @brief Set a configuration along with its params. Configuration name and params must be already sanitized
-- @param endpoint_id An integer identifier of the endpoint
-- @param endpoint_recipient_name A string with the recipient name
-- @param check_categories A Lua array with already-validated ids as found in `checks.check_categories` or nil to indicate all categories
-- @param check_entities A Lua array with already-validated ids as found in `checks.check_entities` or nil to indicate all entities
-- @param minimum_severity An already-validated integer alert severity id as found in `alert_severities` or nil to indicate no minimum severity
-- @param checks An already-validated integer alert id or nil to indicate filter on the alert ids
-- @param safe_params A table with endpoint recipient params already sanitized
-- @return nil
local function _set_endpoint_recipient_params(recipient_data, safe_params)
    -- Write the endpoint recipient config into another hash
    local k = _get_recipient_details_key(recipient_data.recipient_id)
    -- Add the preference to silence the same alerts for a specific recipient, by default is set to true (1)
    ntop.setCache("ntopng.prefs.silence_multiple_alerts." .. recipient_data.recipient_id,
        ternary(recipient_data.silence_alerts and recipient_data.silence_alerts == "false", '0', '1'))
    ntop.setCache(k, json.encode({
        endpoint_id = recipient_data.endpoint_id,
        recipient_name = recipient_data.endpoint_recipient_name,
        check_categories = recipient_data.check_categories,
        check_entities = recipient_data.check_entities,
        minimum_severity = recipient_data.minimum_severity,
        host_pools = recipient_data.host_pools_ids,
        am_hosts = recipient_data.am_hosts_ids,
        checks = recipient_data.checks,
        silence_alerts = recipient_data.silence_alerts,
        notifications_type = recipient_data.notifications_type,
        recipient_params = safe_params
    }))

    return recipient_data.recipient_id
end

-- ##############################################

local function format_recipient_checks(checks_list)
    if isEmptyString(checks_list) then
        return nil
    end
    local list = checks_list:split(",") or {checks_list}
    local formatted_list = {}
    local num_alerts = 0

    for _, check in pairs(list or {}) do
        local alert_info = check:split("_")

        if table.len(alert_info) == 2 then
            local alert_id = alert_info[1]
            local entity_id = alert_info[2]
            local entity = alert_consts.alertEntityRaw(entity_id)

            if not formatted_list[entity] then
                formatted_list[entity] = {}
            end

            formatted_list[entity][#formatted_list[entity] + 1] = alert_id
            num_alerts = num_alerts + 1
        end
    end

    if num_alerts == 0 then
        return nil
    end

    return formatted_list
end

-- ##############################################

-- @brief Add a new recipient of an existing endpoint configuration and returns its id
-- @param endpoint_id An integer identifier of the endpoint
-- @param endpoint_recipient_name A string with the recipient name
-- @param check_categories A Lua array with already-validated ids as found in `checks.check_categories` or nil to indicate all categories
-- @param check_entities A Lua array with already-validated ids as found in `checks.check_entities` or nil to indicate all entities
-- @param minimum_severity An already-validated integer alert severity id as found in `alert_severities` or nil to indicate no minimum severity
-- @param recipient_params A table with endpoint recipient params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed", and the recipient id assigned to the newly added recipient. When "failed", the table contains another key "error" with an indication of the issue
function recipients.add_recipient(endpoint_id, endpoint_recipient_name, check_categories, check_entities,
    minimum_severity, host_pools_ids, am_hosts_ids, recipient_params)
    local endpoints = require "endpoints"
    local locked = _lock()
    local res = {
        status = "failed",
        error = {
            type = "internal_error"
        }
    }

    if locked then
        local ec = endpoints.get_endpoint_config(endpoint_id)

        if ec["status"] == "OK" and endpoint_recipient_name then

            -- Is the endpoint already existing?
            local same_recipient = recipients.get_recipient_by_name(endpoint_recipient_name)
            if same_recipient then
                res = {
                    status = "failed",
                    error = {
                        type = "endpoint_recipient_already_existing",
                        endpoint_recipient_name = endpoint_recipient_name
                    }
                }
            else
                local endpoint_key = ec["endpoint_key"]
                local ok, status = check_endpoint_recipient_params(endpoint_key, recipient_params)

                if ok then
                    local safe_params = status["safe_params"]
                    -- Get the list of checks to deliver the alerts
                    local checks = format_recipient_checks(recipient_params["recipient_checks"] or "")
                    local silence_alerts = recipient_params["recipient_silence_multiple_alerts"]
                    local notifications_type = recipient_params["recipient_notifications_type"] or "alerts"
                    local flow_alert_types = nil
                    local host_alert_types = nil
                    local other_alert_types = nil

                    if checks and table.len(checks) > 0 then
                        for family, alerts in pairs(checks) do
                            if #alerts > 0 then
                                if family == "flow" then
                                    flow_alert_types = table.concat(alerts, ",")
                                elseif family == "host" then
                                    host_alert_types = table.concat(alert, ",")
                                else -- other
                                    if not isEmptyString(other_alert_types) then
                                        other_alert_types = other_alert_types .. "," .. table.concat(alerts, ",")
                                    else
                                        other_alert_types = table.concat(alerts, ",")
                                    end
                                end
                            end
                        end
                    end

                    -- Assign the recipient id
                    local recipient_id = _assign_recipient_id()
                    -- Persist the configuration
                    _set_endpoint_recipient_params({
                        endpoint_id = endpoint_id,
                        recipient_id = recipient_id,
                        endpoint_recipient_name = endpoint_recipient_name,
                        check_categories = check_categories,
                        check_entities = check_entities,
                        minimum_severity = minimum_severity,
                        host_pools_ids = host_pools_ids,
                        am_hosts_ids = am_hosts_ids,
                        silence_alerts = silence_alerts,
                        checks = checks,
                        notifications_type = notifications_type
                    }, safe_params)

                    -- Finally, register the recipient in C so we can start enqueuing/dequeuing notifications
                    ntop.recipient_register(recipient_id, minimum_severity, table.concat(check_categories, ','),
                        table.concat(host_pools_ids, ','), table.concat(check_entities, ','),
                        flow_alert_types, -- Flow Alerts bitmap
                        host_alert_types, -- Host Alerts bitmap
                        other_alert_types, -- Other Alerts bitmap
                        ternary((notifications_type ~= "alerts"), true --[[skip alerts]] , false --[[dont skip alerts]] ))

                    -- Set a flag to indicate that a recipient has been created
                    if not ec.endpoint_conf.builtin and
                        isEmptyString(ntop.getPref(recipients.FIRST_RECIPIENT_CREATED_CACHE_KEY)) then
                        ntop.setPref(recipients.FIRST_RECIPIENT_CREATED_CACHE_KEY, "1")
                    end

                    res = {
                        status = "OK",
                        recipient_id = recipient_id
                    }
                else
                    res = status
                end
            end
        else
            res = {
                status = "failed",
                error = {
                    type = "bad_endpoint"
                }
            }
        end

        _unlock()
    end

    return res
end

-- ##############################################

-- @brief Edit the recipient parameters of an existing endpoint configuration
-- @param recipient_id The integer recipient identificator
-- @param endpoint_recipient_name A string with the recipient name
-- @param check_categories A Lua array with already-validated ids as found in `checks.check_categories` or nil to indicate all categories
-- @param minimum_severity An already-validated integer alert severity id as found in `alert_severities` or nil to indicate no minimum severity
-- @param recipient_params A table with endpoint recipient params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function recipients.edit_recipient(recipient_id, endpoint_recipient_name, check_categories, check_entities,
    minimum_severity, host_pools_ids, am_hosts_ids, recipient_params)
    local endpoints = require "endpoints"
    local locked = _lock()
    local res = {
        status = "failed"
    }

    if locked then
        local rc = recipients.get_recipient(recipient_id)

        if not rc then
            res = {
                status = "failed",
                error = {
                    type = "endpoint_recipient_not_existing",
                    endpoint_recipient_name = endpoint_recipient_name
                }
            }
        else
            local ec = endpoints.get_endpoint_config(rc["endpoint_id"])

            if ec["status"] ~= "OK" then
                res = ec
            else
                -- Are the submitted params those expected by the endpoint?
                local ok, status = check_endpoint_recipient_params(ec["endpoint_key"], recipient_params)

                if not ok then
                    res = status
                else
                    local safe_params = status["safe_params"]
                    local checks = format_recipient_checks(recipient_params["recipient_checks"] or "")
                    local silence_alerts = recipient_params["recipient_silence_multiple_alerts"]
                    local notifications_type = recipient_params["recipient_notifications_type"] or "alerts"
                    local flow_alert_types = nil
                    local host_alert_types = nil
                    local other_alert_types = nil

                    if checks and table.len(checks) > 0 then
                        for family, alerts in pairs(checks) do
                            if #alerts > 0 then
                                if family == "flow" then
                                    flow_alert_types = table.concat(alerts, ",")
                                elseif family == "host" then
                                    host_alert_types = table.concat(alert, ",")
                                else -- other
                                    if not isEmptyString(other_alert_types) then
                                        other_alert_types = other_alert_types .. "," .. table.concat(alerts, ",")
                                    else
                                        other_alert_types = table.concat(alerts, ",")
                                    end
                                end
                            end
                        end
                    end

                    _set_endpoint_recipient_params({
                        endpoint_id = rc["endpoint_id"],
                        recipient_id = recipient_id,
                        endpoint_recipient_name = endpoint_recipient_name,
                        check_categories = check_categories,
                        check_entities = check_entities,
                        minimum_severity = minimum_severity,
                        host_pools_ids = host_pools_ids,
                        am_hosts_ids = am_hosts_ids,
                        silence_alerts = silence_alerts,
                        checks = checks,
                        notifications_type = notifications_type
                    }, safe_params)

                    -- Finally, register the recipient in C to make sure also the C knows about this edit
                    -- and periodic scripts can be reloaded
                    ntop.recipient_register(tonumber(recipient_id), minimum_severity,
                        table.concat(check_categories, ','), table.concat(host_pools_ids, ','),
                        table.concat(check_entities, ','), flow_alert_types, host_alert_types, other_alert_types,
                            ternary((notifications_type ~= "alerts"), true --[[skip alerts]] , false --[[dont skip alerts]] ))

                    res = {
                        status = "OK"
                    }
                end
            end
        end

        _unlock()
    end

    return res
end

-- ##############################################

function recipients.delete_recipient(recipient_id)
    recipient_id = tonumber(recipient_id)
    local ret = false

    local locked = _lock()

    if locked then
        -- Make sure the recipient exists
        local cur_recipient_details = recipients.get_recipient(recipient_id)

        if cur_recipient_details then
            -- Remove the key with all the recipient details (e.g., with members)
            ntop.delCache(_get_recipient_details_key(recipient_id))

            -- Remove the recipient_id from the set of all currently existing recipient ids
            ntop.delMembersCache(_get_recipient_ids_key(), string.format("%d", recipient_id))

            -- Finally, remove the recipient from C
            ntop.recipient_delete(recipient_id)
            ret = true
        end

        _unlock()
    end

    return ret
end

-- ##############################################

-- @brief Delete all recipients having the given `endpoint_id`
-- @param endpoint_id An integer identifier of the endpoint
-- @return nil
function recipients.delete_recipients_by_conf(endpoint_id)
    local ret = false

    local all_recipients = recipients.get_all_recipients()
    for _, recipient in pairs(all_recipients) do
        -- Use tostring for backwards compatibility
        if tostring(recipient.endpoint_id) == tostring(endpoint_id) then
            recipients.delete_recipient(recipient.recipient_id)
        end
    end
end

-- ##############################################

-- @brief Get all recipients having the given `endpoint_conf_name`
-- @param endpoint_id An integer identifier of the endpoint
-- @return A lua array with recipients
function recipients.get_recipients_by_conf(endpoint_id, include_stats)
    local res = {}

    local all_recipients = recipients.get_all_recipients(false, include_stats)

    for _, recipient in pairs(all_recipients) do
        -- Use tostring for backward compatibility, to handle
        -- both integer and string endpoint_id
        if tostring(recipient.endpoint_id) == tostring(endpoint_id) then
            res[#res + 1] = recipient
        end
    end

    return res
end

-- #################################################################

function recipients.test_recipient(endpoint_id, recipient_params)
    local endpoints = require "endpoints"
    -- Get endpoint config

    local ec = endpoints.get_endpoint_config(endpoint_id)
    if ec["status"] ~= "OK" then
        return ec
    end

    -- Check recipient parameters

    local endpoint_key = ec["endpoint_key"]
    ok, status = check_endpoint_recipient_params(endpoint_key, recipient_params)

    if not ok then
        return status
    end

    local safe_params = status["safe_params"]

    -- Create test recipient
    local recipient = {
        endpoint_id = ec["endpoint_id"],
        endpoint_conf_name = ec["endpoint_conf_name"],
        endpoint_conf = ec["endpoint_conf"],
        endpoint_key = ec["endpoint_key"],
        recipient_params = safe_params
    }

    -- Get endpoint module
    local modules_by_name = endpoints.get_types()
    local module_name = recipient.endpoint_key
    local m = modules_by_name[module_name]
    if not m then
        return {
            status = "failed",
            error = {
                type = "endpoint_module_not_existing",
                endpoint_recipient_name = recipient.endpoint_conf.endpoint_key
            }
        }
    end

    -- Run test

    if not m.runTest then
        return {
            status = "failed",
            error = {
                type = "endpoint_test_not_available",
                endpoint_recipient_name = recipient.endpoint_conf.endpoint_key
            }
        }
    end

    local success, message = m.runTest(recipient)

    if success then
        return {
            status = "OK"
        }
    else
        return {
            status = "failed",
            error = {
                type = "endpoint_test_failure",
                message = message
            }
        }
    end
end

-- ##############################################

function recipients.get_recipient(recipient_id, include_stats)
    local endpoints = require "endpoints"
    local recipient_details
    local recipient_details_key = _get_recipient_details_key(recipient_id)

    -- Attempt at retrieving the recipient details key and at decoding it from JSON
    if recipient_details_key then
        local recipient_details_str = ntop.getCache(recipient_details_key)
        recipient_details = json.decode(recipient_details_str)
        if recipient_details then
            -- Add the integer recipient id
            recipient_details["recipient_id"] = tonumber(recipient_id)

            -- Add also the endpoint configuration name
            -- Use the endpoint id to get the endpoint configuration (use endpoint_conf_name for the old endpoints)
            local ec = endpoints.get_endpoint_config(recipient_details["endpoint_id"] or
                                                         recipient_details["endpoint_conf_name"])
            recipient_details["endpoint_conf_name"] = ec["endpoint_conf_name"]
            recipient_details["endpoint_id"] = ec["endpoint_id"]

            -- Add check categories. nil or empty check categories read from the JSON imply ANY AVAILABLE category
            if not recipient_details["check_categories"] or #recipient_details["check_categories"] == 0 then
                if not recipient_details["check_categories"] then
                    recipient_details["check_categories"] = {}
                end

                for _, category in pairs(alert_categories) do
                    recipient_details["check_categories"][#recipient_details["check_categories"] + 1] = category.id
                end
            end

            -- Add check entities. nil or empty check entities read from the JSON imply ANY AVAILABLE entity
            if not recipient_details["check_entities"] or #recipient_details["check_entities"] == 0 then
                if not recipient_details["check_entities"] then
                    recipient_details["check_entities"] = {}
                end

                for _, entity_info in pairs(alert_entities) do
                    recipient_details["check_entities"][#recipient_details["check_entities"] + 1] =
                        entity_info.entity_id
                end
            end

            -- Add host pools
            if not recipient_details["host_pools"] then
                local host_pools = require "host_pools":create()
                local pools = host_pools:get_all_pools()

                if (recipient_details["host_pools"] == nil) then
                    recipient_details["host_pools"] = {}
                end

                for _, pool in pairs(pools) do
                    recipient_details["host_pools"][#recipient_details["host_pools"] + 1] = pool.pool_id
                end
            end

            -- Add active monitoring hosts
            if not recipient_details["am_hosts"] then
                -- No hosts by default
                recipient_details["am_hosts"] = {}
            end

            -- Add minimum alert severity. nil or empty minimum severity assumes a minimum severity of notice
            if not tonumber(recipient_details["minimum_severity"]) then
                recipient_details["minimum_severity"] = default_builtin_minimum_severity
            end

            if ec then
                recipient_details["endpoint_conf"] = ec["endpoint_conf"]
                recipient_details["endpoint_key"] = ec["endpoint_key"]

                local modules_by_name = endpoints.get_types()
                local cur_module = modules_by_name[recipient_details["endpoint_key"]]
                if cur_module and cur_module.format_recipient_params then
                    -- Add a formatted output of recipient params
                    recipient_details["recipient_params_fmt"] =
                        cur_module.format_recipient_params(recipient_details["recipient_params"])
                else
                    -- A default
                    recipient_details["recipient_params_fmt"] = ""
                end
            end

            if include_stats then
                -- Read stats from C
                recipient_details["stats"] = ntop.recipient_stats(recipient_details["recipient_id"])
            end
        end
    end

    -- Upon success, recipient details are returned, otherwise nil
    return recipient_details
end

-- ##############################################

function recipients.get_all_recipients(exclude_builtin, include_stats)
    local res = {}
    local cur_recipient_ids = _get_assigned_recipient_ids()

    for _, recipient_id in pairs(cur_recipient_ids) do
        local recipient_details = recipients.get_recipient(recipient_id, include_stats)

        if recipient_details and (not exclude_builtin or not recipient_details.endpoint_conf.builtin) then
            res[#res + 1] = recipient_details
        end
    end

    return res
end

-- ##############################################

function recipients.get_recipient_by_name(name)
    local cur_recipient_ids = _get_assigned_recipient_ids()

    for _, recipient_id in pairs(cur_recipient_ids) do
        local recipient_details = recipients.get_recipient(recipient_id)

        if recipient_details and recipient_details["recipient_name"] and recipient_details["recipient_name"] == name then
            return recipient_details
        end
    end

    return nil
end

-- ##############################################

local builtin_recipients_cache
function recipients.get_builtin_recipients()
    -- Currently, only sqlite is the builtin recipient
    -- created in startup.lua calling recipients.initialize()
    if not builtin_recipients_cache then
        local alert_store_db_recipient = recipients.get_recipient_by_name("builtin_recipient_alert_store_db")
        builtin_recipients_cache = {alert_store_db_recipient.recipient_id}
    end

    return builtin_recipients_cache
end

-- ##############################################

local function get_notification_category(notification, current_script)
    -- Category is first read from the current_script. If no current_script is found (e.g., for
    -- alerts generated from the C++ core such as start after anomalous termination), the category
    -- is guessed from the alert entity.
    local entity_id = notification.entity_id

    local cur_category_id
    if current_script and current_script.category and current_script.category.id then
        -- Found in the script
        cur_category_id = current_script.category.id
    else
        --- Determined from the entity
        if entity_id == alert_entities.system.entity_id then
            -- System alert entity becomes system
            cur_category_id = alert_categories.system.id
        else
            -- All other entities fall into other category
            cur_category_id = alert_categories.other.id
        end
    end

    return cur_category_id or alert_categories.other.id
end

function recipients.format_checks_list(recipients)
    for _, recipient in pairs(recipients or {}) do
        local check_list = {}
        for entity, alert_list in pairs(recipient.checks or {}) do
            for _, alert in pairs(alert_list or {}) do
                check_list[#check_list + 1] = string.format("%d_%d", alert, alert_entities[entity].entity_id)
            end
        end
        recipient.checks = check_list
    end

    return recipients
end

-- ##############################################

-- @brief This function deliver a notification to a specific recipient id
--        without checking for filters, ecc.
-- @param notification An notification in table format
-- @param name The recipient name to which send the notification
-- @return boolean
function recipients.sendMessageByRecipientName(notification, name)
    local recipient = recipients.get_recipient_by_name(name)
    if recipient and recipient.recipient_id then
        recipients.dispatch_notification(notification, nil, nil, recipient.recipient_id)
        return true
    end
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "Trying to deliver a notification to a non-existing recipient " .. name)
    return false
end

-- ##############################################

-- @brief This function deliver a notification to all recipients with 
--        the same notification_type configured
-- @param notification An notification in table format
-- @param notification_type The notification type
-- @return boolean
function recipients.sendMessageByNotificationType(notification, notification_type)
    notification.notification_type = notification_type
    return recipients.dispatch_notification(notification, nil, notification_type, nil)
end

-- #############################################

-- @brief Dispatches a `notification` to all the interested recipients
-- Note: this is similar to RecipientQueue::enqueue does in C++)
-- @param notification An alert notification
-- @param current_script The user script which has triggered this notification - can be nil if the script is unknown or not available
-- @return nil
function recipients.dispatch_notification(notification, current_script, notification_type, recipient_id)
    local is_vs = (notification_type == 'vulnerability_scans')

    if not notification then
        -- traceError(TRACE_ERROR, TRACE_CONSOLE, "Internal error. Empty notification")
        -- tprint(debug.traceback())
    end

    if debug_vs and is_vs then
        traceError(TRACE_NORMAL, TRACE_CONSOLE, "VS: dispatching notification")
    end

    if not notification.score then
        notification.score = 0
    end

    local notification_category = get_notification_category(notification, current_script)

    local recipients = recipients.get_all_recipients()

    if #recipients > 0 then

        -- Use pcall to catch possible exceptions, e.g., (string expected, got light userdata)
        local status, json_notification = pcall(function()
            return json.encode(notification)
        end)

        -- If an exception occurred, print the notification and exit
        if not status then
            traceError(TRACE_ERROR, TRACE_CONSOLE, "Failure encoding notification")
            tprint(notification)
            return
        end

        for _, recipient in ipairs(recipients) do
            local recipient_ok = true

            if debug_vs and is_vs then
                traceError(TRACE_NORMAL, TRACE_CONSOLE, "VS: evaluating recipient")
                tprint(recipient)
            end

            -- If recipient_id is not nil, it means that notification has to be 
            -- dispatched only to the specific recipient
            if recipient_ok and recipient_id then
                if recipient_id == recipient.recipient_id then
                    goto skip_filters
                end
                recipient_ok = false
            end

            -- Checking if a specific notification type is requested
            -- otherwise go to the alerts filters
            if recipient_ok and notification_type and notification_type ~= "alerts" then
                if recipient.notifications_type and recipient.notifications_type ~= "alerts" then
                    if notification_type == recipient.notifications_type then
                        if debug_vs and is_vs then
                            traceError(TRACE_NORMAL, TRACE_CONSOLE, "VS: recipient match!")
                        end
                        goto skip_filters
                    end
                end

                recipient_ok = false
            end

            -- Check Category
            if recipient_ok and notification_category and recipient.check_categories ~= nil then
                -- Make sure the user script category belongs to the recipient check categories
                recipient_ok = false
                for _, check_category in pairs(recipient.check_categories) do
                    if check_category == notification_category then
                        recipient_ok = true
                    end
                end

                if not recipient_ok then
                    debug_print("X Discarding " .. notification.entity_val .. " alert for recipient " ..
                                    recipient.recipient_name .. " due to category selection")
                end
            end

            -- Check Entity
            if recipient_ok and notification.entity_id and recipient.check_entities ~= nil then
                -- Make sure the user script entity belongs to the recipient check entities
                recipient_ok = false
                for _, check_entity_id in pairs(recipient.check_entities) do
                    if check_entity_id == notification.entity_id then
                        recipient_ok = true
                    end
                end

                if not recipient_ok then
                    debug_print("X Discarding " .. notification.entity_val .. " alert for recipient " ..
                                    recipient.recipient_name .. " due to entity selection")
                end
            end

            -- Check Severity
            if recipient_ok then
                if notification.severity and recipient.minimum_severity ~= nil and notification.severity <
                    recipient.minimum_severity then
                    -- If the current alert severity is less than the minimum requested severity exclude the recipient
                    debug_print("X Discarding " .. notification.entity_val .. " alert for recipient " ..
                                    recipient.recipient_name .. " due to severity")
                    recipient_ok = false
                end
            end

            -- Check Alerts List
            if recipient_ok and notification.alert_id and notification.entity_id ~= nil then
                -- Apply the filters if available
                if table.len(recipient["checks"] or {}) > 0 then
                    recipient_ok = false
                    for entity, alert_list in pairs(recipient["checks"] or {}) do
                        -- First of all check if the entity_id of the alert is the same of the one to filter
                        if alert_entities[entity].entity_id == notification.entity_id then
                            -- Then check the alert_id
                            for _, alert_id in pairs(alert_list) do
                                -- Same ID, break the loop and continue, the alert is OK
                                if tonumber(alert_id) == notification.alert_id then
                                    recipient_ok = true
                                    break
                                end
                            end
                        end
                    end

                    if not recipient_ok then
                        debug_print("X Discarding " .. notification.entity_val .. " alert for recipient " ..
                                        recipient.recipient_name .. " due to entity selection")
                    end
                end
            end

            -- Check Pool
            if recipient_ok then
                if notification.host_pool_id then
                    if recipient.recipient_name ~= "builtin_recipient_alert_store_db" and recipient.host_pools then
                        local host_pools_map = swapKeysValues(recipient.host_pools)
                        if not host_pools_map[notification.host_pool_id] then
                            debug_print("X Discarding " .. notification.entity_val .. " alert for recipient " ..
                                            recipient.recipient_name .. " due to host pool selection (" ..
                                            notification.host_pool_id .. ")")
                            recipient_ok = false
                        end
                    end
                end
            end

            if recipient_ok then
                if notification.entity_id == alert_entities.am_host.entity_id and notification.entity_val then
                    if recipient.recipient_name ~= "builtin_recipient_alert_store_db" then
                        local am_measurement
                        local am_host
                        local parts = split(notification.entity_val, "@")
                        if #parts == 2 then
                            am_measurement = parts[1]
                            am_host = parts[2]
                        end

                        if am_measurement == "vs" then
                            -- Vulnerability scan - enabled for any hosts
                        else
                            -- Active Monitoring measurements
                            if recipient.am_hosts then
                                local am_hosts_map = swapKeysValues(recipient.am_hosts)
                                if not am_hosts_map[notification.entity_val] then
                                    recipient_ok = false
                                    debug_print("X Discarding " .. notification.entity_val .. " alert for recipient " ..
                                                    recipient.recipient_name .. " due to AM selection")
                                end
                            end
                        end
                    end
                end
            end

            ::skip_filters::

            if recipient_ok then

                -- Enqueue alert
                --debug_print("Delivering alert for entity id " .. notification.entity_id .. " to recipient " .. recipient.recipient_name)

                if debug_vs and is_vs then
                    traceError(TRACE_NORMAL, TRACE_CONSOLE, "VS: enqueueing notification to recipient")
                end

                ntop.recipient_enqueue(recipient.recipient_id,
                    json_notification --[[ alert --]] , 
                    notification.score,
                    notification.alert_id,
                    notification.entity_id,
                    notification_category)
            end
        end

        ::continue::
    end
end

-- ##############################################

-- @brief Processes notifications dispatched to recipients
-- @param ready_recipients A table with recipients ready to export. Recipients who completed their work are removed from the table
-- @param now An epoch of the current time
-- @param periodic_frequency The frequency, in seconds, of this call
-- @param force_export A boolean telling to forcefully export dispatched notifications
-- @return nil
local function process_notifications(ready_recipients, now, deadline, periodic_frequency, force_export)
    -- Total budget available, which is a multiple of the periodic_frequency
    -- Budget in this case is the maximum number of notifications which can
    -- be processed during this call.
    local total_budget = 1000 * periodic_frequency
    -- To avoid having one recipient jeopardizing all the resources, the total
    -- budget is consumed in chunks, that is, recipients are iterated multiple times
    -- and, each time any recipient has a maximum budget for every iteration.
    local budget_per_iter = total_budget / #ready_recipients

    -- Put a cap of 1000 messages/iteration
    if (budget_per_iter > 1000) then
        budget_per_iter = 1000
    end

    -- Cycle until there are ready_recipients and total_budget left
    local cur_time = os.time()
    while #ready_recipients > 0 and total_budget >= 0 and cur_time <= deadline and
        (force_export or not ntop.isDeadlineApproaching()) do
        for i = #ready_recipients, 1, -1 do
            local ready_recipient = ready_recipients[i]
            local recipient = ready_recipient.recipient
            local m = ready_recipient.mod

            debug_print("Dequeuing alerts for ready recipient: " .. recipient.recipient_name .. " recipient_id: " ..
                            recipient.recipient_id)

            if last_error_notification == 0 then
                last_error_notification = tonumber(ntop.getCache(string.format(ERROR_KEY, recipient.recipient_name))) or
                                              0
            end

            if m.dequeueRecipientAlerts and (now > MIN_ERROR_DELAY + last_error_notification) then
                local rv = m.dequeueRecipientAlerts(recipient, budget_per_iter)

                -- If the recipient has failed (not rv.success) or
                -- if it has no more work to do (not rv.more_available)
                -- it can be removed from the array of ready recipients.
                if not rv.success or not rv.more_available then
                    table.remove(ready_recipients, i)

                    debug_print("Ready recipient done: " .. recipient.recipient_name)

                    if not rv.success then
                        last_error_notification = now
                        ntop.setCache(string.format(ERROR_KEY, recipient.recipient_name), now)
                        local msg = rv.error_message or "Unknown Error"
                        traceError(TRACE_ERROR, TRACE_CONSOLE,
                            "Error while sending notifications via " .. recipient.recipient_name .. " " .. msg)
                    end
                end
            end
        end

        -- Update the total budget
        total_budget = total_budget - budget_per_iter
        cur_time = os.time()
    end

    if do_trace then
        if #ready_recipients > 0 then
            debug_print("Deadline approaching: " .. tostring(deadline < cur_time))
            debug_print("Budget left: " .. total_budget)
            debug_print("The following recipients were unable to dequeue all their notifications")
            for _, ready_recipient in pairs(ready_recipients) do
                debug_print(" " .. ready_recipient.recipient.recipient_name)
            end
        end
    end
end

-- #################################################################

-- @brief Check if it time to export notifications towards recipient identified with `recipient_id`, depending on its `xport_frequency`
-- @param recipient_id The integer recipient identifier
-- @param export_frequency The recipient export frequency in seconds
-- @param now The current epoch
-- @return True if it is time to export notifications towards the recipient, or False otherwise
local function check_endpoint_export(recipient_id, export_frequency, now)
    -- Read the epoch of the last time the recipient was used
    local last_use = ntop.recipient_last_use(recipient_id)
    local res = last_use + export_frequency <= now

    return res
end

-- #################################################################

-- @brief Processes notifications dispatched to recipients
-- @param now An epoch of the current time
-- @param periodic_frequency The frequency, in seconds, of this call
-- @param force_export A boolean telling to forcefully export dispatched notifications
-- @return nil
local cached_recipients
function recipients.process_notifications(now, deadline, periodic_frequency, force_export)
    local endpoints = require "endpoints"
    if not areAlertsEnabled() then
        return
    end

    -- Dequeue alerts from the internal C queue
    process_notifications_from_c_queue()

    -- Dequeue alerts enqueued into per-recipient queues from checks
    if not cached_recipients then
        -- Cache recipients to avoid re-reading them constantly
        -- NOTE: in case of recipient add/edit/delete, the vm executing this
        -- function is reloaded and thus, recipients, are re-cached automatically
        cached_recipients = recipients.get_all_recipients()
    end
    local modules_by_name = endpoints.get_types()
    local ready_recipients = {}

    -- Check, among all available recipients, those that are ready to export, depending on
    -- their EXPORT_FREQUENCY
    for _, recipient in pairs(cached_recipients) do
        local module_name = recipient.endpoint_key

        if modules_by_name[module_name] then
            local m = modules_by_name[module_name]
            if force_export or check_endpoint_export(recipient.recipient_id, m.EXPORT_FREQUENCY, now) then
                -- This recipient is ready for export...
                local ready_recipient = {
                    recipient = recipient,
                    recipient_id = recipient.recipient_id,
                    mod = m
                }

                ready_recipients[#ready_recipients + 1] = ready_recipient
            end
        end
    end

    process_notifications(ready_recipients, now, deadline, periodic_frequency, force_export)
end

-- ##############################################

-- @brief Cleanup all but builtin recipients
function recipients.cleanup()
    local all_recipients = recipients.get_all_recipients()
    for _, recipient in pairs(all_recipients) do
        recipients.delete_recipient(recipient.recipient_id)
    end

    recipients.initialize()
end

-- ##############################################

function recipients.isAlertsRecipient(recipient)
    return recipient.notifications_type == "alerts"
end

-- ##############################################

function recipients.isBuiltinRecipient(recipient)
    return recipient.recipient_name == "builtin_recipient_alert_store_db"
end

-- ##############################################

return recipients
