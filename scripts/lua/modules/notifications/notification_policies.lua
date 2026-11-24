--
-- (C) 2026 - ntop.org
--
-- Notification policies: the notifications matching the condition of a policy (type, minimum
-- severity, categories, host pools, active monitoring hosts, tags) are delivered to its
-- recipients, once per recipient also when more policies match. An empty list is no filter.
-- Alerts raised in C++ are matched by the NotificationPolicy class (registered here), the
-- other notifications by notification_policies.matches (see recipients.dispatch_notification).
--

require "lua_utils_generic"
require "lua_trace"
local json = require "dkjson"
local alert_entities = require "alert_entities"

local notification_policies = {}

-- ##############################################

notification_policies.MAX_NUM_POLICIES = 128 -- Keep in sync with ntop_defines.h MAX_NUM_NOTIFICATION_POLICIES

local LOCK_KEY = "ntopng.cache.notification_policies.lock"
local IDS_KEY = "ntopng.prefs.notification_policies.policy_ids"
local DETAILS_KEY = "ntopng.prefs.notification_policies.policy_id_%d.details"

-- Notification types also delivered by the C++ alerts (see register_policy)
local ALERTS_TYPE = "alerts"
local ISSUES_TYPE = "issues"

-- ##############################################

local function _lock()
    local max_lock_duration = 5 -- seconds
    local max_lock_attempts = 5 -- give up after at most this number of attempts

    for i = 1, max_lock_attempts do
        ntop.setnxCache(LOCK_KEY, "1", max_lock_duration)

        if ntop.getCache(LOCK_KEY) == "1" then
            return true -- lock acquired
        end

        ntop.msleep(1000)
    end

    return false -- lock not acquired
end

-- ##############################################

local function _unlock()
    ntop.delCache(LOCK_KEY)
end

-- ##############################################

