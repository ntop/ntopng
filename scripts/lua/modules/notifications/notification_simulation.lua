--
-- (C) 2026 - ntop.org
--
-- Notification simulation: what happens when an alert is raised by a Behavioural Check, a traffic
-- rule, an SNMP device rule, an active monitoring measurement, an AI policy or a
-- Wazuh alert rule, from the values of its (not necessarily saved) dialog: is the alert stored,
-- which recipients are notified and by which notification policies.
-- Each source builds the sample alerts it raises, which go through the same functions as the
-- real notifications (recipients.dispatch_notification). An unknown value (e.g. the host pool of
-- the host raising a check alert, the severity of a C++ host check) is not filtered but reported
-- as a condition of the matching policy.
--

require "lua_utils"
local json = require "dkjson"
local alert_consts = require "alert_consts"
local alert_entities = require "alert_entities"
local alert_severities = require "alert_severities"
local alert_categories = require "alert_categories"
local checks = require "checks"
local recipients = require "recipients"
local notification_policies = require "notification_policies"
local endpoints = require "endpoints"

local notification_simulation = {}

-- ##############################################

notification_simulation.STATUS = {
    match = "match",
    conditional = "conditional",
    no_match = "no_match"
}

-- Entity of the alerts of the checks without a single alert type, per check subdir
local SUBDIR_ENTITIES = {
    flow = alert_entities.flow,
    host = alert_entities.host,
    interface = alert_entities.interface,
    network = alert_entities.network,
    system = alert_entities.system,
    syslog = alert_entities.host,
    snmp_device = alert_entities.snmp_device,
    active_monitoring = alert_entities.am_host,
    as = alert_entities.as
}

-- Entities whose alerts carry the host pool of the host (Recipients::enqueue, pools_alert_utils)
local POOL_ENTITIES = {
    [alert_entities.host.entity_id] = true,
    [alert_entities.flow.entity_id] = true,
    [alert_entities.snmp_device.entity_id] = true
}

-- Alert raised by a traffic rule, per rule type (keep in sync with traffic_rules_utils.build_alert,
-- host_alert and check_exporter_port). Their alerts are switched on/off by the interface check
-- TRAFFIC_RULES_CHECK, which gives them its severity, category and tags (not to the host alerts,
-- raised by the C++ core).
local TRAFFIC_RULES_CHECK = "traffic_rules"
-- Check switching the alerts of the SNMP device rules on/off (see snmp_dev_threshold_check_rules)
local SNMP_RULES_CHECK = "snmp_device_interface_threshold_crossed"
local TRAFFIC_RULE_ALERTS = {
    Host = { alert_type = "host_alert_traffic_volume", entity = alert_entities.host,
             category = alert_categories.network },
    interface = { alert_type = "alert_network_rule_threshold_cross", entity = alert_entities.interface },
    CIDR = { alert_type = "alert_cidr_rule_threshold_crossed", entity = alert_entities.network },
    host_pool = { alert_type = "alert_host_pool_rule_threshold_crossed", entity = alert_entities.interface },
    vlan = { alert_type = "alert_vlan_rule_threshold_crossed", entity = alert_entities.interface },
    profiles = { alert_type = "alert_profile_rule_threshold_crossed", entity = alert_entities.interface },
    asn = { alert_type = "alert_asn_rule_threshold_crossed", entity = alert_entities.as },
    exporter = { alert_type = "alert_network_rule_threshold_cross", entity = alert_entities.interface }
}

-- ##############################################

-- @brief Sample alerts of a check, with the configuration of the dialog when given
--        (hooks: JSON of the hooks configuration, tag_ids: comma separated tag ids)
local function check_samples(subdir, script_key, hooks_json, tag_ids)
    local script_type = checks.getScriptType(subdir)
    local script = script_type and checks.loadModule(getSystemInterfaceId(), script_type, subdir, script_key)

    if not script then
        return nil
    end

    local configset = checks.getConfigset()
    local hooks = (hooks_json and json.decode(hooks_json)) or checks.getScriptConfig(configset, script, subdir)
    local tags = (tag_ids and split(tag_ids, ",")) or checks.getCheckTags(configset, subdir, script_key)
    local enabled, severity_id = false, nil

    for _, hook in pairs(hooks) do
        if hook.enabled then
            enabled = true

            local severity = hook.script_conf and hook.script_conf.severity
            if severity and severity.severity_id then
                severity_id = tonumber(severity.severity_id)
            end
        end
    end

    local tags_bitmap = require("tag_badge_utils").getTagsBitmap(tags)

    local entity = SUBDIR_ENTITIES[subdir]
    local sample = {
        title = i18n(script.gui and script.gui.i18n_title) or script_key,
        entity = entity,
        current_script = script,
        tags_bitmap = tags_bitmap,
        disabled = not enabled
    }

    if script.alert_id then
        local alert_type = alert_consts.alert_types[alert_consts.getAlertType(script.alert_id, entity.entity_id)]

        if alert_type then
            sample.title = i18n(alert_type.meta.i18n_title) or sample.title
            sample.no_issue = (alert_type.meta.issue == false)
        end
    end

    -- Severity: the configured one, the one of the check definition, the default score of the
    -- flow alerts. Otherwise unknown (e.g. C++ host checks computing the score at runtime).
    if severity_id then
        sample.score = ntop.mapSeverityToScore(severity_id)
    elseif script.severity then
        sample.score = ntop.mapSeverityToScore(script.severity.severity_id)
    elseif (subdir == "flow") and script.alert_id then
        sample.score = ntop.getFlowAlertScore(script.alert_id)
    end

    return { sample }
