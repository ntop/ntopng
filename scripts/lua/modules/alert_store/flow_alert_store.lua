--
-- (C) 2021-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/flow_db/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
require "http_lint"

require "lua_utils"
local alert_store = require "alert_store"
local flow_risk_utils = require "flow_risk_utils"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local tag_utils = require "tag_utils"
local network_consts = require "network_consts"
local json = require "dkjson"
local pools = require "pools"
local historical_flow_utils = require "historical_flow_utils"
local flow_alert_keys = require "flow_alert_keys"
local href_icon = "<i class='fas fa-laptop'></i>"
local rest_utils = require "rest_utils"
local historical_flow_details_formatter = require "historical_flow_details_formatter"
local db_search_manager = require "db_search_manager"

-- ##############################################

local flow_alert_store = classes.class(alert_store)

-- ##############################################

function flow_alert_store:format_location()
    local cli_location = _GET["cli_location"]
    local srv_location = _GET["srv_location"]
    local host_location = _GET["host_location"]
    -- 0 is remote, 1 is local
    if cli_location then
        local list = split(cli_location, ',')
        local value = self:strip_filter_operator(list[1])
        self:add_filter_condition_list("cli_location", cli_location, "string", value)
    end
    if srv_location then
        local list = split(srv_location, ',')
        local value = self:strip_filter_operator(list[1])
        self:add_filter_condition_list("srv_location", srv_location, "string", value)
    end
    if host_location then
        self:add_filter_condition_list("location", srv_location)
    end
end

-- ##############################################

function flow_alert_store:format_traffic_direction(traffic_direction)
    if traffic_direction then
        local list = split(traffic_direction, ',')
        local value = self:strip_filter_operator(list[1])

        if value == "0" then
            self:add_filter_condition_list("cli_location", traffic_direction, "string", "0")
            self:add_filter_condition_list("srv_location", traffic_direction, "string", "0")
        elseif value == "1" then
            self:add_filter_condition_list("cli_location", traffic_direction, "string", "1")
            self:add_filter_condition_list("srv_location", traffic_direction, "string", "1")
        elseif value == "2" then
            self:add_filter_condition_list("cli_location", traffic_direction, "string", "0")
            self:add_filter_condition_list("srv_location", traffic_direction, "string", "1")
        elseif value == "3" then
            self:add_filter_condition_list("cli_location", traffic_direction, "string", "1")
            self:add_filter_condition_list("srv_location", traffic_direction, "string", "0")
        end
    end
end

-- ##############################################

function flow_alert_store:init(args)
    local table_name = "flow_alerts"

    self.super:init()

    if ntop.isClickHouseEnabled() then
        -- Alerts from historical flows (see also RecipientQueue::enqueue)
        table_name = "flow_alerts_view"
        self._write_table_name = "flows"
    end

    self._table_name = table_name
    self._alert_entity = alert_entities.flow
end

-- ##############################################

-- Get the 'real' field name (used by flow alerts where the flow table is a view
-- and we write to the real table which has different column names)
function flow_alert_store:get_column_name(field, is_write, value)
    local col = field

    if is_write and self._write_table_name then
        -- This is using the flow table, in write mode we have to remap columns

        if field == 'cli_ip' or field == 'srv_ip' then
            -- Note: there are separate V4 and V6 columns in the flow table,
            -- we need to use the correct one based on the value
            if string.match(value, ':') then
                -- IPv6
                if field == 'cli_ip' then
                    col = 'IPV6_SRC_ADDR'
                else
                    col = 'IPV6_DST_ADDR'
                end
            else
                -- IPv4
                if field == 'cli_ip' then
                    col = 'IPV4_SRC_ADDR'
                else
                    col = 'IPV4_DST_ADDR'
                end
            end
        else

            -- Convert columns to tags for those who differ
            if field == 'proto' then
                field = 'l4proto'
            end
            if field == 'l7_cat' then
                field = 'l7cat'
            end
            if field == 'l7_proto' then
                field = 'l7proto'
            end
            if field == 'l7_master_proto' then
                field = 'l7proto_master'
            end
            if field == 'flow_risk_bitmap' then
                field = 'flow_risk'
            end

            col = historical_flow_utils.get_flow_column_by_tag(field)
        end

        if not col then
            col = field
        end
    else
        if field == 'flow_risk' then
            col = 'flow_risk_bitmap'
        end
    end

    return col
end

-- ##############################################

-- @brief Labels alerts according to specified filters
function flow_alert_store:acknowledge(label)
    local table_name = self:get_write_table_name()
    local where_clause = self:build_where_clause(true)

    -- Prepare the final query
    local q
    if ntop.isClickHouseEnabled() then
        -- This is using the historical 'flows' table
        q = string.format("ALTER TABLE `%s` UPDATE `%s` = %u, `%s` = '%s', `%s` = %u WHERE %s", table_name,
            self:get_column_name('alert_status', true), alert_consts.alert_status.acknowledged.alert_status_id,
            self:get_column_name('user_label', true), self:_escape(label),
            self:get_column_name('user_label_tstamp', true), os.time(), where_clause)
    else
        q = string.format("UPDATE `%s` SET `alert_status` = %u, `user_label` = '%s', `user_label_tstamp` = %u WHERE %s",
            table_name, alert_consts.alert_status.acknowledged.alert_status_id, self:_escape(label), os.time(),
            where_clause)
    end

    local res = interface.alert_store_query(q)
    return res and table.len(res) == 0
end

-- ##############################################

-- @brief Deletes data according to specified filters
function flow_alert_store:delete()
    local table_name = self:get_write_table_name()
    local where_clause = self:build_where_clause(true)

    -- Prepare the final query
    local q
    if ntop.isClickHouseEnabled() then
        if self._write_table_name then

            -- Fix column type conversion
            where_clause = historical_flow_utils.fixWhereTypes(where_clause)

            q = string.format("ALTER TABLE `%s` UPDATE `IS_ALERT_DELETED` = 1 WHERE %s", table_name, where_clause)
        else
            q = string.format("ALTER TABLE `%s` DELETE WHERE %s ", table_name, where_clause)
        end
    else
        q = string.format("DELETE FROM `%s` WHERE %s ", table_name, where_clause)
    end

    local res = interface.alert_store_query(q)
    return res and table.len(res) == 0
end

-- ##############################################

function flow_alert_store:_get_tstamp_column_name()
    if ntop.isClickHouseEnabled() then
        return "first_seen"
    else
        return "tstamp"
    end
end

-- ##############################################