local function _get_policy_ids()
    local res = {}

    for _, policy_id in pairs(ntop.getMembersCache(IDS_KEY) or {}) do
        res[#res + 1] = tonumber(policy_id)
    end

    table.sort(res)

    return res
end

-- ##############################################

-- @brief Whether the alerts are delivered to the policy recipients: the alerts policies, and
--        the issues policies while the issues are disabled (their recipients receive the alerts)
local function delivers_alerts(policy)
    local recipients = require "recipients"

    return (policy.notifications_type == ALERTS_TYPE) or
        ((policy.notifications_type == ISSUES_TYPE) and not recipients.can_deliver_issues())
end

-- ##############################################

-- @brief Register the policy in C++ (that routes the alerts raised in C++), or delete it
--        when it does not deliver alerts
local function register_policy(policy)
    if policy.enabled and delivers_alerts(policy) and #policy.recipient_ids > 0 then
        ntop.notification_policy_register(policy.policy_id, policy.minimum_severity,
            table.concat(policy.check_categories, ","), table.concat(policy.host_pools, ","),
            table.concat(policy.tags, ","), table.concat(policy.recipient_ids, ","))
    else
        ntop.notification_policy_delete(policy.policy_id)
    end
end

-- ##############################################

-- @brief Store and register a policy (the lock must be held)
local function save_policy(policy)
    ntop.setCache(string.format(DETAILS_KEY, policy.policy_id), json.encode({
        name = policy.name,
        enabled = policy.enabled,
        notifications_type = policy.notifications_type,
        minimum_severity = policy.minimum_severity,
        check_categories = policy.check_categories,
        host_pools = policy.host_pools,
        am_hosts = policy.am_hosts,
        tags = policy.tags,
        recipient_ids = policy.recipient_ids
    }))

    register_policy(policy)
end

-- ##############################################

-- @brief Validate a policy (and fill the missing lists with no filter)
-- @return nil when valid, otherwise an error table { type = ... }
local function check_policy(policy, policy_id)
    local recipients = require "recipients"

    if isEmptyString(policy.name) then
        return { type = "missing_mandatory_param", missing_param = "policy_name" }
    end

    for _, other in pairs(notification_policies.get_all_policies()) do
        if other.name == policy.name and other.policy_id ~= policy_id then
            return { type = "policy_already_existing", policy_name = policy.name }
        end
    end

    -- The issues type is offered only while the issues are enabled: an existing issues
    -- policy stays valid (it delivers the alerts while they are disabled)
    local stored = policy_id and notification_policies.get_policy(policy_id)
    if not recipients.get_notification_types()[policy.notifications_type or ""] and
        not (stored and stored.notifications_type == policy.notifications_type) then
        return { type = "invalid_notifications_type" }
    end

    if not tonumber(policy.minimum_severity) then
        return { type = "missing_mandatory_param", missing_param = "minimum_severity" }
    end

    policy.enabled = (policy.enabled ~= false)
    policy.check_categories = policy.check_categories or {}
    policy.host_pools = policy.host_pools or {}
    policy.am_hosts = policy.am_hosts or {}
    policy.tags = policy.tags or {}
    policy.recipient_ids = policy.recipient_ids or {}

    for _, recipient_id in ipairs(policy.recipient_ids) do
        local recipient = recipients.get_recipient(recipient_id)

        if not recipient or recipients.isBuiltinRecipient(recipient) then
            return { type = "endpoint_recipient_not_existing", recipient_id = recipient_id }
        end

        -- The CEF syslog format can only export alerts
        if (recipient.endpoint_key == "syslog") and ((recipient.endpoint_conf or {}).syslog_alert_format == "cef") and
            (policy.notifications_type ~= ALERTS_TYPE) and (policy.notifications_type ~= ISSUES_TYPE) then
            return { type = "recipient_alerts_only", recipient_name = recipient.recipient_name }
        end
    end

    return nil
end

-- ##############################################

-- @brief Add a policy
-- @param policy A table with name, enabled, notifications_type, minimum_severity, check_categories,
--        host_pools, am_hosts, tags (lists of already-validated ids) and recipient_ids
-- @return A table with status "OK" and the policy_id, or status "failed" and an error
function notification_policies.add_policy(policy)
    if not _lock() then
        return { status = "failed", error = { type = "internal_error" } }
    end

    local res
    local err = check_policy(policy)

    if err then
        res = { status = "failed", error = err }
    else
        local used = {}
        for _, policy_id in ipairs(_get_policy_ids()) do
            used[policy_id] = true
        end

        -- First (smallest) available policy id
        for policy_id = 0, notification_policies.MAX_NUM_POLICIES - 1 do
            if not used[policy_id] then
                policy.policy_id = policy_id
                break
            end
        end

        if not policy.policy_id then
            res = { status = "failed", error = { type = "too_many_policies" } }
        else
            ntop.setMembersCache(IDS_KEY, string.format("%d", policy.policy_id))
            save_policy(policy)
            res = { status = "OK", policy_id = policy.policy_id }
        end
    end

    _unlock()

    return res
end

-- ##############################################

-- @brief Edit a policy (same params as add_policy)
-- @return A table with status "OK", or status "failed" and an error
function notification_policies.edit_policy(policy_id, policy)
    policy_id = tonumber(policy_id)

    if not _lock() then
        return { status = "failed", error = { type = "internal_error" } }
    end

    local res
    local err = (not notification_policies.get_policy(policy_id)) and { type = "policy_not_existing" } or
        check_policy(policy, policy_id)

    if err then
        res = { status = "failed", error = err }
    else
        policy.policy_id = policy_id
        save_policy(policy)
        res = { status = "OK" }
    end

    _unlock()

    return res
end

-- ##############################################

function notification_policies.delete_policy(policy_id)
    policy_id = tonumber(policy_id)

    if not policy_id or not notification_policies.get_policy(policy_id) or not _lock() then
        return false
    end

    ntop.delCache(string.format(DETAILS_KEY, policy_id))
    ntop.delMembersCache(IDS_KEY, string.format("%d", policy_id))
    ntop.notification_policy_delete(policy_id)

    _unlock()

    return true
end

-- ##############################################

function notification_policies.get_policy(policy_id)
    policy_id = tonumber(policy_id)

    if not policy_id then
        return nil
    end

    local policy = json.decode(ntop.getCache(string.format(DETAILS_KEY, policy_id)) or "")

    if policy then
        policy.policy_id = policy_id
    end

    return policy
end

-- ##############################################

function notification_policies.get_all_policies()
    local res = {}

    for _, policy_id in ipairs(_get_policy_ids()) do
        local policy = notification_policies.get_policy(policy_id)

        if policy then
            res[#res + 1] = policy
        end
    end

    return res
end

-- ##############################################

-- @brief Set the policies delivering to a recipient: it is added to the listed policies and
--        removed from the others (an empty list removes a deleted recipient from every policy)
-- @return nil, or the error of a listed policy that can not deliver to the recipient (nothing is saved)
function notification_policies.set_recipient_policies(recipient_id, policy_ids)
    recipient_id = tonumber(recipient_id)

    if not _lock() then
        return { type = "internal_error" }
    end

    local changed = {}
    local err

    for _, policy in ipairs(notification_policies.get_all_policies()) do
        local listed = table.contains(policy_ids, policy.policy_id)
        local delivers = table.contains(policy.recipient_ids, recipient_id)

        if listed and not delivers then
            policy.recipient_ids[#policy.recipient_ids + 1] = recipient_id
            err = check_policy(policy, policy.policy_id)

            if err then
                break
            end

            changed[#changed + 1] = policy
        elseif delivers and not listed then
            local recipient_ids = {}

            for _, id in ipairs(policy.recipient_ids) do
                if id ~= recipient_id then
                    recipient_ids[#recipient_ids + 1] = id
                end
            end

            policy.recipient_ids = recipient_ids
            changed[#changed + 1] = policy
        end
    end

    if not err then
        for _, policy in ipairs(changed) do
            save_policy(policy)
        end
    end

    _unlock()

    return err
end

-- ##############################################

-- @brief Remove a deleted host pool or tag from the filters of the policies: its id can be
--        reused by a new pool or tag, that must not inherit the filter. A policy losing its last
--        pool or tag is disabled, as an empty filter would send every alert
-- @param filter "host_pools" or "tags"
-- @param id The id of the deleted pool or tag
function notification_policies.remove_filter_id(filter, id)
    id = tonumber(id)

    if not _lock() then
        return
    end

    for _, policy in ipairs(notification_policies.get_all_policies()) do
        if table.contains(policy[filter], id) then
            local ids = {}

            for _, cur_id in ipairs(policy[filter]) do
                if cur_id ~= id then
                    ids[#ids + 1] = cur_id
                end
            end

            policy[filter] = ids

            if #ids == 0 and policy.enabled then
                policy.enabled = false
                traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format(
                    "Notification policy '%s' disabled: the only %s of its filter (id %d) has been deleted",
                    policy.name, (filter == "tags") and "tag" or "host pool", id))
            end

            save_policy(policy)
        end
    end

    _unlock()
end

-- ##############################################

-- @brief Register (again) all the policies in C++, at startup and when the issues
--        preference changes (the issues policies deliver the alerts while it is off)
function notification_policies.register_all()
    for _, policy in ipairs(notification_policies.get_all_policies()) do
        register_policy(policy)
    end
end

-- ##############################################

-- @brief Delete all the policies
function notification_policies.cleanup()
    for _, policy_id in ipairs(_get_policy_ids()) do
        notification_policies.delete_policy(policy_id)
    end
end

-- ##############################################

-- @brief Whether a notification matches a policy
-- @param policy The policy (see get_policy)
-- @param notification The notification (alert, issue, report...)
-- @param notification_type The notification type (nil for the alerts and the issues)
-- @param category_id The alert category of the notification
-- @param severity_id The severity of the notification, nil when not known (not filtered)
-- @param issues_enabled Whether the issues are delivered (recipients.can_deliver_issues())
-- @return true when the notification matches the policy
function notification_policies.matches(policy, notification, notification_type, category_id, severity_id,
    issues_enabled)
    if not policy.enabled then
        return false
    end

    -- Reports, active scans...: no filters
    if notification_type and notification_type ~= ALERTS_TYPE then
        if policy.notifications_type ~= notification_type then
            return false
        end

        return true
    end

    if notification.issue ~= nil then
        if policy.notifications_type ~= ISSUES_TYPE then
            return false
        end
    elseif (policy.notifications_type ~= ALERTS_TYPE) and
        ((policy.notifications_type ~= ISSUES_TYPE) or issues_enabled) then
        return false
    end

    if #policy.check_categories > 0 and not table.contains(policy.check_categories, category_id) then
        return false
    end

    if severity_id and severity_id < policy.minimum_severity then
        return false
    end

    if notification.host_pool_id and #policy.host_pools > 0 and
        not table.contains(policy.host_pools, notification.host_pool_id) then
        return false
    end

    -- Active monitoring measurements (the vulnerability scans are for any host)
    if #policy.am_hosts > 0 and notification.entity_id == alert_entities.am_host.entity_id and
        notification.entity_val and (notification.entity_val:sub(1, 3) ~= "vs@") and
        not table.contains(policy.am_hosts, notification.entity_val) then
        return false
    end

    -- At least one of the tags. Integer bit operations: a bitmap with the tag 63 is a negative integer
    if #policy.tags > 0 then
        local tags_bitmap = math.tointeger(notification.tags_bitmap) or 0

        for _, tag_id in ipairs(policy.tags) do
            if ((tags_bitmap >> tonumber(tag_id)) & 1) == 1 then
                return true
            end
        end

        return false
    end

    return true
end

-- ##############################################

return notification_policies