end

-- ##############################################

local SOURCES = {}

function SOURCES.check(params)
    return check_samples(params.check_subdir, params.script_key, params.JSON, params.tag_ids)
end

function SOURCES.traffic_rule(params)
    local rule_alert = TRAFFIC_RULE_ALERTS[params.rule_type]
    local samples = rule_alert and check_samples("interface", TRAFFIC_RULES_CHECK)

    if not samples then
        return nil
    end

    local sample = samples[1]
    sample.title = i18n(alert_consts.alert_types[rule_alert.alert_type].meta.i18n_title)
    sample.entity = rule_alert.entity
    sample.category = rule_alert.category

    if params.rule_type == "Host" then
        sample.tags_bitmap = 0

        if not isEmptyString(params.rule_target) and (params.rule_target ~= "*") then
            local host_pools = require "host_pools"

            sample.host_pool_id = host_pools:create():get_pool_id(params.rule_target)
        end
    end

    return { sample }
end

function SOURCES.snmp_rule(params)
    local samples = check_samples("snmp_device", SNMP_RULES_CHECK)

    if not samples then
        return nil
    end

    local sample = samples[1]
    sample.title = i18n(alert_consts.alert_types.alert_snmp_interface_threshold_crossed.meta.i18n_title)

    if not isEmptyString(params.snmp_device) and (params.snmp_device ~= "all") then
        local pools_alert_utils = require "pools_alert_utils"

        sample.host_pool_id = pools_alert_utils.get_host_pool_id({
            alert_entity = alert_entities.snmp_device,
            entity_val = params.snmp_device
        })
    end

    return { sample }
end

function SOURCES.am(params)
    local am_utils = require "am_utils"
    local entity_val = am_utils.getAmHostKey(params.am_host, params.measurement)
    local title = i18n(alert_consts.alert_types.alert_am_threshold_cross.meta.i18n_title)
    local current_script = { category = alert_categories.active_monitoring }
    -- The tags of the dialog, else the saved ones of the measurement (see am_utils.triggerAlert)
    local saved = am_utils.getHost(params.am_host, params.measurement)
    local tag_ids = (params.tag_ids and split(params.tag_ids, ",")) or (saved and saved.tag_ids)
    local tags_bitmap = require("tag_badge_utils").getTagsBitmap(tag_ids)

    -- See am_utils.triggerAlert
    return {{
        title = i18n("notification_simulation.am_threshold", { title = title }),
        entity = alert_entities.am_host,
        entity_val = entity_val,
        current_script = current_script,
        tags_bitmap = tags_bitmap,
        score = ntop.mapSeverityToScore(alert_severities.warning.severity_id)
    }, {
        title = i18n("notification_simulation.am_unreachable", { title = title }),
        entity = alert_entities.am_host,
        entity_val = entity_val,
        current_script = current_script,
        tags_bitmap = tags_bitmap,
        score = ntop.mapSeverityToScore(alert_severities.critical.severity_id)
    }}
end

function SOURCES.ai_policy(params)
    -- See ai_policy_dispatch.lua
    return {{
        title = i18n(alert_consts.alert_types.host_alert_ai_policy.meta.i18n_title),
        entity = alert_entities.host,
        category = alert_categories.security,
        tags_bitmap = require("tag_badge_utils").getTagsBitmap(params.tag_ids and split(params.tag_ids, ",")),
        score = tonumber(params.custom_score) or 50
    }}
end

-- ##############################################

local function severity_label(severity_id)
    local severity = alert_consts.alertSeverityById(severity_id)

    return i18n(severity.i18n_title) or severity.i18n_title
end

-- ##############################################

