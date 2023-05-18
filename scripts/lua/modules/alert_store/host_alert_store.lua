--
-- (C) 2021-22 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"

require "lua_utils"
local alert_store = require "alert_store"
local format_utils = require "format_utils"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local alert_roles = require "alert_roles"
local json = require "dkjson"
local tag_utils = require "tag_utils"

-- ##############################################

local host_alert_store = classes.class(alert_store)

-- ##############################################

function host_alert_store:init(args)
    self.super:init()

    self._table_name = "host_alerts"
    self._alert_entity = alert_entities.host
end

-- ##############################################

function host_alert_store:insert(alert)
    local is_attacker = ternary(alert.is_attacker, 1, 0)
    local is_victim = ternary(alert.is_victim, 1, 0)
    local is_client = ternary(alert.is_client, 1, 0)
    local is_server = ternary(alert.is_server, 1, 0)
    local ip_version = alert.ip_version
    local ip = alert.ip
    local vlan_id = alert.vlan_id

    if not ip then -- Compatibility with Lua alerts
        local host_info = hostkey2hostinfo(alert.entity_val)
        ip = host_info.host
        vlan_id = host_info.vlan
    end

    if not ip_version then
        if isIPv4(ip) then
            ip_version = 4
        else
            ip_version = 6
        end
    end

    local extra_columns = ""
    local extra_values = ""
    if (ntop.isClickHouseEnabled()) then
        extra_columns = "rowid, "
        extra_values = "generateUUIDv4(), "
    end

    local insert_stmt = string.format("INSERT INTO %s " ..
                                          "(%salert_id, interface_id, ip_version, ip, vlan_id, name, country, is_attacker, is_victim, is_client, is_server, tstamp, tstamp_end, severity, score, granularity, host_pool_id, network, json) " ..
                                          "VALUES (%s%u, %d, %u, '%s', %u, '%s', '%s', %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, '%s'); ",
        self._table_name, extra_columns, extra_values, alert.alert_id, self:_convert_ifid(interface.getId()),
        ip_version, ip, vlan_id or 0, self:_escape(alert.name), alert.country_name, is_attacker, is_victim, is_client,
        is_server, alert.tstamp, alert.tstamp_end, map_score_to_severity(alert.score), alert.score, alert.granularity,
        alert.host_pool_id or 0, alert.network or 0, self:_escape(alert.json or ""))

    -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

    return interface.alert_store_query(insert_stmt)
end

-- ##############################################

-- @brief Performs a query for the top hosts by alert count
function host_alert_store:top_ip_historical()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()

    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
            "SELECT ip, name, vlan_id, count(*) count FROM %s WHERE %s GROUP BY ip, vlan_id, name ORDER BY count DESC LIMIT %u",
            self._table_name, where_clause, self._top_limit)
    else
        q = string.format(
            "SELECT ip, name, vlan_id, count(*) count FROM %s WHERE %s GROUP BY ip ORDER BY count DESC LIMIT %u",
            self._table_name, where_clause, self._top_limit)
    end

    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Stats used by the dashboard
function host_alert_store:_get_additional_stats()
    local stats = {}
    stats.top = {}
    stats.top.ip = self:top_ip_historical()
    return stats
end

-- ##############################################

-- @brief Add ip filter
function host_alert_store:add_ip_filter(ip)
    self:add_filter_condition('ip', 'eq', ip);
end

-- ##############################################

-- @brief Add vlan filter
function host_alert_store:add_vlan_filter(vlan_id)
    self:add_filter_condition('vlan_id', 'eq', vlan_id);
end

-- ##############################################

-- @brief Add filters according to what is specified inside the REST API
function host_alert_store:_add_additional_request_filters()
    local vlan_id = _GET["vlan_id"]
    local ip_version = _GET["ip_version"]
    local ip = _GET["ip"]
    local name = _GET["name"]
    local role = _GET["role"]
    local role_cli_srv = _GET["role_cli_srv"]
    local host_pool_id = _GET["host_pool_id"]
    local network = _GET["network"]

    self:add_filter_condition_list('vlan_id', vlan_id, 'number')
    self:add_filter_condition_list('ip_version', ip_version)
    self:add_filter_condition_list('ip', ip)
    self:add_filter_condition_list('name', name)
    self:add_filter_condition_list('host_role', role)
    self:add_filter_condition_list('role_cli_srv', role_cli_srv)
    self:add_filter_condition_list('host_pool_id', host_pool_id)
    self:add_filter_condition_list('network', network)
end

-- ##############################################

-- @brief Get info about additional available filters
function host_alert_store:_get_additional_available_filters()
    local filters = {
        vlan_id = tag_utils.defined_tags.vlan_id,
        ip_version = tag_utils.defined_tags.ip_version,
        ip = tag_utils.defined_tags.ip,
        name = tag_utils.defined_tags.name,
        role = tag_utils.defined_tags.role,
        role_cli_srv = tag_utils.defined_tags.role_cli_srv,
        host_pool_id = tag_utils.defined_tags.host_pool_id,
        network = tag_utils.defined_tags.network
    }

    return filters
end

-- ##############################################

local RNAME = {
    IP = {
        name = "ip",
        export = true
    },
    IS_VICTIM = {
        name = "is_victim",
        export = true
    },
    IS_ATTACKER = {
        name = "is_attacker",
        export = true
    },
    IS_CLIENT = {
        name = "is_client",
        export = true
    },
    IS_SERVER = {
        name = "is_server",
        export = true
    },
    VLAN_ID = {
        name = "vlan_id",
        export = true
    },
    ALERT_NAME = {
        name = "alert_name",
        export = true
    },
    DESCRIPTION = {
        name = "description",
        export = true
    },
    MSG = {
        name = "msg",
        export = true,
        elements = {"name", "value", "description"}
    },
    LINK_TO_PAST_FLOWS = {
        name = "link_to_past_flows",
        export = false
    },
    HOST_POOL_ID = {
        name = "host_pool_id",
        export = false
    },
    NETWORK = {
        name = "network",
        export = false
    }
}

