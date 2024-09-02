--
-- (C) 2014-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local clock_start = os.clock()

-- This file contains the description of all functions
-- used to trigger host alerts
local verbose = ntop.getCache("ntopng.prefs.alerts.debug") == "1"

local json = require("dkjson")
local recovery_utils = require "recovery_utils"
local alert_entities = require "alert_entities"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local alerts_api = require "alerts_api"
local icmp_utils = require "icmp_utils"
local flow_risk_utils = require "flow_risk_utils"
require "check_redis_prefs"

local shaper_utils = nil

if (ntop.isnEdge()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    shaper_utils = require("shaper_utils")
end

-- ##############################################

local alert_utils = {}

-- ##############################################

-- @brief Return a callback for formatting the alert
-- @param alert_key The alert type
-- @param entity_id The alert entity
-- @return a format callback as defined in alert_definitions whose parameters are:
-- - ifid
-- - alert
-- - alert_json
-- - local_explorer: true if called by the local alert explorer, false if exported to an endpoint
local function alertTypeDescription(alert_key, entity_id)
    local alert_id = alert_consts.getAlertType(alert_key, entity_id)

    if alert_id and alert_consts.alert_types[alert_id].format then
        return alert_consts.alert_types[alert_id].format
    end

    return nil
end

-- ##############################################

local function get_make_room_keys(ifId)
    return {
        flows = "ntopng.cache.alerts.ifid_" .. ifId .. ".make_room_flow_alerts",
        entities = "ntopng.cache.alerts.ifid_" .. ifId .. ".make_room_closed_alerts"
    }
end

-- #################################

-- @brief Deletes all stored alerts matching an host and an IP
-- @return nil
function alert_utils.deleteFlowAlertsMatchingHost(host_ip, vlan_id, alert_id)
    local flow_alert_store = require("flow_alert_store").new()

    if not isEmptyString(host_ip) then
        flow_alert_store:add_ip_filter(hostkey2hostinfo(host_ip)["host"])
    end

    if (vlan_id) and (tonumber(vlan_id) ~= 0) then
        flow_alert_store:add_vlan_filter(vlan_id)
    end

    flow_alert_store:add_alert_id_filter(alert_id)

    -- Perform the actual deletion
    flow_alert_store:delete()
end

-- #################################

-- @brief Deletes all stored alerts matching a domain
-- @return nil
function alert_utils.deleteFlowAlertsMatchingDomain(domain_name, alert_id)
    local flow_alert_store = require("flow_alert_store").new()

    if not isEmptyString(domain_name) then
        flow_alert_store:add_domain_filter(domain_name)
    end

    if alert_id then
        flow_alert_store:add_alert_id_filter(alert_id)
    end

    -- Perform the actual deletion
    flow_alert_store:delete()
end

-- #################################

-- @brief Deletes all stored alerts matching a certificate
-- @return nil
function alert_utils.deleteFlowAlertsMatchingCertificate(certificate, alert_id)

    -- TODO

end

-- #################################

-- @brief Deletes all stored alerts matching an host and an IP
-- @return nil
function alert_utils.deleteHostAlertsMatchingHost(host_ip, vlan_id, alert_id)
    local host_alert_store = require("host_alert_store").new()

    if not isEmptyString(host_ip) then
        host_alert_store:add_ip_filter(hostkey2hostinfo(host_ip)["host"])
    end

    if (vlan_id) and (tonumber(vlan_id) ~= 0) then
        host_alert_store:add_vlan_filter(vlan_id)
    end

    host_alert_store:add_alert_id_filter(alert_id)

    -- Perform the actual deletion
    host_alert_store:delete()
end

-- #################################

-- this function returns an object with parameters specific for one tab
function alert_utils.getTabParameters(_get, what)
    local opts = {}
    for k, v in pairs(_get) do
        opts[k] = v
    end

    -- these options are contextual to the current tab (status)
    if _get.status ~= what then
        opts.alert_id = nil
    end
    if not isEmptyString(what) then
        opts.status = what
    end
    opts.ifid = interface.getId()
    return opts
end

-- #################################

-- Return more information for the flow alert description
local function getAlertTypeInfo(record, alert_info)
    local res = ""

    local l7proto_name = interface.getnDPIProtoName(tonumber(record["l7_proto"]) or 0)

    if l7proto_name == "ICMP" then -- is ICMPv4
        -- TODO: old format - remove when the all the flow alers will be generated in lua
        local type_code = {
            type = alert_info["icmp.icmp_type"],
            code = alert_info["icmp.icmp_code"]
        }

        if table.empty(type_code) and alert_info["icmp"] then
            -- This is the new format created when setting the alert from lua
            type_code = {
                type = alert_info["icmp"]["type"],
                code = alert_info["icmp"]["code"]
            }
        end

        if alert_info["icmp.unreach.src_ip"] then -- TODO: old format to be removed
            res = string.format("[%s]", i18n("icmp_page.icmp_port_unreachable_extra", {
                unreach_host = alert_info["icmp.unreach.dst_ip"],
                unreach_port = alert_info["icmp.unreach.dst_port"],
                unreach_protocol = l4_proto_to_string(alert_info["icmp.unreach.protocol"])
            }))
        elseif alert_info["icmp"] and alert_info["icmp"]["unreach"] then -- New format
            res = string.format("[%s]", i18n("icmp_page.icmp_port_unreachable_extra", {
                unreach_host = alert_info["icmp"]["unreach"]["dst_ip"],
                unreach_port = alert_info["icmp"]["unreach"]["dst_port"],
                unreach_protocol = l4_proto_to_string(alert_info["icmp"]["unreach"]["protocol"])
            }))
        else
            res = string.format("[%s]",
                icmp_utils.get_icmp_label(4 --[[ ipv4 --]] , type_code["type"], type_code["code"]))
        end
    end

    return string.format(" %s", res)
end

-- #################################

-- This function formats flows in alerts
function alert_utils.formatRawFlow(alert, nohtml)
    require "flow_utils"
    local time_bounds
    local add_links = false

    -- pretend alert is a flow to reuse getFlowLabel
    local flow = {
        ["cli.ip"] = alert["cli_ip"],
        ["cli.port"] = tonumber(alert["cli_port"]),
        ["cli.blacklisted"] = tostring(alert["cli_blacklisted"]) == "1",
        ["cli.localhost"] = tostring(alert["cli_localhost"]) == "1",
        ["cli.host"] = alert["cli_name"],
        ["srv.ip"] = alert["srv_ip"],
        ["srv.port"] = tonumber(alert["srv_port"]),
        ["srv.blacklisted"] = tostring(alert["srv_blacklisted"]) == "1",
        ["srv.localhost"] = tostring(alert["srv_localhost"]) == "1",
        ["srv.host"] = alert["srv_name"],
        ["vlan"] = alert["vlan_id"]
    }

    flow = "<i class=\"fas fa-stream\"></i> " .. (getFlowLabel(flow, false, add_links, time_bounds, {
        page = "alerts"
    }, nil, true, nohtml) or "")

    return flow
end

-- #################################

function alert_utils.disableAlertsGeneration()
    if not isAdministratorOrPrintErr() then
        return
    end

    -- Ensure we do not conflict with others
    ntop.setPref("ntopng.prefs.disable_alerts_generation", "1")
    if (verbose) then
        io.write("[Alerts] Disable done\n")
    end
end

-- #################################

local function alertNotificationActionToLabel(action, use_emoji)
    local label = ""

    if action == "engage" then
        label = "["
        if (use_emoji) then
            label = label .. "\xE2\x9D\x97 "
        end
        label = label .. "Engaged"
        label = label .. "]"
    elseif action == "release" then
        label = "["
        if (use_emoji) then
            label = label .. "\xE2\x9C\x94 "
        end
        label = label .. "Released"
        label = label .. "]"
    end

    return label
end

-- #################################

function alert_utils.getConfigsetURL(script_key, subdir)
    return string.format('%s/lua/admin/edit_configset.lua?subdir=%s&check=%s#all', ntop.getHttpPrefix(), subdir,
        script_key)
end

-- #################################

function alert_utils.getConfigsetAlertLink(alert_json, alert --[[ optional --]] , alert_entity)
    if isAdministrator() then
        local info = alert_json.alert_generation or (alert_json.alert_info and alert_json.alert_info.alert_generation)
        if alert_entity and alert_entity == alert_entities.am_host.entity_id then
            local host = alert_json.host.host or alert_json.host
            if host then
                local measurement = alert_json.host.measurement or alert_json.measurement
                if measurement then
                    return
                        ' <a href="' .. ntop.getHttpPrefix() .. '/lua/monitor/active_monitoring_monitor.lua?am_host=' ..
                            host .. '&measurement=' .. measurement .. '&page=overview"><i class="fas fa-cog" title="' ..
                            i18n("edit_configuration") .. '"></i></a>'
                else
                    return
                        ' <a href="' .. ntop.getHttpPrefix() .. '/lua/monitor/active_monitoring_monitor.lua?am_host=' ..
                            host .. '&page=overview"><i class="fas fa-cog" title="' .. i18n("edit_configuration") ..
                            '"></i></a>'
                end
            else
                return ' <a href="' .. ntop.getHttpPrefix() ..
                           '/lua/monitor/active_monitoring_monitor.lua?page=overview"><i class="fas fa-cog" title="' ..
                           i18n("edit_configuration") .. '"></i></a>'
            end
        elseif info then
            return (' <a href="' .. alert_utils.getConfigsetURL(info.script_key, info.subdir) .. '">' ..
                       '<i class="fas fa-cog" title="' .. i18n("edit_configuration") .. '"></i></a>')
        else
            return (' <a href="' .. ntop.getHttpPrefix() .. '/lua/admin/edit_configset.lua?subdir=interface#all">' ..
                       '<i class="fas fa-cog" title="' .. i18n("edit_configuration") .. '"></i></a>')
        end
    end

    return ('')
end

-- #################################

function alert_utils.getAlertInfo(alert)
    local alert_json = alert["json"] or alert["alert_json"]

    if isEmptyString(alert_json) then
        alert_json = {}
    elseif (string.sub(alert_json, 1, 1) == "{") then
        alert_json = json.decode(alert_json) or {}
    end

    return alert_json
end

-- #################################

function alert_utils.formatAlertMessage(ifid, alert, alert_json, local_explorer)
    local msg

    if (alert_json == nil) then
        alert_json = alert_utils.getAlertInfo(alert)
    end

    local description = alertTypeDescription(alert.alert_id, alert.entity_id)

    msg = alert_json
    if (type(description) == "string") then
        -- localization string
        msg = i18n(description, msg)
    elseif (type(description) == "function") then
        msg = description(ifid, alert, alert_json, local_explorer)
    end

    if (type(msg) == "table") then
        return ("")
    end

    if isEmptyString(msg) then
        msg = alert_consts.alertTypeLabel(tonumber(alert.alert_id), true --[[ no_html --]] , alert.entity_id)
    end

    if not isEmptyString(alert["user_label"]) then
        msg = string.format('%s <small><span class="text-muted">%s</span></small>', msg, alert["user_label"])
    end

    return (msg or "")
end

-- #################################

-- Return a risk info (raw text, do not return a formatted value)
function alert_utils.get_flow_risk_info(alert_risk, alert_json)
    if (alert_json) and (alert_json.alert_generation) and (alert_json.alert_generation.flow_risk_info) then
        local flow_risk_info = json.decode(alert_json.alert_generation.flow_risk_info)
        if (flow_risk_info) and (flow_risk_info[tostring(alert_risk)]) then
            return flow_risk_info[tostring(alert_risk)]
        end
    end

    return ''
end

-- #################################

function alert_utils.format_score(msg, alert_score)
    if (alert_score) and (tonumber(alert_score)) and (tonumber(alert_score) > 0) then
        msg = string.format("%s [Score: %d] ", msg, tonumber(alert_score))
    end

    return msg
end

-- #################################

function alert_utils.formatFlowAlertMessage(ifid, alert, alert_json, add_score, local_explorer)
    local msg
    local alert_risk

    if tonumber(alert.alert_id) then
        alert_risk = ntop.getFlowAlertRisk(tonumber(alert.alert_id))

        if (tonumber(alert_risk) == 0) then
            alert_src = "ntopng"
            alert_risk = tonumber(alert.alert_id)
        else
            alert_src = "nDPI"
        end
    end

    if not alert_json then
        alert_json = alert_utils.getAlertInfo(alert)
    end

    local description = alertTypeDescription(alert.alert_id, alert_entities.flow.entity_id)

    if (type(description) == "string") then
        -- localization string
        msg = i18n(description, alert_json)
    elseif (type(description) == "function") then
        msg = description(ifid, alert, alert_json, local_explorer)
    end

    if isEmptyString(msg) then
        if alert_json and alert_json.alert_generation and alert_risk and alert_risk > 0 then
            -- Flow risks most of the times already have a default description, use this in case of emtpy descr
            msg = alert_utils.get_flow_risk_info(alert_risk, alert_json)
        else
            -- Normal alerts
            msg = alert_consts.alertTypeLabel(tonumber(alert.alert_id), true --[[ no_html --]] , alert.entity_id)
        end
    end

    if not isEmptyString(alert["user_label"]) then
        msg = string.format('%s <small><span class="text-muted">%s</span></small>', msg, alert["user_label"])
    end

    if add_score then
        if tonumber(alert.alert_id) then
            local alert_score = ntop.getFlowAlertScore(tonumber(alert.alert_id))
            msg = alert_utils.format_score(msg, alert_score)
        end
    end

    -- Add the link to the documentation
    if alert_risk and alert_risk > 0 then
        msg = string.format("%s %s %s", msg, flow_risk_utils.get_documentation_link(alert_risk, alert_src),
            flow_risk_utils.get_remediation_documentation_link(alert_risk, alert_src))
        local info_msg = alert_utils.get_flow_risk_info(alert_risk, alert_json)

        -- Add check info_msg ~= alert.info to avoid duplicated in description msg
        --[[if (not isEmptyString(info_msg) and info_msg ~= alert.info) then
         msg = string.format("%s", msg, info_msg)
	 end--]]
    end

    return msg or ""
end

-- #################################

function alert_utils.getLinkToPastFlows(ifid, alert, alert_json)
    if not ntop.isEnterpriseM() or not hasClickHouseSupport() then
        -- nIndex not enabled or enabled but not available for this particular interface
        return
    end

    local epoch_begin = alert["tstamp"]
    local epoch_end = alert["tstamp_end"]

    -- Fetch the alert id
    local alert_id = alert_consts.getAlertType(alert.alert_id, alert.entity_id)
    if alert_id and epoch_begin and epoch_end then
        local final_filter = {}
        local filters = {}

        -- Look a bit around the epochs
        epoch_begin = epoch_begin - (5 * 60)
        epoch_end = epoch_end + (5 * 60)

        -- IP
        if not isEmptyString(alert["ip"]) then
            filters[#filters + 1] = {
                name = "ip",
                op = "eq",
                val = alert["ip"]
            }

            -- Add the hostname here cause it's needed to check if the ip is equal to the name
            -- Hostname
            if not isEmptyString(alert["name"]) and (alert["ip"] ~= alert["name"]) then
                filters[#filters + 1] = {
                    name = "name",
                    op = "eq",
                    val = alert["name"]
                }
            end
        end

        -- VLAN ID
        if not isEmptyString(alert["vlan_id"]) and tonumber(alert["vlan_id"]) > 0 then
            filters[#filters + 1] = {
                name = "vlan_id",
                op = "eq",
                val = alert["vlan_id"]
            }
        end

        -- Host alerts could have a custom function to format the url, in case call it
        -- and then merge the filters
        if alert_consts.alert_types[alert_id].filter_to_past_flows then
            local past_flows_filter = alert_consts.alert_types[alert_id].filter_to_past_flows(ifid, alert, alert_json)
            table.merge(filters, past_flows_filter)
        end

        for _, tag in pairs(filters) do
            final_filter[tag.name] = string.format("%s%s%s", tag.val, alert_consts.SEPARATOR, tag.op)
        end

        -- Return the link augmented with the filter
        local res = string.format("%s/lua/pro/db_search.lua?epoch_begin=%u&epoch_end=%u&%s", ntop.getHttpPrefix(),
            epoch_begin, epoch_end, table.tconcat(final_filter, "=", "&"))

        return res
    end

    return nil
end

-- #################################

function alert_utils.notification_timestamp_rev(a, b)
    return (a.tstamp > b.tstamp)
end

function alert_utils.severity_rev(a, b)
    return (a.severity_id > b.severity_id)
end

-- #################################
--
-- Returns a summary of the alert as readable text
function alert_utils.formatAlertNotification(notif, options)
    -- Otherwise format the alert
    local defaults = {
        show_severity = true,
        nohtml = false,
        nolabelhtml = false,
        emoji = false
    }
    options = table.merge(defaults, options)

    local ifname
    local severity
    local when

    if (notif.ifid ~= -1) then
        ifname = string.format(" [Interface: %s]", getInterfaceName(notif.ifid))
    else
        ifname = ""
    end

    if (options.show_severity == false) then
        severity = ""
    else
        severity = " [Severity: " ..
                       alert_consts.alertSeverityLabel(notif.score, options.nohtml or options.nolabelhtml, options.emoji) ..
                       "]"
    end

    if (options.nodate == true) then
        when = ""
    else
        if options.timezone then
            when = format_utils.formatEpochISO8601(notif.tstamp_end or notif.tstamp or 0)
        else
            when = format_utils.formatEpoch(notif.tstamp_end or notif.tstamp or 0)
        end

        if (not options.no_bracket_around_date) then
            when = " [" .. when .. "]"
        end

        when = when .. " "
    end

    local msg = string.format("%s%s%s", when, ifname, severity)

    local entity_label = ""
    if notif.entity_id then
        entity_label = alert_consts.alertEntityLabel(notif.entity_id) or ""
    end

    -- entity can be hidden for example when one is OK with just the message
    if options.show_entity and not isEmptyString(entity_label) then
        msg = msg .. " [" .. entity_label .. "]"
    end

    local alert_type_label = alert_consts.alertTypeLabel(notif.alert_id, options.nohtml or options.nolabelhtml,
        notif.entity_id, true)
    if alert_type_label then
        msg = msg .. " [" .. alert_type_label .. "]"
    end

    -- entity can be hidden for example when one is OK with just the message
    if options.show_entity and notif.entity_id and notif.entity_val then
        local ev = notif.entity_val

        if notif.entity_id == alert_entities.flow.entity_id then
            ev = noHtml(alert_utils.formatRawFlow(notif, options.nohtml))

        elseif notif.entity_id == alert_entities.host.entity_id then
            -- suppress @0 when the vlan is zero
            ev = hostinfo2hostkey(hostkey2hostinfo(notif.entity_val))

        elseif notif.entity_id == alert_entities.am_host.entity_id then
            -- show host only, hiding measurement id (e.g. vs@)
            local parts = split(notif.entity_val, "@")
            if #parts == 2 then
                ev = parts[2]
            end

        end
        msg = msg .. " [" .. (ev or '') .. "]"
    end

    -- add the label, that is, engaged or released
    msg = msg .. " " .. alertNotificationActionToLabel(notif.action, options.emoji) .. " "

    local alert_message = alert_utils.formatAlertMessage(notif.ifid, notif)

    if (options.add_cr) then
        msg = msg .. "\n"
    end

    if options.nohtml then
        msg = msg .. noHtml(alert_message)
    else
        msg = msg .. alert_message
    end

    local alert_title = ""
    if not isEmptyString(entity_label) then
        alert_title = string.format("[%s]: ", entity_label)
    end
    alert_title = alert_title .. alert_consts.alertTypeLabel(notif.alert_id, options.nohtml, notif.entity_id)

    return msg, alert_title, entity_label
end

-- ##############################################

function alert_utils.formatAlertCulprit(notif)
    local msg

    -- Formatting cli-srv
    if not isEmptyString(notif.cli_ip) and not isEmptyString(notif.srv_ip) then
        local client = notif.cli_ip
        local server = notif.srv_ip
        local client_port = ''
        local server_port = ''

        if not isEmptyString(notif.cli_name) then
            client = notif.cli_name
        end

        if not isEmptyString(notif.srv_name) then
            server = notif.srv_name
        end

        if notif.cli_port ~= 0 then
            client_port = ':' .. notif.cli_port
        end

        if notif.srv_port ~= 0 then
            server_port = ':' .. notif.srv_port
        end

        msg = string.format('%s%s \xE2\x9E\xA1 %s%s', client, client_port, server, server_port)
    elseif not isEmptyString(notif.entity_val) then
        msg = notif.entity_val

        if notif.name and not isEmptyString(notif.name) then
            msg = notif.name
        end
    else
        msg = ''
    end

    return msg
end

-- ##############################################

local function notify_ntopng_status(started)
    local info = ntop.getInfo()
    local score = 10
    local msg
    local msg_details = string.format("%s v.%s (%s) [OS: %s][pid: %s][options: %s]", info.product, info.version,
        info.revision, info.OS, info.pid, info.command_line)
    local anomalous = false
    local event

    if (started) then

        -- reading current version and last version to check if it has been updated
        local last_version_key = "ntopng.updates.last_version"
        local last_version = ntop.getCache(last_version_key)
        local curr_version = info["version"] .. "-" .. info["revision"]
        ntop.setCache(last_version_key, curr_version)

        -- let's check if we are restarting from an anomalous termination
        -- e.g., from a crash
        if not recovery_utils.check_clean_shutdown() then
            -- anomalous termination
            msg = string.format("%s %s", i18n("alert_messages.ntopng_anomalous_termination", {
                url = "https://www.ntop.org/support/need-help-2/need-help/"
            }), msg_details)
            score = 100
            anomalous = true
            event = "anomalous_termination"
        elseif not isEmptyString(last_version) and last_version ~= curr_version then
            -- software update
            msg = string.format("%s %s", i18n("alert_messages.ntopng_update"), msg_details)
            event = "update"
        else
            -- normal termination
            msg = string.format("%s %s", i18n("alert_messages.ntopng_start"), msg_details)
            event = "start"
        end
    else
        msg = string.format("%s %s", i18n("alert_messages.ntopng_stop"), msg_details)
        event = "stop"
    end

    local entity_value = ntop.getInfo().product
    local entity_info = alerts_api.systemEntity(entity_value)
    local type_info = alert_consts.alert_types.alert_process_notification.new(event, msg_details)

    type_info:set_score(score)

    return (type_info:store(entity_info))
end

function alert_utils.notify_ntopng_start()
    return (notify_ntopng_status(true))
end

function alert_utils.notify_ntopng_stop()
    return (notify_ntopng_status(false))
end

-- ##############################################

local function addDayEpoch(res, day_epoch)
    res[day_epoch] =
        {0, --[[ Counter for alerts between 00:00 and 00:59 UTC --]] 0, --[[ Counter for alerts between 01:00 and 01:59 UTC --]]
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 --[[ Counter for alerts in other hours, until 23:00 to 23:59 --]] }

    return res
end

-- ##############################################

-- @brief Function used to format the old timeseries format (CheckMK integration)
function alert_utils.formatOldTimeseries(q_res, _epoch_begin, _epoch_end)
    local hour_secs = 60 * 60
    local day_secs = 60 * 60 * 24
    local epoch_begin = _epoch_begin - (_epoch_begin % day_secs) -- Round begin to start of day
    local epoch_end = _epoch_end - (_epoch_end % day_secs) + day_secs -- Round end to end of day
    local res = {}

    for _, v in ipairs(q_res) do
        local tstamp = v.hour or v.tstamp
        -- Midnight UTC of the day containing v.hour
        local day_epoch = tstamp - (tstamp % day_secs)

        -- Hour of the day containing v.hour, from 0 to 23, inclusive
        -- NOTE: Use the `floor` to make sure hour is an integer as it will be used to index a Lua array
        local hour = math.floor((tstamp - day_epoch) / hour_secs)

        -- Here we add 1 to the hour as Lua array are indexed starting from 1, whereas `hour` is an integer starting from zero
        if not res[day_epoch] then
            res = addDayEpoch(res, day_epoch)
        end

        -- This is done for both, enganged and historical alert, historical have v.hour and v.count, instead engaged
        -- There is one entry per engaged, reporting the starting time (tstamp), so just add +1 to the hour having that alert 
        res[day_epoch][hour + 1] = tonumber( --[[ Historical ]]
            v.count or --[[ Engaged ]] ((res[day_epoch][hour + 1] or 0) + 1))
    end -- for

    return res
end

-- ##############################################

function alert_utils.format_other_alerts(alert_bitmap, predominant_alert, alert_json, add_score, no_html, json_format)
    -- Unpack all flow alerts, iterating the alerts_map. The alerts_map is stored as an HEX.
    local other_alerts_by_score = {} -- Table used to keep messages ordered by score
    local additional_alerts = {}
    local nibble_num = 0 -- Current nibble being processed
    for alerts_map_nibble_id = #alert_bitmap, 1, -1 do
        -- Extract the nibble
        local alerts_map_hex_nibble = alert_bitmap:sub(alerts_map_nibble_id, alerts_map_nibble_id)
        -- Convert the HEX nibble into a decimal value
        local alerts_map_nibble = tonumber(alerts_map_hex_nibble, 16)

        if alerts_map_nibble > 0 then
            for bit_num = 0, 7 do
                -- Checks the bits set in this current nibble
                local has_bit = alerts_map_nibble & (1 << bit_num) == (1 << bit_num)

                if has_bit then -- The bit is set
                    -- The actual alert id is the bit number times the current byte multiplied by 8
                    local alert_id = math.floor(8 * nibble_num / 2) + bit_num

                    if alert_id ~= tonumber(predominant_alert) then -- Do not add the predominant alert to the list of additional alerts
                        local message = alert_consts.alertTypeLabel(alert_id, true, alert_entities.flow.entity_id)
                        message = message .. " " ..
                                      alert_consts.addExtraInfo(alert_id, alert_entities.flow.entity_id, alert_json)
                        local alert_score = ntop.getFlowAlertScore(alert_id)

                        if add_score then
                            message = alert_utils.format_score(message, alert_score)
                        end

                        local alert_risk = ntop.getFlowAlertRisk(tonumber(alert_id))
                        if alert_risk > 0 then -- source is nDPI
                            if not no_html then
                                message = string.format("%s %s", message,
                                    flow_risk_utils.get_documentation_link(alert_risk, "nDPI"))
                            end
                            local info_msg = alert_utils.get_flow_risk_info(alert_risk, alert_json)
                            if not isEmptyString(info_msg) then
                                message = string.format("%s [%s]", message, info_msg)
                            end
                        end

                        if not other_alerts_by_score[alert_score] then
                            other_alerts_by_score[alert_score] = {}
                        end

                        other_alerts_by_score[alert_score][#other_alerts_by_score[alert_score] + 1] = message
                        if json_format then
                            additional_alerts[#additional_alerts + 1] = {
                                msg = message,
                                score = alert_score,
                                alert_id = alert_id
                            }
                        else
                            additional_alerts[#additional_alerts + 1] = message
                        end
                    end
                end
            end
        end

        -- Increment the nibble
        nibble_num = nibble_num + 1
    end

    return other_alerts_by_score, additional_alerts
end

-- ##############################################

function alert_utils.filter_notification(notification, recipient_id)
    local alert_info = json.decode(notification.alert)
    local alert_key = alert_info.alert_id
    local entity_id = alert_info.entity_id
    local entity_val = alert_info.entity_val

    if notification.score == 0 then
        return true
    end

    local alert_id = alert_consts.getAlertType(alert_key, entity_id)

    return alert_utils.check_alert_policy(entity_id, entity_val, alert_id, alert_info, recipient_id)
end

-- ##############################################

function alert_utils.check_alert_policy(entity_id, entity_val, alert_id, alert_info, recipient_id)
    local alert_key = ""
    local alert_key_fields = {}
    local not_set = true
    local silence_alerts = ntop.getCache("ntopng.prefs.silence_multiple_alerts." .. recipient_id) or "1"

    -- In case the alerts have to be silenced for the endpoint then silence them, otherwise skip
    if silence_alerts == "1" then
        if alert_consts.alert_types[alert_id].alert_retention_policy_key then
            alert_key_fields = alert_consts.alert_types[alert_id].alert_retention_policy_key(alert_info)
            for _, field in ipairs(alert_key_fields) do
                alert_key = alert_key .. "." .. alert_info[field]
            end
        else
            if not alert_entities[entity_val] then
                entity_val = alert_consts.alertEntityRaw(entity_id)
            end
            alert_key_fields = alert_entities[entity_val].alert_key_fields
            if (alert_key_fields) then
                for _, field in ipairs(alert_key_fields) do
                    alert_key = alert_key .. "." .. alert_info[field]
                end
            else
                return not_set
            end
        end

        if isEmptyString(alert_key) then
            return not_set
        end

        local redis_key = string.format("ntopng.cache.alert.retention.%s.%s.%s%s", recipient_id, entity_id, alert_id,
            alert_key)
        not_set = isEmptyString(ntop.getCache(redis_key))

        if not_set then
            -- Set key with expiration on redis to filter out the same alert for some time
            -- TODO: 3600 must be update with a user preference
            ntop.setCache(redis_key, "1", 3600)
        end
    end

    return not_set -- true to send the alert, false to suppress this alert until the key expires
end

-- ##############################################

if (trace_script_duration ~= nil) then
    io.write(debug.getinfo(1, 'S').source .. " executed in " .. (os.clock() - clock_start) * 1000 .. " ms\n")
end

return alert_utils