local function pool_names(pool_ids)
    local host_pools = require "host_pools"
    local host_pools_instance = host_pools:create()
    local names = {}

    for _, pool_id in ipairs(pool_ids) do
        local pool = host_pools_instance:get_pool(tonumber(pool_id))
        names[#names + 1] = (pool and pool.name) or tostring(pool_id)
    end

    return table.concat(names, ", ")
end

-- ##############################################

-- @brief The conditions (texts) under which a policy matching a sample with unknown values
--        matches the actual alert
local function policy_conditions(policy, severity_id, pool_unknown)
    local conditions = {}

    if (not severity_id) and (policy.minimum_severity > alert_severities.none.severity_id) then
        conditions[#conditions + 1] = i18n("notification_simulation.condition_severity",
            { severity = severity_label(policy.minimum_severity) })
    end

    if pool_unknown and (#policy.host_pools > 0) then
        conditions[#conditions + 1] = i18n("notification_simulation.condition_host_pool",
            { pools = pool_names(policy.host_pools) })
    end

    return conditions
end

-- ##############################################

local function recipient_destination(recipient, endpoint_types)
    local endpoint = endpoint_types[recipient.endpoint_key]

    if endpoint and endpoint.format_recipient_params then
        return endpoint.format_recipient_params(recipient.recipient_params or {})
    end

    return (endpoint and endpoint.name) or recipient.endpoint_key
end

-- ##############################################

-- @brief Simulate the delivery of a sample alert
local function simulate_sample(sample, policies, builtin_recipient, issues_enabled)
    local notification = {
        entity_id = sample.entity and sample.entity.entity_id,
        entity_val = sample.entity_val,
        score = sample.score,
        alert_category = sample.category and sample.category.id,
        tags_bitmap = sample.tags_bitmap,
        host_pool_id = sample.host_pool_id
    }
    local severity_id = sample.score and recipients.get_notification_severity(notification)
    local category_id = recipients.get_notification_category(notification, sample.current_script)
    local pool_unknown = sample.entity and POOL_ENTITIES[sample.entity.entity_id] and not sample.host_pool_id
    local feeds_issues = issues_enabled and (not sample.no_issue)
    local issue_notification = table.merge(notification, { issue = {} })
    local res = {
        title = sample.title,
        disabled = sample.disabled,
        severity = severity_id and severity_label(severity_id),
        feeds_issues = feeds_issues,
        category = i18n(alert_consts.get_category_by_id(category_id).i18n_title),
        recipients = {}
    }

    -- Stored alerts (builtin recipient), see recipients.dispatch_notification
    if not severity_id then
        res.stored = notification_simulation.STATUS.conditional
        res.stored_condition = i18n("notification_simulation.condition_severity",
            { severity = severity_label(builtin_recipient.minimum_severity) })
    elseif severity_id >= builtin_recipient.minimum_severity then
        res.stored = notification_simulation.STATUS.match
    else
        res.stored = notification_simulation.STATUS.no_match
        res.stored_reason = i18n("notification_simulation.stored_no_severity",
            { severity = severity_label(builtin_recipient.minimum_severity) })
    end

    local recipients_policies = {}

    for _, policy in ipairs(policies) do
        local delivers = policy.notifications_type
        local policy_notification = notification
        -- Only the policies of the alerts and of the issues (e.g. not the reports)
        local relevant = (delivers == "alerts") or (delivers == "issues")

        -- While the issues are enabled, the issues policies receive the issues, not the alerts
        if (delivers == "issues") and issues_enabled then
            policy_notification = issue_notification
            relevant = relevant and feeds_issues
        end

        if relevant and notification_policies.matches(policy, policy_notification, nil,
            category_id, severity_id, issues_enabled) then
            local conditions = policy_conditions(policy, severity_id, pool_unknown)

            for _, recipient_id in ipairs(policy.recipient_ids) do
                recipients_policies[recipient_id] = recipients_policies[recipient_id] or {}
                table.insert(recipients_policies[recipient_id], {
                    policy_id = policy.policy_id,
                    name = policy.name,
                    conditions = conditions
                })
            end
        end
    end

    local endpoint_types = endpoints.get_types()

    for recipient_id, recipient_policies in pairs(recipients_policies) do
        local recipient = recipients.get_recipient(recipient_id)

        if recipient then
            -- Notified for sure when at least a policy matches without conditions
            local status = notification_simulation.STATUS.conditional

            for _, policy in ipairs(recipient_policies) do
                if #policy.conditions == 0 then
                    status = notification_simulation.STATUS.match
                end
            end

            table.sort(recipient_policies, function(a, b)
                return a.name < b.name
            end)

            res.recipients[#res.recipients + 1] = {
                recipient_id = recipient_id,
                name = recipient.recipient_name,
                destination = recipient_destination(recipient, endpoint_types),
                status = status,
                policies = recipient_policies
            }
        end
    end

    table.sort(res.recipients, function(a, b)
        return a.name < b.name
    end)

    return res
end

-- ##############################################

-- @brief Simulate the alerts raised by a source
-- @param source One of check, traffic_rule, snmp_rule, am, ai_policy
-- @param params The parameters of the source (the fields of its dialog)
-- @return The list of the simulated alerts, nil for an invalid source or parameters
function notification_simulation.simulate(source, params)
    local samples = SOURCES[source] and SOURCES[source](params)

    if not samples then
        return nil
    end

    local policies = notification_policies.get_all_policies()
    local builtin_recipient = recipients.get_recipient_by_name("builtin_recipient_alert_store_db")
    local issues_enabled = recipients.can_deliver_issues()
    local res = {}

    for _, sample in ipairs(samples) do
        res[#res + 1] = simulate_sample(sample, policies, builtin_recipient, issues_enabled)
    end

    return res
end

-- ##############################################

return notification_simulation