function host_alert_store:get_rnames()
    return RNAME
end

-- @brief Convert an alert coming from the DB (value) to an host_info table
function host_alert_store:_alert2hostinfo(value)
    return {
        ip = value["ip"],
        name = value["name"]
    }
end

-- @brief Convert an alert coming from the DB (value) to a record returned by the REST API
function host_alert_store:format_record(value, no_html)
    local href_icon = "<i class='fas fa-laptop'></i>"
    local record = self:format_json_record_common(value, alert_entities.host.entity_id)

    local alert_info = alert_utils.getAlertInfo(value)
    local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), true --[[ no_html --]] ,
        alert_entities.host.entity_id)
    local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)

    -- local host = hostinfo2hostkey(value)
    -- Handle VLAN as a separate field
    local host = value["ip"]

    local reference_html = nil

    reference_html = hostinfo2detailshref({
        ip = value["ip"],
        vlan = value["vlan_id"]
    }, nil, href_icon, "", true)
    if reference_html == href_icon then
        reference_html = nil
    end

    record[RNAME.IP.name] = {
        value = host,
        label = host,
        shown_label = host,
        reference = reference_html,
        country = interface.getHostCountry(host)
    }

    -- Long, unshortened label
    local host_label_long = hostinfo2label(self:_alert2hostinfo(value), false --[[ Show VLAN --]] , false)

    if no_html then
        record[RNAME.IP.name]["label"] = host_label_long
    else
        local host_label_short = shortenString(host_label_long)
        record[RNAME.IP.name]["label"] = host_label_short
        record[RNAME.IP.name]["label_long"] = host_label_long
    end

    record[RNAME.IS_VICTIM.name] = ""
    record[RNAME.IS_ATTACKER.name] = ""
    record[RNAME.IS_CLIENT.name] = ""
    record[RNAME.IS_SERVER.name] = ""

    if value["is_victim"] == true or value["is_victim"] == "1" then
        if no_html then
            record[RNAME.IS_VICTIM.name] = tostring(true) -- when no_html is enabled a default value must be present
        else
            record[RNAME.IS_VICTIM.name] = '<i class="fas fa-sad-tear"></i>'
            record["role"] = {
                label = i18n("victim"),
                value = "victim"
            }
        end
    elseif no_html then
        record[RNAME.IS_VICTIM.name] = tostring(false) -- when no_html is enabled a default value must be present
    end

    if value["is_attacker"] == true or value["is_attacker"] == "1" then
        if no_html then
            record[RNAME.IS_ATTACKER.name] = tostring(true) -- when no_html is enabled a default value must be present
        else
            record[RNAME.IS_ATTACKER.name] = '<i class="fas fa-skull"></i>'
            record["role"] = {
                label = i18n("attacker"),
                value = "attacker"
            }
        end
    elseif no_html then
        record[RNAME.IS_ATTACKER.name] = tostring(false) -- when no_html is enabled a default value must be present
    end

    if value["is_client"] == true or value["is_client"] == "1" then
        if no_html then
            record[RNAME.IS_CLIENT.name] = tostring(true) -- when no_html is enabled a default value must be present
        else
            record[RNAME.IS_CLIENT.name] = '<i class="fas fa-long-arrow-alt-right"></i>'
            record["role_cli_srv"] = {
                label = i18n("client"),
                value = "client"
            }
        end
    elseif no_html then
        record[RNAME.IS_CLIENT.name] = tostring(false) -- when no_html is enabled a default value must be present
    end

    if value["is_server"] == true or value["is_server"] == "1" then
        if no_html then
            record[RNAME.IS_SERVER.name] = tostring(true) -- when no_html is enabled a default value must be present
        else
            record[RNAME.IS_SERVER.name] = '<i class="fas fa-long-arrow-alt-left"></i>'
            record["role_cli_srv"] = {
                label = i18n("server"),
                value = "server"
            }
        end
    elseif no_html then
        record[RNAME.IS_SERVER.name] = tostring(false) -- when no_html is enabled a default value must be present
    end

    if value["vlan_id"] and tonumber(value["vlan_id"]) ~= 0 then
        record[RNAME.VLAN_ID.name] = value["vlan_id"]
    else
        record[RNAME.VLAN_ID.name] = ""
    end

    local network_value = value['network']
    if network_value == "65535" then
        network_value = ""
    end
    local network = RNAME.NETWORK.name
    record[network] = {
        value = network_value,
        label = getLocalNetworkAliasById(value['network'])
    }

    local host_pool_id = RNAME.HOST_POOL_ID.name
    record[host_pool_id] = {
        value = value['host_pool_id'],
        label = getPoolName(tonumber(value['host_pool_id']))
    }

    record[RNAME.ALERT_NAME.name] = alert_name

    record[RNAME.DESCRIPTION.name] = msg

    if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
        msg = ""
    end

    if no_html then
        msg = noHtml(msg)
    end

    record[RNAME.MSG.name] = {
        name = noHtml(alert_name),
        fullname = alert_name,
        value = tonumber(value["alert_id"]),
        description = msg,
        configset_ref = alert_utils.getConfigsetAlertLink(alert_info, value)
    }

    record[RNAME.LINK_TO_PAST_FLOWS.name] = alert_utils.getLinkToPastFlows(ifid, value, alert_info)

    return record
end

-- ##############################################

return host_alert_store