function flow_alert_store:insert(alert)
    local hex_prefix = ''
    local extra_columns = ''
    local extra_values = ''

    -- Note: this is no longer called when ClickHouse is enabled
    -- as a view on the historical is used. See RecipientQueue::enqueue
    if ntop.isClickHouseEnabled() then
        return -- Safety check
    end

    if ntop.isClickHouseEnabled() then
        extra_columns = "rowid, "
        extra_values = "generateUUIDv4(), "
    else
        hex_prefix = "X"
    end
    -- tprint(alert)
    local alert_key = alert_consts.getAlertType(alert.alert_id, alert.entity_id)
    local mitre_info = alert_consts.getAlertMitreInfo(alert_key)
    local alert_json = json.decode(alert.json)
    alert_json.mitre_info = mitre_info
    alert.json = json.encode(alert_json)

    -- Note
    -- The database contains first_seen, tstamp, tstamp_end for historical reasons.
    -- The time index is set on first_seen, thus:
    -- - tstamp and first_seen contains the same value alert.first_seen
    -- - tstamp_end is set to alert.tstamp (which is the time the alert has been emitted as there is no engage on flows)
    -- - first_seen is used to lookups as this is the indexed field
    -- - tstamp (instead of first_seen) is used in select and for visualization as it's in common to all tables

    -- io.write("---------------------------\n") tprint(debug.traceback()) tprint(alert.flow_risk_bitmap) io.write("---------------------------\n")

    local fmt = "INSERT INTO %s " ..
                    "(%salert_id, alert_status, alert_category, interface_id, tstamp, tstamp_end, severity, ip_version, cli_ip, srv_ip, cli_port, srv_port, vlan_id, " ..
                    "is_cli_attacker, is_cli_victim, is_srv_attacker, is_srv_victim, proto, l7_proto, l7_master_proto, l7_cat, " ..
                    "cli_name, srv_name, cli_country, srv_country, cli_blacklisted, srv_blacklisted, cli_location, srv_location, " ..
                    "cli2srv_bytes, srv2cli_bytes, cli2srv_pkts, srv2cli_pkts, first_seen, community_id, score, " ..
                    "flow_risk_bitmap, alerts_map, cli_host_pool_id, srv_host_pool_id, cli_network, srv_network, probe_ip, input_snmp, output_snmp, " ..
                    "json, info) " ..
                    "VALUES (%s%u, %u, %u, %u, %u, %u, %u, %u, '%s', '%s', %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, '%s', '%s', '%s', " ..
                    "'%s', %u, %u, %u, %u, %u, %u, %u, %u, %u, '%s', %u, %u, %s'%s', %u, %u, %u, %u, '%s', %u, %u, '%s', '%s'); "

    local insert_stmt = string.format(fmt, self:get_write_table_name(), extra_columns, extra_values, alert.alert_id,
        ternary(alert.acknowledged, alert_consts.alert_status.acknowledged.alert_status_id, 0), alert.alert_category,
        self:_convert_ifid(interface.getId()), alert.first_seen, alert.tstamp, -- 10
        map_score_to_severity(alert.score), alert.ip_version, alert.cli_ip, alert.srv_ip, alert.cli_port,
        alert.srv_port, alert.vlan_id, ternary(alert.is_cli_attacker, 1, 0), ternary(alert.is_cli_victim, 1, 0),
        ternary(alert.is_srv_attacker, 1, 0), -- 20
        ternary(alert.is_srv_victim, 1, 0), alert.proto, alert.l7_proto, alert.l7_master_proto, alert.l7_cat,
        self:_escape(alert.cli_name), self:_escape(alert.srv_name), alert.cli_country_name, alert.srv_country_name,
        ternary(alert.cli_blacklisted, 1, 0), -- 30
        ternary(alert.srv_blacklisted, 1, 0), alert.cli_location or 0, alert.srv_location or 0, alert.cli2srv_bytes,
        alert.srv2cli_bytes, alert.cli2srv_packets, alert.srv2cli_packets, alert.first_seen, alert.community_id,
        alert.score, alert.flow_risk_bitmap or 0, -- 40
        hex_prefix, alert.alerts_map, tonumber(alert.cli_host_pool_id or pools.DEFAULT_POOL_ID),
        tonumber(alert.srv_host_pool_id or pools.DEFAULT_POOL_ID),
        tonumber(alert.cli_network or network_consts.UNKNOWN_NETWORK),
        tonumber(alert.srv_network or network_consts.UNKNOWN_NETWORK), alert.probe_ip, alert.input_snmp,
        alert.output_snmp, self:_escape(alert.json), -- 50
        self:_escape(alert.info or ''))

    -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

    return interface.alert_store_query(insert_stmt)
end

-- ##############################################

-- @brief Performs a query for the top l7_proto by alert count
function flow_alert_store:top_l7_proto_historical()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()

    local q = string.format(
        "SELECT l7_proto, sum(score) , count(*) as count  FROM %s WHERE %s GROUP BY l7_proto ORDER BY count DESC LIMIT %u",
        self:get_table_name(), where_clause, self._top_limit)
    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Performs a query for the top VLAN by alert count
function flow_alert_store:top_vlan_historical()
    if not interface.hasVLANs() then
        return {}
    end

    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()

    local q = string.format(
        "SELECT vlan_id, sum(score) , count(*) as count  FROM %s WHERE %s AND vlan_id != 0 GROUP BY vlan_id ORDER BY count DESC LIMIT %u",
        self:get_table_name(), where_clause, self._top_limit)
    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Performs a query for the top client hosts by alert count
function flow_alert_store:top_cli_ip_historical()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()

    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
            "SELECT cli_ip, vlan_id, cli_name, sum(score), count(*) as count FROM %s WHERE %s GROUP BY cli_ip, vlan_id, cli_name ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)
    else
        q = string.format(
            "SELECT cli_ip, vlan_id, cli_name, sum(score), count(*) as count FROM %s WHERE %s GROUP BY cli_ip ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)
    end

    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Performs a query for the top server hosts by alert count
function flow_alert_store:top_srv_ip_historical()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()

    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
            "SELECT srv_ip, vlan_id, srv_name, sum(score) , count(*) as count  FROM %s WHERE %s GROUP BY srv_ip, vlan_id, srv_name ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)
    else
        q = string.format(
            "SELECT srv_ip, vlan_id, srv_name, sum(score) , count(*) as count  FROM %s WHERE %s GROUP BY srv_ip ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)
    end

    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Performs a query for the top domain named hosts for suspicious_dga_domain alerts by alert count
function flow_alert_store:top_srv_ip_domain()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause() .. " AND alert_id = 47 "
    local field_to_search = self:get_column_name('json', false)
    local q = nil
    local q_res = {}
    if ntop.isClickHouseEnabled() then

        q = string.format("SELECT '.' || arrayStringConcat(arraySlice(splitByString('.'," ..
                              string.format('JSON_VALUE(%s, \'$.%s\')', field_to_search,
                "proto.tls.client_requested_server_name") ..
                              "),-2,2),'.') as domain_name_trunc_dot, vlan_id, '*.' || arrayStringConcat(arraySlice(splitByString('.'," ..
                              string.format('JSON_VALUE(%s, \'$.%s\')', field_to_search,
                "proto.tls.client_requested_server_name") ..
                              "),-2,2),'.') as domain_name_trunc_star, sum(score) , count(*) as count  FROM %s WHERE %s GROUP BY vlan_id, '*.' || arrayStringConcat(arraySlice(splitByString('.'," ..
                              string.format('JSON_VALUE(%s, \'$.%s\')', field_to_search,
                "proto.tls.client_requested_server_name") ..
                              "),-2,2),'.'), '.' || arrayStringConcat(arraySlice(splitByString('.'," ..
                              string.format('JSON_VALUE(%s, \'$.%s\')', field_to_search,
                "proto.tls.client_requested_server_name") .. "),-2,2),'.') ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)

        q_res = interface.alert_store_query(q)
    end

    return q_res
end

-- ##############################################

-- @brief Merge top clients and top servers to build a top hosts 
function flow_alert_store:top_ip_merge(top_cli_ip, top_srv_ip)
    local all_ip = {}
    local top_ip = {}
    local ip_names = {}

    for _, p in ipairs(top_cli_ip) do
        all_ip[p.cli_ip] = tonumber(p.count)
        ip_names[p.cli_ip] = {
            name = p.cli_name,
            vlan_id = p.vlan_id
        }
        p.name = p.cli_name
        p.ip = p.cli_ip
    end
    for _, p in ipairs(top_srv_ip) do
        all_ip[p.srv_ip] = (all_ip[p.srv_ip] or 0) + tonumber(p.count)
        ip_names[p.srv_ip] = {
            name = p.srv_name,
            vlan_id = p.vlan_id
        }
        p.name = p.srv_name
        p.ip = p.srv_ip
    end

    for ip, count in pairsByValues(all_ip, rev) do
        top_ip[#top_ip + 1] = {
            ip = ip,
            count = count,
            name = ip_names[ip]["name"],
            vlan_id = ip_names[ip]["vlan_id"]
        }
        if #top_ip >= self._top_limit then
            break
        end
    end

    return top_ip
end

-- ##############################################

-- @brief Performs a query for the top client hosts by alert count
function flow_alert_store:top_cli_network_historical()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()

    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
            "SELECT cli_network, sum(score) , count(*) as count  FROM %s WHERE %s GROUP BY cli_network ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)
    else
        q = string.format(
            "SELECT cli_network, sum(score) , count(*) as count  FROM %s WHERE %s GROUP BY cli_network ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)
    end

    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Performs a query for the top server hosts by alert count
function flow_alert_store:top_srv_network_historical()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()

    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
            "SELECT srv_network, sum(score) , count(*) as count  FROM %s WHERE %s GROUP BY srv_network ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)
    else
        q = string.format(
            "SELECT srv_network, sum(score) , count(*) as count  FROM %s WHERE %s GROUP BY srv_network ORDER BY count DESC LIMIT %u",
            self:get_table_name(), where_clause, self._top_limit)
    end

    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Merge top clients and top servers to build a top hosts 
function flow_alert_store:top_network_merge(top_cli_network, top_srv_network)
    local all_network = {}
    local top_network = {}

    for _, p in ipairs(top_cli_network) do
        all_network[p.cli_network] = tonumber(p.count)
        p.network = p.cli_network
    end
    for _, p in ipairs(top_srv_network) do
        all_network[p.srv_network] = (all_network[p.srv_network] or 0) + tonumber(p.count)
        p.network = p.srv_network
    end

    for network, count in pairsByValues(all_network, rev) do
        top_network[#top_network + 1] = {
            network = network,
            count = count
        }
        if #top_network >= self._top_limit then
            break
        end
    end

    return top_network
end

-- ##############################################

-- @brief Stats used by the dashboard
function flow_alert_store:_get_additional_stats()
    local stats = {}
    stats.top = {}
    stats.top.cli_ip = self:top_cli_ip_historical()
    stats.top.srv_ip = self:top_srv_ip_historical()
    stats.top.ip = self:top_ip_merge(stats.top.cli_ip, stats.top.srv_ip)
    stats.top.l7_proto = self:top_l7_proto_historical()
    stats.top.cli_network = self:top_cli_network_historical()
    stats.top.srv_network = self:top_srv_network_historical()
    stats.top.network = self:top_network_merge(stats.top.cli_network, stats.top.srv_network)
    stats.top.vlan = self:top_vlan_historical()
    stats.top.dga_domain = self:top_srv_ip_domain()
    return stats
end

-- ##############################################

-- @brief Add ip filter
function flow_alert_store:add_ip_filter(ip)
    self:add_filter_condition('ip', 'eq', ip);
end

-- ##############################################

-- @brief Add ip filter
function flow_alert_store:add_vlan_filter(vlan_id)
    self:add_filter_condition('vlan_id', 'eq', vlan_id);
end

-- ##############################################

-- @brief Add domain (info) filter
function flow_alert_store:add_domain_filter(domain)
    self:add_filter_condition('info', 'in', domain);
end

-- ##############################################

-- @brief Add filters according to what is specified inside the REST API
function flow_alert_store:_add_additional_request_filters()
    local ip_version = _GET["ip_version"]
    local ip = _GET["ip"]
    local cli_ip = _GET["cli_ip"]
    local srv_ip = _GET["srv_ip"]
    local cli_name = _GET["cli_name"]
    local srv_name = _GET["srv_name"]
    local cli_port = _GET["cli_port"]
    local srv_port = _GET["srv_port"]
    local vlan_id = _GET["vlan_id"]
    local l7proto = _GET["l7proto"]
    local flow_risk = _GET["flow_risk"]
    local role = _GET["role"]
    local cli_country = _GET["cli_country"]
    local srv_country = _GET["srv_country"]
    local probe_ip = _GET["probe_ip"]
    local input_snmp = _GET["input_snmp"]
    local output_snmp = _GET["output_snmp"]
    local snmp_interface = _GET["snmp_interface"]

    local cli_host_pool_id = _GET["cli_host_pool_id"]
    local srv_host_pool_id = _GET["srv_host_pool_id"]
    local cli_network = _GET["cli_network"]
    local srv_network = _GET["srv_network"]

    local error_code = _GET["l7_error_id"]
    local confidence = _GET["confidence"]
    local community_id = _GET["community_id"]
    local ja3_client = _GET["ja3_client"]
    local ja3_server = _GET["ja3_server"]
    local ja4_client = _GET["ja4_client"]
    local alert_domain = _GET["alert_domain"]
    local l4_proto = _GET["l4proto"]

    local srv2cli_bytes = _GET["srv2cli_bytes"]
    local cli2srv_bytes = _GET["cli2srv_bytes"]

    self:format_traffic_direction(_GET["traffic_direction"])
    self:format_location()

    -- Filter out flows with no alert
    -- Any reason we need this?
    -- self:add_filter_condition_list('alert_id', "0"..tag_utils.SEPARATOR.."neq", 'number')

    self:add_filter_condition_list('vlan_id', vlan_id, 'number')
    self:add_filter_condition_list('ip_version', ip_version)
    self:add_filter_condition_list('ip', ip)
    self:add_filter_condition_list('cli_ip', cli_ip)
    self:add_filter_condition_list('srv_ip', srv_ip)
    self:add_filter_condition_list('cli_name', cli_name)
    self:add_filter_condition_list('srv_name', srv_name)
    self:add_filter_condition_list('cli_country', cli_country)
    self:add_filter_condition_list('srv_country', srv_country)
    self:add_filter_condition_list('cli_port', cli_port, 'number')
    self:add_filter_condition_list('srv_port', srv_port, 'number')
    self:add_filter_condition_list('flow_role', role)
    self:add_filter_condition_list('l7proto', l7proto, 'number')
    self:add_filter_condition_list('flow_risk', flow_risk, 'number')
    self:add_filter_condition_list('proto', l4_proto)

    self:add_filter_condition_list('cli_host_pool_id', cli_host_pool_id, 'number')
    self:add_filter_condition_list('srv_host_pool_id', srv_host_pool_id, 'number')
    self:add_filter_condition_list('cli_network', cli_network, 'number')
    self:add_filter_condition_list('srv_network', srv_network, 'number')

    self:add_filter_condition_list('probe_ip', probe_ip)
    self:add_filter_condition_list('input_snmp', input_snmp)
    self:add_filter_condition_list('output_snmp', output_snmp)
    self:add_filter_condition_list('snmp_interface', snmp_interface)
    self:add_filter_condition_list('community_id', community_id)

    self:add_filter_condition_list('cli2srv_bytes', cli2srv_bytes)
    self:add_filter_condition_list('srv2cli_bytes', srv2cli_bytes)

    self:add_filter_condition_list(self:format_query_json_value('proto.tls.ja3_server_hash'), ja3_server, 'string')
    self:add_filter_condition_list(self:format_query_json_value('proto.tls.ja3_client_hash'), ja3_client, 'string')
    self:add_filter_condition_list(self:format_query_json_value('proto.tls.ja4_client_hash'), ja4_client, 'string')
    self:add_filter_condition_list(self:format_query_json_value('proto.l7_error_code'), error_code, 'string')
    self:add_filter_condition_list(self:format_query_json_value('proto.confidence'), confidence, 'string')
    self:add_filter_condition_list(self:format_query_json_value('proto.tls.client_requested_server_name'), alert_domain,
        'string')

end

-- ##############################################

-- @brief Get info about additional available filters
function flow_alert_store:_get_additional_available_filters()
    local filters = {
        vlan_id = tag_utils.defined_tags.vlan_id,
        ip_version = tag_utils.defined_tags.ip_version,
        ip = tag_utils.defined_tags.ip,
        cli_ip = tag_utils.defined_tags.cli_ip,
        srv_ip = tag_utils.defined_tags.srv_ip,
        cli_name = tag_utils.defined_tags.cli_name,
        srv_name = tag_utils.defined_tags.srv_name,
        cli_port = tag_utils.defined_tags.cli_port,
        srv_port = tag_utils.defined_tags.srv_port,
        cli_country = tag_utils.defined_tags.cli_country,
        srv_country = tag_utils.defined_tags.srv_country,
        role = tag_utils.defined_tags.role,
        l7proto = tag_utils.defined_tags.l7proto,
        info = tag_utils.defined_tags.info,
        flow_risk = tag_utils.defined_tags.flow_risk,

        cli_host_pool_id = tag_utils.defined_tags.cli_host_pool_id,
        srv_host_pool_id = tag_utils.defined_tags.srv_host_pool_id,
        cli_network = tag_utils.defined_tags.cli_network,
        srv_network = tag_utils.defined_tags.srv_network,

        l7_error_id = tag_utils.defined_tags.l7_error_id,
        confidence = tag_utils.defined_tags.confidence,
        community_id = tag_utils.defined_tags.community_id,
        ja3_client = tag_utils.defined_tags.ja3_client,
        ja3_server = tag_utils.defined_tags.ja3_server,
        ja4_client = tag_utils.defined_tags.ja4_client,
        traffic_direction = tag_utils.defined_tags.traffic_direction,
        alert_domain = tag_utils.defined_tags.alert_domain,

        probe_ip = tag_utils.defined_tags.probe_ip,
        input_snmp = tag_utils.defined_tags.input_snmp,
        output_snmp = tag_utils.defined_tags.output_snmp,
        snmp_interface = tag_utils.defined_tags.snmp_interface,
        host_location = tag_utils.defined_tags.host_location,
        cli_location = tag_utils.defined_tags.cli_location,
        srv_location = tag_utils.defined_tags.srv_location,
        last_server = tag_utils.defined_tags.last_server,
        issuer_dn = tag_utils.defined_tags.issuer_dn,
        l4proto = tag_utils.defined_tags.l4proto,

        cli2srv_bytes = tag_utils.defined_tags.cli2srv_bytes,
        srv2cli_bytes = tag_utils.defined_tags.srv2cli_bytes
    }

    return filters
end

-- ##############################################

local RNAME = {
    ADDITIONAL_ALERTS = {
        name = "additional_alerts",
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
    FLOW_RELATED_INFO = {
        name = "flow_related_info",
        export = true
    },
    MSG = {
        name = "msg",
        export = true,
        elements = {"name", "value", "description"}
    },
    FLOW = {
        name = "flow",
        export = true,
        elements = {"srv_ip.label", "srv_ip.value", "srv_port", "cli_ip.label", "cli_ip.value", "cli_port"}
    },

    VLAN_ID = {
        name = "vlan_id",
        export = true
    },
    CLI_IP = {
        name = "cli_ip",
        export = false
    },
    SRV_IP = {
        name = "srv_ip",
        export = false
    },
    CLI_PORT = {
        name = "cli_port",
        export = false
    },
    SRV_PORT = {
        name = "srv_port",
        export = false
    },

    TRAFFIC = {
        name = "total_bytes",
        export = false
    },

    PROTO = {
        name = "proto",
        export = true
    },
    L7_PROTO = {
        name = "l7_proto",
        export = true
    },
    LINK_TO_PAST_FLOWS = {
        name = "link_to_past_flows",
        export = false
    },

    CLI_HOST_POOL_ID = {
        name = "cli_host_pool_id",
        export = false
    },
    SRV_HOST_POOL_ID = {
        name = "srv_host_pool_id",
        export = false
    },
    CLI_NETWORK = {
        name = "cli_network",
        export = false
    },
    SRV_NETWORK = {
        name = "srv_network",
        export = false
    },

    PROBE_IP = {
        name = "probe_ip",
        export = true
    },

    INFO = {
        name = "info",
        export = true
    },

    HIST_FLOW_CLI_INFO = {
        name = "hist_flow_cli_info",
        export = true
    },

    HIST_FLOW_SRV_INFO = {
        name = "hist_flow_srv_info",
        export = true
    },

    HIST_FLOW_INFO = {
        name = "hist_flow_info",
        export = true
    },

}

-- ##############################################

function flow_alert_store:get_rnames()
    return RNAME
end

-- ##############################################

-- @brief Convert an alert coming from the DB (value) to an host_info table, either for the client or for the server
-- @param value The alert as read from the database
-- @param as_client A boolean indicating whether the hostinfo should be build for the client or for the server
function flow_alert_store:_alert2hostinfo(value, as_client)
    if as_client then
        return {
            ip = value["cli_ip"],
            name = value["cli_name"]
        }
    else
        return {
            ip = value["srv_ip"],
            name = value["srv_name"]
        }
    end
end

-- ##############################################

local function location(host_location)
    if tonumber(host_location) == 0 then
        -- Remote
        return "remote"
    elseif tonumber(host_location) == 1 then
        return "local"
    else
        return "multicast"
    end
end

-- ##############################################

-- @brief Convert an alert coming from the DB (value) to a record returned by the REST API
-- if verbose == true returns historical flow data info
function flow_alert_store:format_record(value, no_html, verbose)
    local record = self:format_json_record_common(value, alert_entities.flow.entity_id, no_html)
    local alert_info = alert_utils.getAlertInfo(value)
    local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), true --[[ no_html --]] ,
        alert_entities.flow.entity_id)
    local show_cli_port = (value["cli_port"] ~= '' and value["cli_port"] ~= '0')
    local show_srv_port = (value["srv_port"] ~= '' and value["srv_port"] ~= '0')
    local msg = alert_utils.formatFlowAlertMessage(interface.getId(), value, alert_info, false, local_explorer)
    local active_url = ""
    local attacker = ""
    local victim = ""

    local alert_json = {}
    if not isEmptyString(value.json) then
        alert_json = json.decode(value.json) or {}
    end

    -- Add link to active flow
    local flow_related_info = addExtraFlowInfo(alert_json, value, no_html --[[ Send these info in json format ]] )

    local alert_risk
    if tonumber(value.alert_id) then
        alert_risk = ntop.getFlowAlertRisk(tonumber(value.alert_id))
    end

    -- TLS IssuerDN
    local flow_tls_issuerdn = nil
    if alert_risk and alert_risk > 0 and -- record.script_key == 'tls_certificate_selfsigned'
    tonumber(value.alert_id) == flow_alert_keys.flow_alert_tls_certificate_selfsigned then
        flow_tls_issuerdn = alert_utils.get_flow_risk_info(alert_risk, alert_info)
    end
    if isEmptyString(flow_tls_issuerdn) then
        flow_tls_issuerdn = getExtraFlowInfoTLSIssuerDN(alert_json)
    end

    if not no_html and alert_json and (alert_json["ntopng.key"]) and (alert_json["hash_entry_id"]) then
        local active_flow = interface.findFlowByKeyAndHashId(alert_json["ntopng.key"], alert_json["hash_entry_id"])

        if active_flow and active_flow["seen.first"] < tonumber(value["tstamp_end"]) then
            local href = string.format("%s/lua/flow_details.lua?flow_key=%u&flow_hash_id=%u", ntop.getHttpPrefix(),
                active_flow["ntopng.key"], active_flow["hash_entry_id"])
            active_url = href
        end
    end

    -- add additional flow related info
    if (verbose == "true") then
        
        -- get alert details page info
        local flow = db_search_manager.get_flow(value["rowid"], value["tstamp_epoch"], "")
        
        -- format cli flow info
        local flow_cli_info = {
            isVictim = tonumber(flow["IS_CLI_VICTIM"] or ""),
            isAttacker = tonumber(flow["IS_CLI_ATTACKER"] or "")
        }

        -- format srv flow info
        local flow_srv_ip = {
            isVictim = tonumber(flow["IS_SRV_VICTIM"] or ""),
            isAttacker = tonumber(flow["IS_SRV_ATTACKER"] or "")
        }

        -- detailed flow info -> /lua/pro/db_flow_details.lua page
        local detailed_flow_info = {
            alert_name = alert_name,
            -- dst2src_bytes = tonumber(flow["DST2SRC_BYTES"] or 0),
            -- src2dst_bytes = tonumber(flow["SRC2DST_BYTES"] or 0),
            status = tonumber(flow["STATUS"] or ""),
            alert_status = tonumber(flow["ALERT_STATUS"] or ""),
            packets = tonumber(flow["PACKETS"] or ""),
            major_connection_state = tonumber(flow["MAJOR_CONNECTION_STATE"] or ""),
            dst2src_tcp_flags = tonumber(flow["DST2SRC_TCP_FLAGS"] or ""),
            src2dst_tcp_flags = tonumber(flow["SRC2DST_TCP_FLAGS"] or ""),
            latency_to_srv_us = tonumber(flow["SERVER_NW_LATENCY_US"] or ""),
            latency_to_cli_us = tonumber(flow["CLIENT_NW_LATENCY_US"] or ""),
            -- protocol = tonumber(flow["PROTOCOL"] or ""),
            flow_risk = tonumber(flow["FLOW_RISK"] or ""),
        }

        -- add extracted data to JSON response
        record[RNAME.HIST_FLOW_CLI_INFO.name] = flow_cli_info
        record[RNAME.HIST_FLOW_SRV_INFO.name] = flow_cli_info
        record[RNAME.HIST_FLOW_INFO.name] = detailed_flow_info
    end

    local other_alerts_by_score = {} -- Table used to keep messages ordered by score
    local additional_alerts = {}

    if value.alerts_map then
        other_alerts_by_score, additional_alerts = alert_utils.format_other_alerts(value.alerts_map, value['alert_id'],
            nil, nil, no_html)
    end

    -- Print additional issues, sorted by score
    record[RNAME.ADDITIONAL_ALERTS.name] = ''
    local cur_additional_alert = 0
    for _, messages in pairsByKeys(other_alerts_by_score, rev) do
        for _, message in pairsByValues(messages, asc) do
            local cur_msg = ''
            if cur_additional_alert > 0 then
                -- Every 4 issues print a newline
                if not no_html then
                    cur_msg = cur_additional_alert and "<br>"
                else
                    cur_msg = cur_additional_alert and " - "
                end
            end
            cur_additional_alert = cur_additional_alert + 1

            cur_msg = cur_msg .. message
            record[RNAME.ADDITIONAL_ALERTS.name] = record[RNAME.ADDITIONAL_ALERTS.name] .. cur_msg
        end
    end

    local shorten_msg

    record[RNAME.ADDITIONAL_ALERTS.name] = {
        descr = record[RNAME.ADDITIONAL_ALERTS.name]
    }

    if no_html then
        msg = noHtml(msg)
    else
        record[RNAME.DESCRIPTION.name] = {
            descr = msg,
            shorten_descr = shorten_msg
        }
    end

    -- local proto = string.lower(interface.getnDPIProtoName(tonumber(value["l7_master_proto"])))

    local flow_server_name = getExtraFlowInfoServerName(alert_json)
    local flow_domain
    if hostnameIsDomain(flow_server_name) then
        flow_domain = flow_server_name
    end

    record[RNAME.INFO.name] = {
        label = value["info"] or "",
        value = value["info"] or "",
        issuerdn = flow_tls_issuerdn -- IssuerDN used for alert exclusion
    }

    record[RNAME.FLOW_RELATED_INFO.name] = {
        descr = flow_related_info or {}
    }

    record[RNAME.ALERT_NAME.name] = alert_name

    local cli_host_pool_id = RNAME.CLI_HOST_POOL_ID.name
    record[cli_host_pool_id] = {
        value = value['cli_host_pool_id'],
        label = getPoolName(value['cli_host_pool_id'])
    }

    local srv_host_pool_id = RNAME.SRV_HOST_POOL_ID.name
    record[srv_host_pool_id] = {
        value = value['srv_host_pool_id'],
        label = getPoolName(value['srv_host_pool_id'])
    }

    local cli_network = RNAME.CLI_NETWORK.name
    record[cli_network] = {
        value = value['cli_network'],
        label = getLocalNetworkAliasById(value['cli_network'])
    }

    local srv_network = RNAME.SRV_NETWORK.name
    record[srv_network] = {
        value = value['srv_network'],
        label = getLocalNetworkAliasById(value['srv_network'])
    }

    -- Removing the server network if the host has no network
    if value['srv_network'] == '65535' then
        record[srv_network]['label'] = ''
        record[srv_network]['value'] = ''
    end

    if value['cli_network'] == '65535' then
        record[cli_network]['label'] = ''
        record[cli_network]['value'] = ''
    end

    if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
        msg = ""
    end

    record[RNAME.MSG.name] = {
        name = noHtml(alert_name),
        fullname = alert_name,
        value = tonumber(value["alert_id"]),
        description = msg
    }

    if not no_html then
        record[RNAME.MSG.name].configset_ref = alert_utils.getConfigsetAlertLink(alert_info)
    end

    -- Format Client  

    local cli_ip = value["cli_ip"]

    local reference_html = ""
    if not isEmptyString(cli_ip) and not no_html then
        reference_html = hostinfo2detailshref({
            ip = cli_ip,
            value["vlan_id"]
        }, nil, href_icon, "", true, nil, false)
        if reference_html == href_icon then
            reference_html = ""
        end
    end

    -- In case no country is found, let's check if the host is in memory and retrieve country info
    local country = value["cli_country"]

    if (isEmptyString(country) or country == "nil") and not isEmptyString(cli_ip) then
        local host_info = interface.getHostMinInfo(cli_ip)
        if host_info then
            country = host_info["country"] or ""
        end
    end

    record["community_id"] = {
        value = value["community_id"],
        name = value["community_id"]
    }

    local flow_cli_ip = {
        value = cli_ip or "",
        ip = cli_ip or "",
        label = cli_ip or "",
        reference = reference_html,
        country = country,
        blacklisted = value["cli_blacklisted"],
        location = location(value["cli_location"])
    }

    if not isEmptyString(value["cli_name"]) and value["cli_name"] ~= flow_cli_ip["value"] then
        flow_cli_ip["name"] = value["cli_name"]
    end

    if not isEmptyString(cli_ip) then
        local label = hostinfo2label(self:_alert2hostinfo(value, true --[[ As client --]] ), false --[[ Show VLAN --]] ,
            false --[[ Shorten --]] , true --[[ Skip Resolution ]] )

        -- Shortened label if necessary for UI purposes
        flow_cli_ip["label"] = label
        flow_cli_ip["label_long"] = label
    end

    -- Format Server

    local srv_ip = value["srv_ip"]

    reference_html = ""
    if not no_html and not isEmptyString(srv_ip) then
        reference_html = hostinfo2detailshref({
            ip = srv_ip,
            vlan = value["vlan_id"]
        }, nil, href_icon, "", true)
        if reference_html == href_icon then
            reference_html = ""
        end
    end

    -- In case no country is found, let's check if the host is in memory and retrieve country info
    country = value["srv_country"]

    if (isEmptyString(country) or country == "nil") and not isEmptyString(srv_ip) then
        local host_info = interface.getHostMinInfo(srv_ip)
        if host_info then
            country = host_info["country"] or ""
        end
    end

    local flow_srv_ip = {
        value = srv_ip or "",
        ip = srv_ip or "",
        label = srv_ip or "",
        reference = reference_html,
        country = country,
        blacklisted = value["srv_blacklisted"],
        location = location(value["srv_location"])
    }

    if not isEmptyString(value["srv_name"]) and value["srv_name"] ~= flow_srv_ip["value"] then
        flow_srv_ip["name"] = value["srv_name"]
    end

    if not isEmptyString(srv_ip) then
        local label =
            hostinfo2label(self:_alert2hostinfo(value, false --[[ As server --]] ), false --[[ Show VLAN --]] , false --[[ Shorten --]] ,
                true --[[ Skip Resolution ]] )

        -- Shortened label if necessary for UI purposes
        flow_srv_ip["label"] = label
        flow_srv_ip["label_long"] = label
    end

    local vlan = {
        label = "",
        title = "",
        value = 0
    }

    if value["vlan_id"] and tonumber(value["vlan_id"]) ~= 0 then
        vlan = {
            label = getFullVlanName(value["vlan_id"], true --[[ Compact --]] ),
            title = getFullVlanName(value["vlan_id"], false --[[ non Compact --]] ),
            value = tonumber(value["vlan_id"])
        }
    end

    local flow_cli_port = {
        value = value["cli_port"] or ""
    }
    local flow_srv_port = {
        value = value["srv_port"] or ""
    }

    -- Used to render custom queries (compatible with historical flows columns definition)
    record[RNAME.CLI_IP.name] = flow_cli_ip
    record[RNAME.SRV_IP.name] = flow_srv_ip
    record[RNAME.CLI_PORT.name] = flow_cli_port
    record[RNAME.SRV_PORT.name] = flow_srv_port
    record[RNAME.VLAN_ID.name] = vlan

    if not no_html then
        -- Used to render the flow column in raw alerts
        record[RNAME.FLOW.name] = {
            vlan = vlan,
            cli_ip = flow_cli_ip,
            srv_ip = flow_srv_ip,
            cli_port = value["cli_port"],
            srv_port = value["srv_port"],
            active_url = active_url
        }
    end

    local l4_protocol
    if not isEmptyString(value["proto"]) then
        l4_protocol = l4_proto_to_string(value["proto"])
    end

    record[RNAME.PROTO.name] = {
        value = value["proto"] or "",
        label = l4_protocol or ""
    }

    if value["is_cli_victim"] == "1" then
        record["cli_role"] = {
            value = 'victim',
            label = i18n("victim"),
            tag_label = i18n("victim")
        }
    end
    if value["is_cli_attacker"] == "1" then
        record["cli_role"] = {
            value = 'attacker',
            label = i18n("attacker"),
            tag_label = i18n("attacker")
        }
    end
    if value["is_srv_victim"] == "1" then
        record["srv_role"] = {
            value = 'victim',
            label = i18n("victim"),
            tag_label = i18n("victim")
        }
    end
    if value["is_srv_attacker"] == "1" then
        record["srv_role"] = {
            value = 'attacker',
            label = i18n("attacker"),
            tag_label = i18n("attacker")
        }
    end

    local l7_protocol
    if tonumber(value["l7_master_proto"]) and tonumber(value["l7_proto"]) then
        l7_protocol = interface.getnDPIFullProtoName(tonumber(value["l7_master_proto"]), tonumber(value["l7_proto"]))
    end

    -- Check the two labels, otherwise an ICMP:ICMP label could be possible
    local proto_label = l7_protocol

    if l4_protocol and l7_protocol and l4_protocol ~= l7_protocol then
        proto_label = l4_protocol .. ":" .. l7_protocol
    end

    record[RNAME.L7_PROTO.name] = {
        value = ternary(tonumber(value["l7_proto"]) ~= 0, value["l7_proto"], value["l7_master_proto"]) or "",
        l4_label = l4_protocol or "",
        l7_label = l7_protocol or "",
        label = proto_label or "",
        confidence = format_confidence_from_json(value)
    }

    local traffic_stats = {}

    traffic_stats.bytes_sent = tonumber(value["cli2srv_bytes"] or 0)
    traffic_stats.bytes_rcvd = tonumber(value["srv2cli_bytes"] or 0)

    if value["total_bytes"] then
        traffic_stats.total_bytes = tonumber(value["total_bytes"])
    end
    if value["srv2cli_pkts"] and value["cli2srv_pkts"] then
        traffic_stats.total_packets = tonumber(value["srv2cli_pkts"]) + tonumber(value["cli2srv_pkts"])
    end
    record[RNAME.TRAFFIC.name] = traffic_stats

    -- Add link to historical flow
    if ntop.isEnterpriseM() and hasClickHouseSupport() and not no_html and tonumber(value["tstamp"]) and
        tonumber(value["tstamp_end"]) then
        local op_suffix = tag_utils.SEPARATOR .. 'eq'
        local href = string.format(
            '%s/lua/pro/db_search.lua?epoch_begin=%u&epoch_end=%u&cli_ip=%s%s&srv_ip=%s%s&cli_port=%s%s&srv_port=%s%s&l4proto=%s%s',
            ntop.getHttpPrefix(), tonumber(value["tstamp"]) - (5 * 60), tonumber(value["tstamp_end"]) + (5 * 60),
            value["cli_ip"], op_suffix, value["srv_ip"], op_suffix,
            ternary(show_cli_port, tostring(value["cli_port"]), ''), op_suffix,
            ternary(show_srv_port, tostring(value["srv_port"]), ''), op_suffix, l4_protocol or "", op_suffix)

        if vlan then
            href = href .. string.format('&vlan_id=%s%s', vlan.value, op_suffix)
        end

        record[RNAME.LINK_TO_PAST_FLOWS.name] = href
    end

    -- Add BPF filter (for PCAP extractions)
    -- and Tag filters (e.g. to jump from custom queries to raw alerts)

    record['filter'] = {}

    local rules = {}
    local filters = {}
    local op_suffix = 'eq'

    if not isEmptyString(value["alert_id"]) and tonumber(value["alert_id"]) > 0 then
        filters[#filters + 1] = {
            id = "alert_id",
            value = value["alert_id"],
            op = op_suffix
        }
    end
    if not isEmptyString(value["vlan_id"]) and tonumber(value["vlan_id"]) > 0 then
        filters[#filters + 1] = {
            id = "vlan_id",
            value = value["vlan_id"],
            op = op_suffix
        }
    end
    if not isEmptyString(value["cli_ip"]) then
        rules[#rules + 1] = 'host ' .. value["cli_ip"]
        filters[#filters + 1] = {
            id = "cli_ip",
            value = value["cli_ip"],
            op = op_suffix
        }
    end
    if not isEmptyString(value["srv_ip"]) then
        rules[#rules + 1] = 'host ' .. value["srv_ip"]
        filters[#filters + 1] = {
            id = "srv_ip",
            value = value["srv_ip"],
            op = op_suffix
        }
    end
    if not isEmptyString(value["cli_port"]) and tonumber(value["cli_port"]) > 0 then
        rules[#rules + 1] = 'port ' .. tostring(value["cli_port"])
        filters[#filters + 1] = {
            id = "cli_port",
            value = value["cli_port"],
            op = op_suffix
        }
    end
    if not isEmptyString(value["srv_port"]) and tonumber(value["srv_port"]) > 0 then
        rules[#rules + 1] = 'port ' .. tostring(value["srv_port"])
        filters[#filters + 1] = {
            id = "srv_port",
            value = value["srv_port"],
            op = op_suffix
        }
    end
    if not isEmptyString(value["info"]) then
        filters[#filters + 1] = {
            id = "info",
            value = value["info"],
            op = op_suffix
        }
    end

    if #rules > 0 and tonumber(value["tstamp"]) and tonumber(value["tstamp_end"]) then
        record['filter'].epoch_begin = tonumber(value["tstamp"])
        record['filter'].epoch_end = tonumber(value["tstamp_end"]) + 1
        record['filter'].bpf = table.concat(rules, " and ")
    end
    record['filter'].tag_filters = filters

    local probe_ip = ''
    local probe_label = ''
    if value["probe_ip"] and value["probe_ip"] ~= "0.0.0.0" then
        probe_ip = value["probe_ip"]
        probe_label = getProbeName(probe_ip)
    end
    record[RNAME.PROBE_IP.name] = {
        value = probe_ip,
        label = probe_label
    }

    return record
end

-- ##############################################

local function get_label_link(label, tag, value, add_hyperlink)
    if add_hyperlink then
        return "<a href=\"" .. ntop.getHttpPrefix() .. "/lua/alert_stats.lua?status=" .. _GET['status'] .. "&page=" ..
                   _GET['page'] .. "&" .. tag .. "=" .. value .. tag_utils.SEPARATOR .. "eq\" " .. ">" .. label ..
                   "</a>"
    else
        return label
    end
end

-- ##############################################

local function get_flow_link(fmt, add_hyperlink)
    local label = ''

    local value = fmt['flow']['cli_ip']['value']
    local vlan = ''
    local tag = 'cli_ip'
    local vlan_id = 0

    if fmt['flow']['vlan'] and fmt['flow']['vlan']["value"] ~= 0 then
        vlan_id = tonumber(fmt['flow']['vlan']["value"])
        vlan = '@' ..
                   get_label_link(fmt['flow']['vlan']['label'], 'vlan_id', fmt['flow']['vlan']["value"], add_hyperlink)
    end

    local reference = hostinfo2detailshref({
        ip = fmt['flow']['cli_ip']['value'],
        vlan = vlan_id
    }, nil, href_icon, "", true)

    local cli_ip = ""
    local srv_ip = ""

    if fmt['flow']['cli_ip']['label_long'] ~= fmt['flow']['cli_ip']['value'] then
        if add_hyperlink then
            cli_ip = " [ " .. get_label_link(fmt['flow']['cli_ip']['value'], 'cli_ip', value, add_hyperlink) .. " ]"
        end
        value = fmt['flow']['cli_ip']['label_long']
        tag = 'cli_name'
    end
    label = label .. get_label_link(fmt['flow']['cli_ip']['label_long'], tag, value, add_hyperlink) .. cli_ip

    if fmt['flow']['cli_port'] then
        label = label .. vlan .. ':' ..
                    get_label_link(fmt['flow']['cli_port'], 'cli_port', fmt['flow']['cli_port'], add_hyperlink)
    end

    if add_hyperlink then
        label = label .. " " .. reference
    end

    label = label .. ' <i class="fas fa-exchange-alt fa-lg" aria-hidden="true"></i> '

    reference = hostinfo2detailshref({
        ip = fmt['flow']['srv_ip']['value'],
        vlan = vlan_id
    }, nil, href_icon, "", true)
    local value = fmt['flow']['srv_ip']['value']
    local tag = 'srv_ip'
    if fmt['flow']['srv_ip']['label_long'] ~= fmt['flow']['srv_ip']['value'] then
        if add_hyperlink then
            srv_ip = " [ " .. get_label_link(fmt['flow']['srv_ip']['value'], 'srv_ip', value, add_hyperlink) .. " ]"
        end
        value = fmt['flow']['srv_ip']['label_long']
        tag = 'srv_name'
    end
    label = label .. get_label_link(fmt['flow']['srv_ip']['label_long'], tag, value, add_hyperlink) .. srv_ip

    if fmt['flow']['srv_port'] then
        label = label .. vlan .. ':' ..
                    get_label_link(fmt['flow']['srv_port'], 'srv_port', fmt['flow']['srv_port'], add_hyperlink)
    end

    if add_hyperlink then
        label = label .. " " .. reference
    end

    return label
end

-- ##############################################

-- @brief Edit specifica proto info, like converting 
--       timestamp to date/time for TLS Certificate Validity
local function editProtoDetails(proto_info)
    for key, value in pairs(proto_info) do
        if type(value) ~= "table" then
            proto_info[key] = nil
        end
    end

    for proto, info in pairs(proto_info) do
        if proto == "tls" then
            info = format_tls_info(info)
            break
        elseif proto == "dns" then
            info = format_dns_query_info(info)
            break
        elseif proto == "http" then
            info = format_http_info(info)
            break
        elseif proto == "icmp" then
            info = format_icmp_info(info)
            break
        end
    end

    return proto_info
end

-- ##############################################

local function add_historical_link(value, flow_link)
    local historical_href = ""

    if ntop.isClickHouseEnabled() then
        historical_href = "<a href=\"" .. ntop.getHttpPrefix() .. "/lua/pro/db_flow_details.lua?row_id=" ..
                              value["rowid"] .. "&tstamp=" .. value["tstamp_epoch"] .. "\" title='" ..
                              i18n('alert_details.flow_details') ..
                              "' target='_blank'> <i class='fas fa fa-search-plus'></i> </a>"
    end

    return flow_link .. " " .. historical_href
end

-- ##############################################

-- @brief Get a label/title for the alert coming from the DB (value)
function flow_alert_store:get_alert_label(value)
    local fmt = self:format_record(value, false)
    return fmt['msg']['name'] .. ' | ' .. get_flow_link(fmt, false)
end

-- ##############################################

-- @brief Convert an alert coming from the DB (value) to a list of items to be printed in the details page
function flow_alert_store:get_alert_details(value)
    local details = {}
    local fmt = self:format_record(value, false)
    local add_hyperlink = true
    local json = json.decode(value["json"]) or {}
    local proto_info = json["proto"]
    local traffic_info = {}

    details[#details + 1] = {
        label = i18n("alerts_dashboard.alert"),
        content = get_label_link(fmt['alert_id']['label'], 'alert_id', fmt['alert_id']['value'], add_hyperlink)
    }

    details[#details + 1] = {
        label = i18n("flow_details.flow_peers_client_server"),
        content = add_historical_link(value, get_flow_link(fmt, add_hyperlink))
    }

    details[#details + 1] = {
        label = i18n("protocol") .. " / " .. i18n("application"),
        content = get_label_link(fmt['l7_proto']['l4_label'] .. ':' .. fmt['l7_proto']['l7_label'], 'l7proto',
            fmt['l7_proto']['value'], add_hyperlink)
    }

    details[#details + 1] = {
        label = i18n("show_alerts.alert_datetime"),
        content = fmt['tstamp']['label']
    }

    details[#details + 1] = {
        label = i18n("score"),
        content = '<span style="color: ' .. fmt['score']['color'] .. '">' .. fmt['score']['label'] .. '</span>'
    }

    details[#details + 1] = {
        label = i18n("description"),
        content = fmt['msg']['description']
    }

    details[#details + 1] = {
        label = i18n("flow_details.additional_alert_type"),
        content = fmt['additional_alerts']['descr']
    }

    if (proto_info and (proto_info.l7_error_code ~= nil) and (proto_info.l7_error_code ~= 0)) then
        details[#details + 1] = {
            label = i18n("l7_error_code"),
            content = proto_info.l7_error_code
        }

        proto_info.l7_error_code = nil -- Avoid to print it twice in the flow details section
    end

    proto_info = editProtoDetails(proto_info or {})
    traffic_info = format_common_info(value, traffic_info)

    details[#details + 1] = {
        label = i18n("flow_details.traffic_info"),
        content = traffic_info
    }

    for k, info in pairs(proto_info or {}) do
        details[#details + 1] = {
            label = i18n("alerts_dashboard.flow_related_info"),
            content = info
        }
    end

    --[[
   details[#details + 1] = {
      label = "Title",
      content = {
         [1] = "Content 1",
         [2] = "Content 2",
      }
   }
   --]]

    return details
end

return flow_alert_store