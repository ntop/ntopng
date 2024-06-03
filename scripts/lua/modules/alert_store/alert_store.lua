--
-- (C) 2021-24 - ntop.org
--
-- Module to keep things in common across alert_store of various type
local dirs = ntop.getDirs()

-- Import the classes library.
local classes = require "classes"
require "lua_utils"
local json = require "dkjson"
local format_utils = require "format_utils"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_severities = require "alert_severities"
local tag_utils = require "tag_utils"
local alert_entities = require "alert_entities"
local alert_category_utils = require "alert_category_utils"
local os_utils = require("os_utils")

-- ##############################################

local alert_store = classes.class()

-- ##############################################

local EARLIEST_AVAILABLE_EPOCH_CACHE_KEY = "ntopng.cache.alerts.ifid_%d.table_%s.status_%d.earliest_available_epoch"

-- Default number of time slots to be returned when aggregating by time
local NUM_TIME_SLOTS = 31
local TOP_LIMIT = 10

local user = "no_user"

if (_SESSION) and (_SESSION["user"]) then
    user = _SESSION["user"]
end

local ALERT_SORTING_ORDER = "ntopng.cache.alert.%d.%s.sort_order.%s"
local ALERT_SORTING_COLUMN = "ntopng.cache.alert.%d.%s.sort_column.%s"
local ALERT_SCORE_FILTER_KEY = "ntopng.alert.score.ifid_%d"

local CSV_SEPARATOR = "|"

-- ##############################################

function alert_store:init(args)
    self._group_by = nil
    self._top_limit = TOP_LIMIT

    -- Note: _where contains conditions for the where clause.
    -- Example:
    -- {
    --   -- List of items
    --   'alert_id' = {
    --     all = {
    --       -- List of AND conditions
    --       {
    --         field = 'alert_id',
    --         op = 'neq',
    --         value = 1,
    --         value_type = 'number', -- default: string
    --         sql = 'alert_id = 1', -- special conditions only
    --       }
    --     },
    --     any = {
    --       -- List of OR conditions
    --     }
    --   }
    -- }
    self._where = {}

    -- tprint(debug.traceback())
end

-- ##############################################

-- Get the table name
function alert_store:get_table_name()
    return self._table_name
end

-- ##############################################

-- Get the table name for write operations (this may differ from the
-- tabel name (e.g. flows on clickhouse)
function alert_store:get_write_table_name()
    if self._write_table_name then
        return self._write_table_name
    else
        return self._table_name
    end
end

-- ##############################################

function alert_store:_escape(str)
    if not str then
        return ""
    end

    str = str:gsub("'", "''")
    if (str == '\\') then
        str = ''
    end

    return str
end

-- ##############################################

-- @brief Converts interface IDs into their database type
--       Normal interface IDs are untouched.
--       The system interface ID is converted from -1 to (u_int16_t)-1 to handle everything as unsigned integer
function alert_store:_convert_ifid(ifid)
    -- The system interface ID becomes (u_int16_t)-1
    return 0xFFFF & tonumber(ifid)
end

-- ##############################################

-- @brief Check if the submitted fields are avalid (i.e., they are not injection attempts)
function alert_store:_valid_fields(fields)
    local f = fields:split(",") or {fields}

    for _, field in pairs(f) do
        -- only allow alphanumeric characters and underscores
        if not string.match(field, "^[%w_(*) ]+$") then
            traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Invalid field found in query [%s]",
                field:gsub('%W', '') --[[ prevent stored injections --]] ))
            return false
        end
    end

    return true
end

-- ##############################################

-- Get the system ifid
function alert_store:get_system_ifid()
    -- The System Interface has the id -1 and in u_int16_t is 65535
    return 65535
end

-- ##############################################

-- @brief ifid
function alert_store:get_ifid()
    local ifid = _GET["ifid"] or interface.getId()

    ifid = tonumber(ifid)

    -- The System Interface has the id -1 and in u_int16_t is 65535
    if ifid == -1 then
        ifid = self:get_system_ifid()
    end

    return ifid
end

-- ##############################################

-- @brief Return the alert family name
function alert_store:get_family()
    local family_name

    if self._alert_entity then
        family_name = self._alert_entity.alert_store_name
    end

    return family_name
end

-- ##############################################

function alert_store:_build_alert_status_condition(status, is_write)
    local field = 'alert_status'

    field = self:get_column_name(field, is_write)

    if status == "any" then
        return string.format(" ((%s = %u) OR (%s = %u)) ", 
            field, alert_consts.alert_status.historical.alert_status_id,
            field, alert_consts.alert_status.acknowledged.alert_status_id)
    else
        return string.format(" %s = %u ",
            field, alert_consts.alert_status[status].alert_status_id)
    end
end

-- ##############################################

-- @brief Add filters on status (any, engaged, historical, or acknowledged)
-- @param status A status key (one of those enumerated in `alert_consts.alert_status`)
-- @return True if set is successful, false otherwise
function alert_store:add_status_filter(status, is_write)
    if not self._status then
        if not status then
           status = "historical"
        end

        if alert_consts.alert_status[status] then
            self._status = alert_consts.alert_status[status].alert_status_id

            if status == "engaged" then
                -- Engaged alerts don't add a database filter as they are in-memory only
            else
                self:add_filter_condition_raw('alert_status', self:_build_alert_status_condition(status, is_write))
            end
        end

        return true
    end

    return false
end

-- ##############################################

-- @brief Return the indexed tstamp column
function alert_store:_get_tstamp_column_name()
    return "tstamp"
end

-- ##############################################

-- @brief Add filters on time
-- @param epoch_begin The start timestamp
-- @param epoch_end The end timestamp
-- @return True if set is successful, false otherwise
function alert_store:add_time_filter(epoch_begin, epoch_end, is_write)
    if not self._epoch_begin and tonumber(epoch_begin) and tonumber(epoch_end) then

        self._epoch_begin = tonumber(epoch_begin)
        self._epoch_end = tonumber(epoch_end)

        local tstamp_column = self:_get_tstamp_column_name()

        local field = tstamp_column
        field = self:get_column_name(field, is_write)

        self:add_filter_condition_raw(tstamp_column, string.format("%s >= %u AND %s <= %u", field, self._epoch_begin,
            field, self._epoch_end))
    end

    return true
end

-- ##############################################

-- Get the 'real' field name (used by flow alerts where the flow table is a view
-- and we write to the real table which has different column names)
function alert_store:get_column_name(field, is_write)
    return field
end

-- ##############################################

function alert_store:build_sql_cond(cond, is_write)
    if cond.sql then
        return cond.sql -- special condition
    end

    local real_field = self:get_column_name(cond.field, is_write, cond.value)

    local sql_cond

    local sql_op = tag_utils.tag_operators[cond.op]

    -- Special case: l7proto
    if cond.field == 'l7proto' then
        local and_cond = 'neq'
        if tonumber(cond.value) == 0 --[[ Unknown --]] then
            and_cond = 'eq'
        end

        -- Search also in l7_master_proto, unless value is 0 (Unknown)
        sql_cond = string.format("(%s %s %u %s %s %s %u)", self:get_column_name('l7_proto', is_write), sql_op,
            cond.value, ternary(cond.op == and_cond, 'AND', 'OR'), self:get_column_name('l7_master_proto', is_write),
            sql_op, cond.value)

    elseif cond.field == 'alert_id' and tonumber(cond.value) ~= 0 then

        if self._alert_entity == alert_entities.flow and ntop.isClickHouseEnabled() then
            -- filter with the predominant alert_id and also search 
            -- the alert_id in the alerts_map where the other flow alerts are present.
            local alert_id_bit = "bitShiftLeft(toUInt128('1'), " .. cond.value .. ")"
            local and_cond = 'neq'
            sql_cond = string.format(" (%s %s %u %s (bitAnd(%s,reinterpretAsUInt128(reverse(unhex(%s)))) %s %s) ) ",
                self:get_column_name('alert_id', is_write), sql_op, cond.value, ternary(cond.op == and_cond, 'AND', 'OR'),
                alert_id_bit, self:get_column_name('alerts_map', is_write), sql_op, alert_id_bit)
        else
            -- TODO implement alerts_map match with sqlite
            sql_cond = string.format(" (%s %s %u) ", self:get_column_name('alert_id', is_write), sql_op, cond.value)
        end

        -- Special case: ip (with vlan)
    elseif cond.field == 'ip' or cond.field == 'cli_ip' or cond.field == 'srv_ip' then
        local host = hostkey2hostinfo(cond.value)
        if not isEmptyString(host["host"]) then
            if not host["vlan"] or host["vlan"] == 0 then
                if cond.field == 'ip' and self._alert_entity == alert_entities.flow then
                    sql_cond = string.format("(%s %s ('%s') %s %s %s ('%s'))",
                        self:get_column_name('cli_ip', is_write, cond.value), sql_op, cond.value,
                        ternary(cond.op == 'neq', 'AND', 'OR'), self:get_column_name('srv_ip', is_write, cond.value),
                        sql_op, cond.value)
                else
                    sql_cond = string.format("%s %s ('%s')", real_field, sql_op, cond.value)
                end
            else
                if cond.field == 'ip' and self._alert_entity == alert_entities.flow then
                    sql_cond = string.format("((%s %s ('%s') %s %s %s ('%s')) %s %s %s %u)",
                        self:get_column_name('cli_ip', is_write, cond.value), sql_op, host["host"],
                        ternary(cond.op == 'neq', 'AND', 'OR'), self:get_column_name('srv_ip', is_write, cond.value),
                        sql_op, host["host"], self:get_column_name('vlan_id', is_write),
                        ternary(cond.op == 'neq', 'OR', 'AND'), sql_op, host["vlan"])
                else
                    sql_cond = string.format("(%s %s ('%s') %s %s %s %u)", real_field, sql_op, host["host"],
                        ternary(cond.op == 'neq', 'OR', 'AND'), self:get_column_name('vlan_id', is_write), sql_op,
                        host["vlan"])
                end
            end
        end

        -- Special case: name (with vlan)
    elseif (cond.field == 'name' or cond.field == 'cli_name' or cond.field == 'srv_name') and
        (cond.op == 'eq' or cond.op == 'neq') then
        local host = hostkey2hostinfo(cond.value)
        if not isEmptyString(host["host"]) then
            if not host["vlan"] or host["vlan"] == 0 then
                if cond.field == 'name' and self._alert_entity == alert_entities.flow then
                    sql_cond = string.format("(%s %s '%s' %s %s %s '%s')", self:get_column_name('cli_name', is_write),
                        sql_op, host["host"], ternary(cond.op == 'neq', 'AND', 'OR'),
                        self:get_column_name('srv_name', is_write), sql_op, host["host"])
                else
                    sql_cond = string.format("%s %s '%s'", real_field, sql_op, host["host"])
                end
            else
                if cond.field == 'name' and self._alert_entity == alert_entities.flow then
                    sql_cond = string.format("((%s %s '%s' %s %s %s '%s') %s %s %s %u)",
                        self:get_column_name('cli_name', is_write), sql_op, host["host"],
                        ternary(cond.op == 'neq', 'AND', 'OR'), self:get_column_name('srv_name', is_write), sql_op,
                        host["host"], ternary(cond.op == 'neq', 'OR', 'AND'), self:get_column_name('vlan_id', is_write),
                        sql_op, host["vlan"])
                else
                    sql_cond = string.format("(%s %s '%s' %s %s %s %u)", real_field, sql_op, host["host"],
                        ternary(cond.op == 'neq', 'OR', 'AND'), self:get_column_name('vlan_id', is_write), sql_op,
                        host["vlan"])
                end
            end
        end

        -- Special case: snmp_interface
    elseif cond.field == 'snmp_interface' or cond.field == 'input_snmp' or cond.field == 'output_snmp' then

        local sql_val = cond.value

        local probe_ip = nil
        local snmp_info = string.split(sql_val, "_")
        if #snmp_info == 2 then
            probe_ip = snmp_info[1]
            sql_val = snmp_info[2]
        end

        if self._alert_entity == alert_entities.snmp_device then -- snmp entity
            
            sql_cond = self:get_column_name('port', is_write) .. sql_op .. sql_val

            if probe_ip then
                sql_cond = " (" .. sql_cond .. ")" .. ternary(cond.op == 'neq', 'OR', 'AND') .. " " ..
                    self:get_column_name('ip', is_write) .. sql_op .. string.format("('%s')", probe_ip)
            end

        else -- flow or other entities
            -- Look for input or output
            if cond.field == 'snmp_interface' then
                local input_snmp = self:get_column_name('input_snmp', is_write)
                local output_snmp = self:get_column_name('output_snmp', is_write)

                sql_cond = input_snmp .. sql_op .. sql_val .. " " .. ternary(cond.op == 'neq', 'AND', 'OR') .. " " ..
                               output_snmp .. sql_op .. sql_val
            else
                local k = self:get_column_name(cond.field, is_write)
                sql_cond = k .. sql_op .. sql_val
            end

            if probe_ip then
                sql_cond = " (" .. sql_cond .. ")" .. ternary(cond.op == 'neq', 'OR', 'AND') .. " " ..
                               self:get_column_name('probe_ip', is_write) .. sql_op .. string.format("('%s')", probe_ip)
            end
        end

        sql_cond = " (" .. sql_cond .. ")"

        -- Special case: role (host)
    elseif cond.field == 'host_role' then
        if cond.value == 'attacker' then
            sql_cond = string.format("%s = 1", self:get_column_name('is_attacker', is_write))
        elseif cond.value == 'victim' then
            sql_cond = string.format("%s = 1", self:get_column_name('is_victim', is_write))
        else -- 'no_attacker_no_victim'
            sql_cond = string.format("(%s = 0 AND %s = 0)", self:get_column_name('is_attacker', is_write),
                self:get_column_name('is_victim', is_write))
        end

        -- Special case: role (flow)
    elseif cond.field == 'flow_role' then
        if cond.value == 'attacker' then
            sql_cond = string.format("(%s = 1 OR %s = 1)", self:get_column_name('is_cli_attacker', is_write),
                self:get_column_name('is_srv_attacker', is_write))
        elseif cond.value == 'victim' then
            sql_cond = string.format("(%s = 1 OR %s = 1)", self:get_column_name('is_cli_victim', is_write),
                self:get_column_name('is_srv_victim', is_write))
        else -- 'no_attacker_no_victim'
            sql_cond = string.format("(%s = 0 AND %s = 0 AND %s = 0 AND %s = 0)",
                self:get_column_name('is_cli_attacker', is_write), self:get_column_name('is_srv_attacker', is_write),
                self:get_column_name('is_cli_victim', is_write), self:get_column_name('is_srv_victim', is_write))
        end

        -- Special case: role_cli_srv)
    elseif cond.field == 'role_cli_srv' then
        if cond.value == 'client' then
            sql_cond = string.format("%s = 1", self:get_column_name('is_client', is_write))
        else -- 'server'
            sql_cond = string.format("%s = 1", self:get_column_name('is_server', is_write))
        end

        -- Special case: description
    elseif cond.field == "description" then
        sql_cond = string.format("json LIKE %s",string.format("'%%%s%%'", cond.value))
        -- Number
    elseif cond.value_type == 'number' then
        if cond.op == 'in' then
            if cond.field == 'flow_risk' then
                sql_cond = string.format("(bitTest(%s, %u) = 1)", real_field, cond.value)
            else
                sql_cond = 'bitAnd(' .. real_field .. ', ' .. cond.value .. ') = ' .. cond.value
            end
        elseif cond.op == 'nin' then
            if cond.field == 'flow_risk' then
                sql_cond = string.format("(bitTest(%s, %u) = 0)", real_field, cond.value)
            else
                sql_cond = real_field .. '!=' .. cond.value .. '/' .. cond.value
            end
        else
            sql_cond = string.format("%s %s %u", real_field, sql_op, cond.value)
        end

        -- String
    else
        if cond.op == 'in' then
            sql_cond = real_field .. ' LIKE ' .. string.format("'%%%s%%'", cond.value)
        elseif cond.op == 'nin' then
            sql_cond = real_field .. ' NOT LIKE ' .. string.format("'%%%s%%'", cond.value)
        else
            -- Any other operator
            sql_cond = string.format("%s %s ('%s')", real_field, sql_op, cond.value)
        end
    end

    return sql_cond
end

-- ##############################################

-- @brief Build where string from filters
-- @return the where condition in SQL syntax
function alert_store:build_where_clause(is_write)
    local where_clause = ""
    local and_clauses = {}
    local or_clauses = {}

    for name, groups in pairs(self._where) do
        -- Build AND clauses for all fields
        for _, cond in ipairs(groups.all) do
            local sql_cond = self:build_sql_cond(cond, is_write)

            if and_clauses[name] then
                and_clauses[name] = and_clauses[name] .. " AND " .. sql_cond
            else
                and_clauses[name] = sql_cond
            end
        end

        -- Build OR clauses for all fields
        for _, cond in ipairs(groups.any) do
            local sql_cond = self:build_sql_cond(cond, is_write)

            if or_clauses[name] then
                or_clauses[name] = or_clauses[name] .. " OR " .. sql_cond
            else
                or_clauses[name] = sql_cond
            end
        end
    end

    -- Join all groups

    -- AND groups
    for name, clause in pairs(and_clauses) do
        if isEmptyString(where_clause) then
            where_clause = "(" .. clause .. ")"
        else
            where_clause = where_clause .. " AND " .. "(" .. clause .. ")"
        end
    end

    -- OR groups
    for name, clause in pairs(or_clauses) do
        if isEmptyString(where_clause) then
            where_clause = "(" .. clause .. ")"
        else
            where_clause = where_clause .. " AND " .. "(" .. clause .. ")"
        end
    end

    if isEmptyString(where_clause) then
        where_clause = "1 = 1"
    end

    return where_clause
end

-- ##############################################

-- @brief Filter (engaged) alerts in lua) evaluating self:_where conditions
function alert_store:eval_alert_cond(alert, cond)
    -- Special case: l7proto
    if cond.field == 'l7proto' and cond.value ~= 0 then
        -- Search also in l7_master_proto, unless value is 0 (Unknown)
        local and_cond = 'neq'
        if tonumber(cond.value) == 0 --[[ Unknown --]] then
            and_cond = 'eq'
        end

        if cond.op == and_cond then
            return tag_utils.eval_op(alert['l7_proto'], cond.op, cond.value) and
                       tag_utils.eval_op(alert['l7_master_proto'], cond.op, cond.value)
        else
            return tag_utils.eval_op(alert['l7_proto'], cond.op, cond.value) or
                       tag_utils.eval_op(alert['l7_master_proto'], cond.op, cond.value)
        end

        -- Special case: ip (with vlan)
    elseif cond.field == 'ip' or cond.field == 'cli_ip' or cond.field == 'srv_ip' then
        local host = hostkey2hostinfo(cond.value)
        if not isEmptyString(host["host"]) then
            if not host["vlan"] or host["vlan"] == 0 then
                if cond.field == 'ip' and self._alert_entity == alert_entities.flow then
                    return tag_utils.eval_op(alert['cli_ip'], cond.op, host["host"]) or
                               tag_utils.eval_op(alert['srv_ip'], cond.op, host["host"])
                else
                    return tag_utils.eval_op(alert[cond.field], cond.op, host["host"])
                end
            else
                if cond.op == 'neq' then
                    if cond.field == 'ip' and self._alert_entity == alert_entities.flow then
                        return tag_utils.eval_op(alert['cli_ip'], cond.op, host["host"]) or
                                   tag_utils.eval_op(alert['srv_ip'], cond.op, host["host"]) or
                                   tag_utils.eval_op(alert['vlan_id'], cond.op, host["vlan"])
                    else
                        return tag_utils.eval_op(alert[cond.field], cond.op, host["host"]) or
                                   tag_utils.eval_op(alert['vlan_id'], cond.op, host["vlan"])
                    end
                else
                    if cond.field == 'ip' and self._alert_entity == alert_entities.flow then
                        return (tag_utils.eval_op(alert['cli_ip'], cond.op, host["host"]) or
                                   tag_utils.eval_op(alert['srv_ip'], cond.op, host["host"])) and
                                   tag_utils.eval_op(alert['vlan_id'], cond.op, host["vlan"])
                    else
                        return tag_utils.eval_op(alert[cond.field], cond.op, host["host"]) and
                                   tag_utils.eval_op(alert['vlan_id'], cond.op, host["vlan"])
                    end
                end
            end
        end

        -- Special case: hostname (with vlan)
    elseif (cond.field == 'name' or cond.field == 'cli_name' or cond.field == 'srv_name') and
        (cond.op == 'eq' or cond.op == 'neq') then
        local host = hostkey2hostinfo(cond.value)
        if not isEmptyString(host["host"]) then
            if not host["vlan"] or host["vlan"] == 0 then
                if cond.field == 'name' and self._alert_entity == alert_entities.flow then
                    return (tag_utils.eval_op(alert['cli_name'], cond.op, host["host"]) or
                               tag_utils.eval_op(alert['srv_name'], cond.op, host["host"])) and
                               tag_utils.eval_op(alert['vlan_id'], cond.op, host["vlan"])
                else
                    return tag_utils.eval_op(alert[cond.field], cond.op, host["host"]) and
                               tag_utils.eval_op(alert['vlan_id'], cond.op, host["vlan"])
                end
            else
                if cond.field == 'name' and self._alert_entity == alert_entities.flow then
                    return (tag_utils.eval_op(alert['cli_name'], cond.op, host["host"]) or
                               tag_utils.eval_op(alert['srv_name'], cond.op, host["host"])) and
                               tag_utils.eval_op(alert['vlan_id'], cond.op, host["vlan"])
                else
                    return tag_utils.eval_op(alert[cond.field], cond.op, host["host"]) and
                               tag_utils.eval_op(alert['vlan_id'], cond.op, host["vlan"])
                end
            end
        end

        -- Special case: snmp_interface
    elseif cond.field == 'snmp_interface' then
        local splitted_engaged_condition = string.split(cond.value,"_")
        if (table.len(splitted_engaged_condition) > 1) then
            -- in engaged snmp alerts case the cond.value is made by <device_ip>_<port>
            local device_ip = splitted_engaged_condition[1]
            local port = tonumber(splitted_engaged_condition[2])
            return  tag_utils.eval_op(alert['port'], cond.op, port) and 
                    tag_utils.eval_op(alert['ip'], cond.op, device_ip)
        else
            return  tag_utils.eval_op(alert['input_snmp'], cond.op, cond.value) or
                    tag_utils.eval_op(alert['output_snmp'], cond.op, cond.value)
        end

        -- Special case: role (host)
    elseif cond.field == 'host_role' then
        if cond.value == 'attacker' then
            return tag_utils.eval_op(alert['is_attacker'], cond.op, 1)
        elseif cond.value == 'victim' then
            return tag_utils.eval_op(alert['is_victim'], cond.op, 1)
        else -- 'no_attacker_no_victim'
            return tag_utils.eval_op(alert['is_attacker'], cond.op, 0) and
                       tag_utils.eval_op(alert['is_victim'], cond.op, 0)
        end

        -- Special case: role (flow)
    elseif cond.field == 'flow_role' then
        if cond.value == 'attacker' then
            return tag_utils.eval_op(alert['is_cli_attacker'], cond.op, 1) or
                       tag_utils.eval_op(alert['is_srv_attacker'], cond.op, 1)
        elseif cond.value == 'victim' then
            return tag_utils.eval_op(alert['is_cli_victim'], cond.op, 1) or
                       tag_utils.eval_op(alert['is_srv_victim'], cond.op, 1)
        else -- 'no_attacker_no_victim'
            return tag_utils.eval_op(alert['is_cli_attacker'], cond.op, 0) and
                       tag_utils.eval_op(alert['is_srv_attacker'], cond.op, 0) and
                       tag_utils.eval_op(alert['is_cli_victim'], cond.op, 0) and
                       tag_utils.eval_op(alert['is_srv_victim'], cond.op, 0)
        end

        -- Special case: role_cli_srv)
    elseif cond.field == 'role_cli_srv' then
        if cond.value == 'client' then
            return tag_utils.eval_op(alert['is_client'], cond.op, 1)
        else -- 'server'
            return tag_utils.eval_op(alert['is_server'], cond.op, 1)
        end
    end

    return tag_utils.eval_op(alert[cond.field], cond.op, cond.value)
end

-- ##############################################

-- @brief Filter (engaged) alerts in lua) evaluating self:_where conditions
function alert_store:filter_alerts(alerts)
    local result = {}

    -- For all alerts
    for _, alert in ipairs(alerts) do
        local pass = true

        -- For all fields
        for name, groups in pairs(self._where) do

            -- Eval AND conditions
            for _, cond in ipairs(groups.all) do
                if not self:eval_alert_cond(alert, cond) then
                    pass = false
                    break
                end
            end
            if not pass then
                break
            end

            -- Eval OR conditions
            if #groups.any > 0 then
                local or_pass = false
                for _, cond in ipairs(groups.any) do
                    if self:eval_alert_cond(alert, cond) then
                        or_pass = true
                        break
                    end
                end
                if not or_pass then
                    pass = false
                    break
                end
            end
        end

        if pass then
            result[#result + 1] = alert
        end
    end

    return result
end

-- ##############################################

-- @brief Add raw/sql condition to the 'where' filters
-- @param field The field name (e.g. 'alert_id')
-- @param sql_cond The raw sql condition
function alert_store:add_filter_condition_raw(field, sql_cond, any)
    local cond = {
        field = field,
        sql = sql_cond
    }

    if not self._where[field] then
        self._where[field] = {
            all = {},
            any = {}
        }
    end

    if any then
        self._where[field].any[#self._where[field].any + 1] = cond
    else
        self._where[field].all[#self._where[field].all + 1] = cond
    end
end

-- ##############################################

-- @brief Add condition to the 'where' filters
-- @param field The field name (e.g. 'alert_id')
-- @param op The operator (e.g. 'neq')
-- @param value The value
-- @param value_type The value type (e.g. 'number')
function alert_store:add_filter_condition(field, op, value, value_type)
    if not op or not tag_utils.tag_operators[op] then
        op = 'eq'
    end

    if value_type == 'number' then
        value = tonumber(value)
    end

    local cond = {
        field = field,
        op = op,
        value = value,
        value_type = value_type
    }

    if not self._where[field] then
        self._where[field] = {
            all = {},
            any = {}
        }
    end

    if op == 'neq' or field == 'score' then
        self._where[field].all[#self._where[field].all + 1] = cond
    else
        self._where[field].any[#self._where[field].any + 1] = cond
    end
end

-- ##############################################

-- @brief Handle filter operator (eq, lt, gt, gte, lte)
function alert_store:strip_filter_operator(value)
    if isEmptyString(value) then
        return nil, nil
    end
    local filter = split(value, tag_utils.SEPARATOR)
    local value = filter[1]
    local op = filter[2]
    return value, op
end

-- ##############################################

function alert_store:format_query_json_value(nested_field, type)
    local field_to_search = self:get_column_name('json', false)
    if type == "boolean" then
        return string.format('JSONExtractInt(%s, \'$.%s\')', field_to_search, nested_field)
    end
    return string.format('JSON_VALUE(%s, \'$.%s\')', field_to_search, nested_field)
end

-- ##############################################

-- @brief Add list of conditions to the 'where' filters
-- @param field The field name (e.g. 'alert_id')
-- @param values The comma-separated list of values and operators
-- @param value_type The value type (e.g. 'number')
-- @return True if set is successful, false otherwise
function alert_store:add_filter_condition_list(field, values, values_type, value_to_use)
    if not values or isEmptyString(values) then
        return false
    end

    local list = split(values, ',')

    for _, value_op in ipairs(list) do
        local value, op = self:strip_filter_operator(value_op)

        -- Value conversion for exceptions
        if field == 'l7proto' then
            if not tonumber(value) then
                -- Try converting l7 proto name to number
                value = interface.getnDPIProtoId(value)
            end
        end

        if values_type == 'number' then
            value = tonumber(value)
        end

        if value_to_use then
            value = value_to_use
        end

        if value then
            self:add_filter_condition(field, op, value, values_type)
        end
    end

    return true
end

-- ##############################################

-- @brief Pagination options to fetch partial results
-- @param limit The number of results to be returned
-- @param offset The number of records to skip before returning results
-- @return True if set is successful, false otherwise
function alert_store:add_limit(limit, offset)
    if not self._limit and tonumber(limit) then
        self._limit = limit

        if not self._offset and tonumber(offset) then
            self._offset = offset
        end

        return true
    end

    return false
end

-- ##############################################

function alert_store:set_order_by(sort_column, sort_order)
    self._order_by = {
        sort_column = sort_column,
        sort_order = sort_order
    }
end

-- ##############################################

-- @brief Specify the sort criteria of the query
-- @param sort_column The column to be used for sorting
-- @param sort_order Order, either `asc` or `desc`
-- @return True if set is successful, false otherwise
function alert_store:add_order_by(sort_column, sort_order)
    -- Caching the order by depending on the user, the page and the interface id
    if sort_order and sort_column then
        local user = "no_user"

        if (_SESSION) and (_SESSION["user"]) then
            user = _SESSION["user"]
        end

        ntop.setCache(string.format(ALERT_SORTING_ORDER, self:get_ifid(), user, _GET["page"]), sort_order)
        ntop.setCache(string.format(ALERT_SORTING_COLUMN, self:get_ifid(), user, _GET["page"]), sort_column)
    end

    -- Creating the order by if not defined and valid
    if not self._order_by and sort_column and self:_valid_fields(sort_column) and
        (sort_order == "asc" or sort_order == "desc") then
        self:set_order_by(sort_column, sort_order)        
        return true
    end

    return false
end

-- ##############################################

function alert_store:group_by(fields)
    if not self._group_by and fields and self:_valid_fields(fields) then
        self._group_by = fields
        return true
    end

    return false
end

-- ##############################################

function alert_store:insert(alert)
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "alert_store:insert")
    return false
end

-- ##############################################

-- @brief Deletes data according to specified filters
function alert_store:delete()
    local table_name = self:get_write_table_name()
    local where_clause = self:build_where_clause(true)

    -- Prepare the final query
    local q
    if ntop.isClickHouseEnabled() then
        q = string.format("ALTER TABLE `%s` DELETE WHERE %s ", table_name, where_clause)
    else
        q = string.format("DELETE FROM `%s` WHERE %s ", table_name, where_clause)
    end

    local res = interface.alert_store_query(q)
    return res and table.len(res) == 0
end

-- ##############################################

-- @brief Labels alerts according to specified filters
function alert_store:acknowledge(label)
    local table_name = self:get_write_table_name()
    local where_clause = self:build_where_clause(true)

    -- Prepare the final query
    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
            "ALTER TABLE `%s` UPDATE `alert_status` = %u, `user_label` = '%s', `user_label_tstamp` = %u WHERE %s",
            table_name, alert_consts.alert_status.acknowledged.alert_status_id, self:_escape(label), os.time(),
            where_clause)
    else
        q = string.format("UPDATE `%s` SET `alert_status` = %u, `user_label` = '%s', `user_label_tstamp` = %u WHERE %s",
            table_name, alert_consts.alert_status.acknowledged.alert_status_id, self:_escape(label), os.time(),
            where_clause)
    end

    local res = interface.alert_store_query(q)
    return res and table.len(res) == 0
end

-- ##############################################

-- NOTE parameter 'filter' is ignored
function alert_store:select_historical(filter, fields, download --[[ Available only with ClickHouse ]] )
    local table_name = self:get_table_name()
    local res = {}
    local where_clause = ''
    local group_by_clause = ''
    local order_by_clause = ''
    local limit_clause = ''
    local offset_clause = ''

    local begin_time = ntop.gettimemsec()

    -- TODO handle fields (e.g. add entity value to WHERE)

    -- Select everything by default
    fields = fields or '*'

    local select_all = false

    if fields == '*' then
        select_all = true
    else
        if not self:_valid_fields(fields) then
            return res
        end
    end

    if select_all then
        if self._alert_entity == alert_entities.flow then
            -- Compute total_bytes
            fields = fields .. ", (srv2cli_bytes + cli2srv_bytes) total_bytes"

            -- SQLite needs BLOB conversion to HEX
            if not ntop.isClickHouseEnabled() then
                fields = fields .. ", hex(alerts_map) alerts_map"
            end
        end
    end

    where_clause = self:build_where_clause()

    if ((filter ~= nil) and (string.len(filter) > 0)) then
        where_clause = where_clause .. " AND " .. filter
    end

    -- [OPTIONAL] Add the group by
    if self._group_by then
        group_by_clause = string.format("GROUP BY %s", self._group_by)
    end

    -- [OPTIONAL] Add sort criteria
    if self._order_by then
        if (self._order_by.sort_column == 'name' and ntop.isClickHouseEnabled()) then
            order_by_clause = string.format("ORDER BY %s %s COLLATE 'en'", self._order_by.sort_column, self._order_by.sort_order)
        else
            order_by_clause = string.format("ORDER BY %s %s", self._order_by.sort_column, self._order_by.sort_order)
        end
    end

    -- [OPTIONAL] Add limit for pagination
    if self._limit then
        limit_clause = string.format("LIMIT %u", self._limit)
    end

    -- [OPTIONAL] Add offset for pagination
    if self._offset then
        offset_clause = string.format("OFFSET %u", self._offset)
    end

    -- Prepare the final query
    -- NOTE: entity_id is necessary as alert_utils.formatAlertMessage assumes it to always be present inside the alert
    local q

    if ntop.isClickHouseEnabled() then
        if (isEmptyString(group_by_clause)) then
            q = string.format(
                " SELECT %u entity_id, (toUnixTimestamp(tstamp_end) - toUnixTimestamp(tstamp)) duration, toUnixTimestamp(tstamp) as tstamp_epoch, toUnixTimestamp(tstamp_end) as tstamp_end_epoch, %s FROM %s WHERE %s %s %s %s",
                self._alert_entity.entity_id, fields, table_name, where_clause, order_by_clause, limit_clause,
                offset_clause)
        else
            q = string.format(" SELECT %s FROM %s WHERE %s %s %s %s %s", fields, table_name, where_clause,
                group_by_clause, order_by_clause, limit_clause, offset_clause)
        end
    else
        if (isEmptyString(group_by_clause)) then
            q = string.format(" SELECT %u entity_id, (tstamp_end - tstamp) duration, %s FROM `%s` WHERE %s %s %s %s",
                self._alert_entity.entity_id, fields, table_name, where_clause, order_by_clause, limit_clause,
                offset_clause)
        else
            q = string.format(" SELECT %s FROM `%s` WHERE %s %s %s %s %s", fields, table_name, where_clause,
                group_by_clause, order_by_clause, limit_clause, offset_clause)
        end
    end

    if download --[[ Available only with ClickHouse ]] then
        interface.clickhouseExecCSVQuery(q)
        return ""
    end

    -- tprint(q)

    -- res = interface.alert_store_query(q, true)
    res = interface.alert_store_query(q, true, true) -- Limit results to the max set in the backend

    if ntop.isClickHouseEnabled() then
        -- convert DATETIME to epoch
        for _, record in ipairs(res or {}) do
            if record.tstamp_epoch then
                record.tstamp = record.tstamp_epoch
            elseif record.tstamp then
                record.tstamp = format_utils.parseDateTime(record.tstamp)
            end

            if record.tstamp_end_epoch then
                record.tstamp_end = record.tstamp_end_epoch
            elseif record.tstamp_end then
                record.tstamp_end = format_utils.parseDateTime(record.tstamp_end)
            end

            -- first_seen is only used in where conditions as it is indexed,
            -- using tstamp in select as it is commong to all alert tables
            -- if record.first_seen then record.first_seen = format_utils.parseDateTime(record.first_seen) end

            if record.user_label_tstamp then
                record.user_label_tstamp = format_utils.parseDateTime(record.user_label_tstamp)
            end
        end
    end

    -- count records
    local count_res = 0
    if isEmptyString(group_by_clause) then
        local count_q = string.format("SELECT COUNT(*) AS totalRows FROM `%s` WHERE %s", table_name, where_clause)
        local count_r = interface.alert_store_query(count_q)
        if table.len(count_r) > 0 then
            count_res = tonumber(count_r[1]["totalRows"])
        end
    else
        count_res = #res
    end

    local end_time = ntop.gettimemsec() -- Format: 1637330701.5767
    local duration = (end_time - begin_time) * 1000
    local records_sec = round((count_res / duration) * 1000)

    local info = {
        query = q,
        query_duration_msec = duration,
        num_records_processed = i18n("db_search.processed_records", {
            records = formatValue(count_res),
            rps = formatValue(records_sec)
        })
    }

    return res, info
end

-- ##############################################

-- @brief Selects engaged alerts from memory
-- @return Selected engaged alerts, and the total number of engaged alerts
function alert_store:select_engaged(filter, debug)
    local entity_id_filter = tonumber(self._alert_entity and self._alert_entity.entity_id) -- Possibly set in subclasses constructor
    local entity_value_filter = filter
    -- The below filters are evaluated in Lua to support all operators
    local alert_id_filter = nil
    local severity_filter = nil
    local role_filter = nil

    local alerts = interface.getEngagedAlerts(entity_id_filter, entity_value_filter, alert_id_filter, severity_filter,
        role_filter)

    alerts = self:filter_alerts(alerts)

    local total_rows = 0
    local sort_2_col = {}
    
    -- Sort and filtering
    for idx, alert in pairs(alerts) do
        local tstamp = tonumber(alert.tstamp)

        -- Engaged alerts are currently active, ignore begin epoch
        -- if self._epoch_begin and tstamp < self._epoch_begin then goto continue end

        -- Exclude alerts falling outside requested time ranges
        if self._epoch_end and tstamp > self._epoch_end then
             if debug then
                tprint("Skip alert (alert.tstamp > filter.epoch_end)")
            end
            goto continue
        end

        if self._subtype and alert.subtype ~= self._subtype then
            if debug then
                tprint("Skip alert (alert.subtype ~= filter.subtype)")
            end
            goto continue
        end

        if debug then
           tprint(alert)
        end

        if self._order_by and self._order_by.sort_column and alert[self._order_by.sort_column] ~= nil then
            sort_2_col[#sort_2_col + 1] = {
                idx = idx,
                val = tonumber(alert[self._order_by.sort_column]) or
                    string.format("%s", string.lower(alert[self._order_by.sort_column]))
            }
        else
            sort_2_col[#sort_2_col + 1] = {
                idx = idx,
                val = tstamp
            }
        end

        total_rows = total_rows + 1

        ::continue::
    end

    -- Pagination
    local offset = self._offset or 0 -- The offset, or zero (start from the beginning) if no offset is set
    local limit = self._limit or total_rows -- The limit, or the actual number of records, ie., no limit

    local res = {}
    local i = 0

    for _, val in pairsByField(sort_2_col, "val", ternary(
        self._order_by and self._order_by.sort_order and self._order_by.sort_order == "asc", asc, rev)) do
        if i >= offset + limit then
            break
        end

        if i >= offset then
            res[#res + 1] = alerts[val.idx]
        end

        i = i + 1
    end

    return res, total_rows
end

-- ##############################################

-- @brief Performs a query and counts the number of records
function alert_store:count()
    local table_name = self:get_table_name()
    local where_clause = ''

    where_clause = self:build_where_clause()

    local q

    if isEmptyString(self._group_by) then
        q = string.format("SELECT count(*) as count FROM `%s` WHERE %s", table_name, where_clause)
    else
        q = string.format("SELECT count(*) as count FROM (SELECT 1 FROM `%s` WHERE %s GROUP BY  %s) g", 
            table_name, where_clause, self._group_by)
    end

    local count_query = interface.alert_store_query(q)

    local num_results = 0
    if count_query then
        num_results = tonumber(count_query[1]["count"])
    end

    return num_results
end

-- ##############################################

-- @brief Returns minimum and maximum timestamps and the time slot width to
-- be used for queries performing group-by-time operations
function alert_store:_count_by_time_get_bounds()
    local now = os.time()
    local min_slot = self._epoch_begin or (now - 3600)
    local max_slot = self._epoch_end or now
    local slot_width

    -- Compute the width to obtain a fixed number of points
    local slot_span = max_slot - min_slot

    if slot_span < 0 or slot_span < NUM_TIME_SLOTS then
        -- Slot width is 1 second, can't be smaller than this
        slot_width = 1
    else
        -- Result is the floor to return an integer number
        slot_width = math.floor(slot_span / NUM_TIME_SLOTS)
    end

    -- Align the range using the width of the time slot to always return aligned data
    min_slot = min_slot - (min_slot % slot_width)
    max_slot = min_slot + slot_width * NUM_TIME_SLOTS

    return min_slot, max_slot, slot_width
end

-- ##############################################

-- @brief Pad missing points with zeroes and prepare the series
function alert_store:_prepare_count_by_severity_and_time_series(all_severities, min_slot, max_slot, time_slot_width)
    local res = {}

    if table.len(all_severities) == 0 then
        -- No series, add a placeholder series for "no alerts"
        local noalert_res = {}
        for slot = min_slot, max_slot + 1, time_slot_width do
            noalert_res[#noalert_res + 1] = {slot * 1000 --[[ In milliseconds --]] , 0}
        end
        res[0] = noalert_res
        return res
    end

    -- Pad missing points with zeroes
    for _, severity in pairs(alert_severities) do
        local severity_id = tonumber(severity.severity_id)

        -- Empty series for this severity, skip
        if not all_severities[severity_id] then
            goto skip_severity_pad
        end

        for slot = min_slot, max_slot + 1, time_slot_width do
            if not all_severities[severity_id].all_slots[slot] then
                all_severities[severity_id].all_slots[slot] = 0
            end
        end

        ::skip_severity_pad::
    end

    -- Prepare the result as a Lua array ordered by time slot
    for _, severity in pairs(alert_severities) do
        local severity_id = tonumber(severity.severity_id)

        -- Empty series for this severity, skip
        if not all_severities[severity_id] then
            goto skip_severity_prep
        end

        local severity_res = {}

        for slot, count in pairsByKeys(all_severities[severity_id].all_slots, asc) do
            severity_res[#severity_res + 1] = {slot * 1000 --[[ In milliseconds --]] , count}
        end

        res[severity_id] = severity_res

        ::skip_severity_prep::
    end

    return res
end

-- ##############################################

-- @brief Counts the number of engaged alerts in multiple time slots
function alert_store:count_by_severity_and_time_engaged(filter, severity)
    local min_slot, max_slot, time_slot_width = self:_count_by_time_get_bounds()
    local entity_id_filter = tonumber(self._alert_entity and self._alert_entity.entity_id) -- Possibly set in subclasses constructor
    local entity_value_filter = filter
    -- The below filters are evaluated in Lua to support all operators
    local alert_id_filter = nil
    local severity_filter = nil
    local role_filter = nil

    local alerts = interface.getEngagedAlerts(entity_id_filter, entity_value_filter, alert_id_filter, severity_filter)

    alerts = self:filter_alerts(alerts)

    local all_severities = {}
    local all_slots = {}

    -- Calculate minimum and maximum slots to make sure the response always returns consecutive time slots, possibly filled with zeroes
    for _, alert in ipairs(alerts) do
        -- Add point for the alert tstamp
        local tstamp = tonumber(alert.tstamp)
        local cur_slot = tstamp - (tstamp % time_slot_width)
        local severity_id = alert.severity

        -- Exclude alerts falling outside requested time ranges
        -- Note: do not skip alerts before the interval begin as they are engaged
        -- if self._epoch_begin and tstamp < self._epoch_begin then goto continue end
        if self._epoch_end and tstamp > self._epoch_end then
            goto continue
        end

        -- In case the alert is engaged way before the selected timeframe,
        -- without this check, all the slot from cur_slot to the current
        -- time, causing the front end to crash are going to be added.
        -- 
        -- e.g. a user is asking for the last 5 minutes but the alert was triggered 30 minutes ago,
        -- without the check all the slots from 30 minutes ago until now are going to be added.
        if (cur_slot < min_slot) then
            cur_slot = min_slot
        end

        if not all_severities[severity_id] then
            all_severities[severity_id] = {}
        end

        if not all_severities[severity_id].all_slots then
            all_severities[severity_id].all_slots = {}
        end

        all_severities[severity_id].all_slots[cur_slot] = (all_severities[severity_id].all_slots[cur_slot] or 0) + 1

        -- Add points for the whole duration of the engaged alert
        if self._epoch_end then
            while cur_slot < self._epoch_end do
                cur_slot = cur_slot + time_slot_width
                all_severities[severity_id].all_slots[cur_slot] =
                    (all_severities[severity_id].all_slots[cur_slot] or 0) + 1
            end
        end

        ::continue::
    end

    return self:_prepare_count_by_severity_and_time_series(all_severities, min_slot, max_slot, time_slot_width)
end

-- ##############################################

-- @brief Performs a query and counts the number of records in multiple time slots

-- Without duration support (use tstamp only)
function alert_store:count_by_severity_and_time_historical()
    local table_name = self:get_table_name()
    -- Preserve all the filters currently set
    local min_slot, max_slot, time_slot_width = self:_count_by_time_get_bounds()
    local where_clause = self:build_where_clause()
    local q

    -- Group by according to the timeslot, that is, the alert timestamp MODULO the slot width
    if (ntop.isClickHouseEnabled()) then
        q = string.format(
            "SELECT severity, (toUnixTimestamp(tstamp) - toUnixTimestamp(tstamp) %% %u) as slot, count(*) count FROM %s WHERE %s GROUP BY severity, slot ORDER BY severity, slot ASC",
            time_slot_width, table_name, where_clause)
    else
        q = string.format(
            "SELECT severity, (tstamp - tstamp %% %u) as slot, count(*) count FROM %s WHERE %s GROUP BY severity, slot ORDER BY severity, slot ASC",
            time_slot_width, table_name, where_clause)
    end

    local q_res = interface.alert_store_query(q) or {}

    local all_severities = {}

    -- Read points from the query
    for _, p in ipairs(q_res) do
        local severity_id = tonumber(p.severity)

        if not all_severities[severity_id] then
            all_severities[severity_id] = {}
        end
        if not all_severities[severity_id].all_slots then
            all_severities[severity_id].all_slots = {}
        end

        -- Make sure slots are within the requested bounds
        local cur_slot = tonumber(p.slot)
        local cur_count = tonumber(p.count)
        if cur_slot >= min_slot and cur_slot <= max_slot then
            all_severities[severity_id].all_slots[cur_slot] = cur_count
        end
    end

    return self:_prepare_count_by_severity_and_time_series(all_severities, min_slot, max_slot, time_slot_width)
end

-- With duration support (use tstamp and tstamp_end as interval)
--[[
function alert_store:count_by_severity_and_time_historical()
   local table_name = self:get_table_name()
   -- Preserve all the filters currently set
   local min_slot, max_slot, time_slot_width = self:_count_by_time_get_bounds()
   local where_clause = self:build_where_clause()
   local q

   -- TODO
   -- In order to make this work properly the time filter generated by add_time_filter
   -- should handle tstamp_end, however this field is not indexed, thus such a filter
   -- can lead to performance degradation.

   -- Group by according to the timeslot, that is, the alert timestamp MODULO the slot width
   if(ntop.isClickHouseEnabled()) then
      q = string.format("SELECT severity, (toUnixTimestamp(tstamp) - toUnixTimestamp(tstamp) %% %u) as slot, (toUnixTimestamp(tstamp_end) - toUnixTimestamp(tstamp_end) %% %u) as slot_end, count(*) count FROM %s WHERE %s GROUP BY severity, slot, slot_end ORDER BY severity, slot ASC",
         time_slot_width, time_slot_width, table_name, where_clause)
   else
      q = string.format("SELECT severity, (tstamp - tstamp %% %u) as slot, (tstamp_end - tstamp_end %% %u) as slot_end, count(*) count FROM %s WHERE %s GROUP BY severity, slot, slot_end ORDER BY severity, slot ASC",
         time_slot_width, time_slot_width, table_name, where_clause)
   end

   local q_res = interface.alert_store_query(q) or {}

   local all_severities = {}

   -- Read points from the query
   for _, p in ipairs(q_res) do
      local severity_id = tonumber(p.severity)

      if not all_severities[severity_id] then all_severities[severity_id] = {} end
      if not all_severities[severity_id].all_slots then all_severities[severity_id].all_slots = {} end

      -- Make sure slots are within the requested bounds
      local cur_slot = tonumber(p.slot)
      local cur_slot_end = tonumber(p.slot_end)
      local cur_count = tonumber(p.count)
      if not (cur_slot > max_slot or cur_slot_end < min_slot) then -- engaged in the selected interval
         if not cur_slot_end or cur_slot_end == 0 then -- set end to begin if not set
            cur_slot_end = cur_slot
         end
         while cur_slot <= cur_slot_end do -- for all the slots in interval
            if cur_slot >= min_slot and cur_slot <= max_slot then -- check range
               all_severities[severity_id].all_slots[cur_slot] = (all_severities[severity_id].all_slots[cur_slot] or 0) + cur_count
            end
            cur_slot = cur_slot + time_slot_width
         end

      end
   end

   return self:_prepare_count_by_severity_and_time_series(all_severities, min_slot, max_slot, time_slot_width)
end
--]]

-- ##############################################

-- @brief Performs a query and counts the number of records in multiple time slots using the old response format (CheckMK integration)
function alert_store:count_by_24h_historical()
    local table_name = self:get_table_name()
    local group_by = "hour"
    local time_slot_width = "3600"
    local where_clause = self:build_where_clause()

    -- Group by according to the timeslot, that is, the alert timestamp MODULO the slot width
    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
            "SELECT (toUnixTimestamp(tstamp) - toUnixTimestamp(tstamp) %% %u) as hour, count(*) count FROM %s WHERE %s GROUP BY hour",
            time_slot_width, table_name, where_clause)
    else
        q = string.format("SELECT (tstamp - tstamp %% %u) as hour, count(*) count FROM %s WHERE %s GROUP BY hour",
            time_slot_width, table_name, where_clause)
    end

    local q_res = interface.alert_store_query(q) or {}

    local res = alert_utils.formatOldTimeseries(q_res, self._epoch_begin, self._epoch_end)

    return res
end

-- ##############################################

-- @brief Performs a query and counts the number of records in multiple time slots using the old response format (CheckMK integration)
function alert_store:count_by_24h_engaged(filter, severity)
    local group_by = "hour"
    local time_slot_width = "3600"
    local where_clause = self:build_where_clause()
    local entity_id_filter = tonumber(self._alert_entity and self._alert_entity.entity_id) -- Possibly set in subclasses constructor
    local entity_value_filter = filter
    local alert_id_filter = nil
    local severity_filter = nil
    local role_filter = nil

    local alerts = interface.getEngagedAlerts(entity_id_filter, entity_value_filter, alert_id_filter, severity_filter)

    q_res = self:filter_alerts(alerts)

    -- Query done, now format the array
    local res = alert_utils.formatOldTimeseries(q_res, self._epoch_begin, self._epoch_end)

    return res
end

-- ##############################################

-- Old timeseries --
-- @brief Count from memory (engaged) or database (historical)
-- @return Alert counters divided into severity and time slots
function alert_store:count_by_24h()
    -- Add filters
    self:add_request_filters()
    -- Add limits and sort criteria
    self:add_request_ranges()

    if self._status == alert_consts.alert_status.engaged.alert_status_id then -- Engaged
        return self:count_by_24h_engaged() or {}
    else -- Historical
        return self:count_by_24h_historical() or {}
    end
end

-- ##############################################

-- @brief Count from memory (engaged) or database (historical)
-- @return Alert counters divided into severity and time slots
function alert_store:count_by_severity_and_time()
    -- Add filters
    self:add_request_filters()
    -- Add limits and sort criteria
    self:add_request_ranges()

    -- old queries, integration with CheckMK
    if self._status == alert_consts.alert_status.engaged.alert_status_id then -- Engaged
        return self:count_by_severity_and_time_engaged() or 0
    else -- Historical
        return self:count_by_severity_and_time_historical() or 0
    end
end

-- ##############################################

-- @brief Performs a query for the top alerts by alert count
function alert_store:top_alert_id_historical_by_count()
    local table_name = self:get_table_name()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()
    local limit = 10

    local q = string.format(
        "SELECT alert_id, sum(score), count(*) as count  FROM %s WHERE %s GROUP BY alert_id ORDER BY count DESC LIMIT %u", table_name,
        where_clause, limit)

    if not self._alert_entity then
        -- For the all view alert_entity is read from the database
        q = string.format(
            "SELECT entity_id, alert_id, sum(score), count(*) as count  FROM %s WHERE %s GROUP BY entity_id, alert_id ORDER BY count DESC LIMIT %u",
            table_name, where_clause, limit)
    end

    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Performs a query for the top alerts by severity
function alert_store:top_alert_id_historical_by_severity()
    local table_name = self:get_table_name()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()
    local limit = 10

    local q = string.format(
        "SELECT alert_id, max(severity) severity, count(*) count FROM %s WHERE %s GROUP BY alert_id ORDER BY severity DESC, count DESC LIMIT %u",
        table_name, where_clause, limit)

    if not self._alert_entity then
        -- For the all view alert_entity is read from the database
        q = string.format(
            "SELECT entity_id, alert_id, max(severity) severity, count(*) count FROM %s WHERE %s GROUP BY entity_id, alert_id ORDER BY severity DESC, count DESC LIMIT %u",
            table_name, where_clause, limit)
    end

    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Child stats
function alert_store:_get_additional_stats()
    return {}
end

-- ##############################################

-- @brief Stats used by the dashboard
function alert_store:get_stats()
    -- Add filters
    self:add_request_filters()

    -- Get child stats
    local stats = self:_get_additional_stats()

    stats.count = self:count()
    stats.top = stats.top or {}
    stats.top.alert_id = self:top_alert_id_historical_by_count()

    return stats
end

-- ##############################################

-- @brief Format top alerts returned by get_stats() for top.lua
function alert_store:format_top_alerts(stats, count)
    local top_alerts = {}

    for n, value in pairs(stats) do
        if self._top_limit > 0 and n > self._top_limit then
            break
        end

        local entity_id
        if self._alert_entity then
            entity_id = self._alert_entity.entity_id
        else
            -- all view
            entity_id = value.entity_id
        end

        local label = alert_consts.alertTypeLabel(tonumber(value.alert_id), true, entity_id)

        local alert_info = {
            key = "alert_id",
            value = tonumber(value.alert_id),
            label = shortenString(label, s_len),
            title = label
        }

        if value.count and count then
            alert_info.count = math.floor((tonumber(value.count) * 100) / count)
        end
        if value.severity then
            alert_info.severity = value.severity
            alert_info.severity_label = i18n(alert_consts.alertSeverityById(value.severity).i18n_title)
        end

        top_alerts[#top_alerts + 1] = alert_info
    end

    return top_alerts
end

-- ##############################################

-- @brief Stats used by the dashboard
function alert_store:get_top_limit()
    return self._top_limit
end

-- ##############################################

-- @brief Stats used by the dashboard
function alert_store:set_top_limit(l)
    self._top_limit = l
end

-- ##############################################
-- REST API Utility Functions
-- ##############################################

-- @brief Handle count requests (GET) from memory (engaged) or database (historical)
-- @return Alert counters divided into severity and time slots
function alert_store:count_by_severity_and_time_request()
    local res = {
        series = {},
        colors = {}
    }

    local count_data = 0
    local by_24h = toboolean(_GET["by_24h"]) or false

    if by_24h then
        return self:count_by_24h()
    else
        count_data = self:count_by_severity_and_time()
    end

    for _, severity in pairsByField(alert_severities, "severity_id", rev) do
        if (count_data[severity.severity_id] ~= nil) then
            res.series[#res.series + 1] = {
                name = i18n(severity.i18n_title),
                data = count_data[severity.severity_id]
            }
            res.colors[#res.colors + 1] = severity.color
        end
    end

    if table.len(res.series) == 0 and count_data[0] ~= nil then
        res.series[#res.series + 1] = {
            name = i18n("alerts_dashboard.no_alerts"),
            data = count_data[0]
        }
        res.colors[#res.colors + 1] = "#ccc"
    end

    return res
end

-- ##############################################

-- @brief Handle alerts select request (GET) from memory (engaged) or database (historical)
-- @param filter A filter on the entity value (no filter by default)
-- @param select_fields The fields to be returned (all by default or in any case for engaged)
-- @return Selected alerts, and the total number of alerts
function alert_store:select_request(filter, select_fields, download --[[ Available only with ClickHouse ]], debug)

    -- Add filters
    self:add_request_filters()
    local is_engaged = self._status == alert_consts.alert_status.engaged.alert_status_id
    if is_engaged then -- Engaged
        -- Add limits and sort criteria
        self:add_request_ranges()

        local alerts, total_rows = self:select_engaged(filter, debug)

        return alerts, total_rows, {}, is_engaged
    else -- Historical

        -- Handle Custom Queries (query_preset)
        local p = _GET["query_preset"] -- Example: &query_preset=contacts
        if not isEmptyString(p) and ntop.isEnterpriseL() then
            package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path 
            local db_query_presets = require "db_query_presets"

            local query_presets = db_query_presets.get_presets(
                os_utils.fixPath(dirs.installdir .. "/scripts/historical/alerts/" .. self._alert_entity.alert_store_name)
            )

            if query_presets[p] then
                local preset = query_presets[p]

                -- Select fields
                if not isEmptyString(preset.select.sql) then
                   select_fields = preset.select.sql
                end

		-- Filters
		if preset.filters and not isEmptyString(preset.filters.sql) then
		   filter = preset.filters.sql -- append to where
		end

                -- Group by fields
                if not isEmptyString(preset.groupby.sql) then
                   self:group_by(preset.groupby.sql)
                end

                -- Sort by field

                local sort_column = _GET["sort"]
                local sort_order = _GET["order"]
                self:add_order_by(sort_column, sort_order)

                -- Check if the selected sort column is valid, use the preset default otherwise
                if #preset.sortby.items > 0 then
                   if not self._order_by or 
                      not self._order_by.sort_column or
                      (not table.contains(preset.groupby.items, 
                             self._order_by.sort_column, 
                             (function(n) return n.name == self._order_by.sort_column end))
                       and not table.contains(preset.select.items, 
                             self._order_by.sort_column, 
                             (function(n) return n.func and n.name == self._order_by.sort_column end))) then
                        -- No order by column or invalid column, using default from preset
                        self:set_order_by(
                            preset.sortby.items[1].name,
                            preset.sortby.items[1].order
                        )
                   end
                end
            end
        end

        -- Count
        local total_row = self:count()

        -- Add limits and sort criteria only after the count has been done
        self:add_request_ranges()

        local res, info =
            self:select_historical(filter, select_fields, download --[[ Available only with ClickHouse ]] )

        return res, total_row, info, is_engaged
    end
end

-- ##############################################

function alert_store:get_earliest_available_epoch(status)
    local table_name = self:get_table_name()
    -- Add filters (only needed for the status, must ignore all other filters)
    self:add_status_filter(status)
    local cached_epoch_key =
        string.format(EARLIEST_AVAILABLE_EPOCH_CACHE_KEY, self:get_ifid(), table_name, self._status)
    local earliest = 0

    -- Check if epoch has already been cached
    local cached_epoch = ntop.getCache(cached_epoch_key)
    if not isEmptyString(cached_epoch) then
        -- If found in cache, return it
        return tonumber(cached_epoch)
    end

    if status == "engaged" then
        local res = self:select_engaged()
        for k, v in pairsByField(res, "tstamp", asc) do
            -- Take the first
            earliest = v["tstamp"]
            break
        end
    else -- Historical
        local q
        if ntop.isClickHouseEnabled() then
            q = string.format(
                " SELECT toUnixTimestamp(tstamp) earliest_epoch FROM `%s` WHERE interface_id = %d AND %s ORDER BY tstamp ASC LIMIT 1",
                table_name, interface.getId(), self:_build_alert_status_condition(status))
        else
            q = string.format(
                " SELECT tstamp earliest_epoch FROM `%s` WHERE interface_id = %d AND %s ORDER BY tstamp ASC LIMIT 1",
                table_name, interface.getId(), self:_build_alert_status_condition(status))
        end

        local res = interface.alert_store_query(q)
        if res and res[1] and tonumber(res[1]["earliest_epoch"]) then
            -- Cache and return the number as read from the DB
            ntop.setCache(cached_epoch_key, res[1]["earliest_epoch"], 600 --[[ Cache for 5 mins --]] )
            earliest = tonumber(res[1]["earliest_epoch"])
        end
    end

    -- Cache the value
    ntop.setCache(cached_epoch_key, string.format("%u", earliest), earliest == 0 and 60 or 600)

    return earliest
end

-- ##############################################

-- @brief Possibly overridden in subclasses to add additional filters from the request
function alert_store:_add_additional_request_filters()
end

-- ##############################################

-- @brief Add ip filter
function alert_store:add_alert_id_filter(alert_id)
    self:add_filter_condition('alert_id', 'eq', alert_id, 'number');
end

-- ##############################################

-- @brief Add filters according to what is specified inside the REST API
function alert_store:add_request_filters(is_write)
    local ifid = self:get_ifid()
    local epoch_begin = tonumber(_GET["epoch_begin"])
    local epoch_end = tonumber(_GET["epoch_end"])
    local alert_id = _GET["alert_id"] or _GET["alert_type"] --[[ compatibility ]] --
    local alert_category = _GET["alert_category"]
    local alert_severity = _GET["severity"] or _GET["alert_severity"]
    local score = _GET["score"]
    local rowid = _GET["row_id"]
    local tstamp = _GET["tstamp"]
    local status = _GET["status"]
    local info = _GET["info"]
    local description = _GET["description"]

    -- Remember the score filter (see also alert_stats.lua)
    local alert_score_cached = string.format(ALERT_SCORE_FILTER_KEY, self:get_ifid())

    if isEmptyString(score) then
        ntop.delCache(alert_score_cached)
    else
        ntop.setCache(alert_score_cached, score)
    end

    self:add_status_filter(status, is_write)
    self:add_time_filter(epoch_begin, epoch_end, is_write)

    self:add_filter_condition_list('alert_id', alert_id, 'number')
    self:add_filter_condition_list('alert_category', alert_category, 'number')
    self:add_filter_condition_list('severity', alert_severity, 'number')
    self:add_filter_condition_list('score', score, 'number')
    self:add_filter_condition_list('tstamp', tstamp, 'number')
    self:add_filter_condition_list('info', info, 'string')
    self:add_filter_condition_list('description', description)

    if (ntop.isClickHouseEnabled()) then
        -- Clickhouse db has the column 'interface_id', filter by that per interface
        if ifid ~= self:get_system_ifid() then
           self:add_filter_condition_list('interface_id', ifid, 'number')
        end
        self:add_filter_condition_list('rowid', rowid, 'string')
    else
        self:add_filter_condition_list('rowid', rowid, 'number')
    end

    self:_add_additional_request_filters()
end

-- ##############################################

-- @brief Possibly overridden in subclasses to get info about additional available filters
function alert_store:_get_additional_available_filters()
    return {}
end

-- ##############################################

-- @brief Get info about available filters
function alert_store:get_available_filters()
    local additional_filters = self:_get_additional_available_filters()

    local filters = {
        alert_id = tag_utils.defined_tags.alert_id,
        alert_category = tag_utils.defined_tags.alert_category,
        severity = tag_utils.defined_tags.severity,
        score = tag_utils.defined_tags.score,
        description = tag_utils.defined_tags.description
    }

    return table.merge(filters, additional_filters)
end

-- ##############################################

-- @brief Add offset, limit, and group by filters according to what is specified inside the REST API
function alert_store:add_request_ranges()
    local start = tonumber(_GET["start"]) --[[ The OFFSET: default no offset --]]
    local length = tonumber(_GET["length"]) --[[ The LIMIT: default no limit   --]]
    local sort_column = _GET["sort"]
    local sort_order = _GET["order"]

    if length then
        tablePreferences("rows_number", length)
    end

    self:add_limit(length, start)
    self:add_order_by(sort_column, sort_order)
end

-- ##############################################

-- define the base record names of the document, both json and csv
-- add a new record name here if you want to add a new base element
-- name: the actual record name
-- export: use only in csv export, true the record is included in the csv, false otherwise
-- in case an element is a table by default the 'value' key is exported, if you want to export multiple fields
-- add an 'element' array specifing the field names to export, for example:
-- MSG = { name = "msg", export = true, elements = {"name", "value"}}
local BASE_RNAME = {
    FAMILY = {
        name = "family",
        export = true
    },
    ROW_ID = {
        name = "row_id",
        export = false
    },
    TSTAMP = {
        name = "tstamp",
        export = true
    },
    ALERT_ID = {
        name = "alert_id",
        export = true
    },
    ALERT_CATEGORY = {
        name = "alert_category",
        export = true
    },
    SCORE = {
        name = "score",
        export = true
    },
    SEVERITY = {
        name = "severity",
        export = true
    },
    DURATION = {
        name = "duration",
        export = true
    },
    COUNT = {
        name = "count",
        export = true
    },
    SCRIPT_KEY = {
        name = "script_key",
        export = false
    },
    USER_LABEL = {
        name = "user_label",
        export = true
    }
}

-- @brief Convert an alert coming from the DB (value) to a record returned by the REST API
function alert_store:format_json_record_common(value, entity_id, no_html)
    local record = {}

    -- Note: this record is rendered by
    -- httpdocs/templates/pages/alerts/families/{host,..}/table[.js].template

    record[BASE_RNAME.FAMILY.name] = self:get_family()

    record[BASE_RNAME.ROW_ID.name] = value["rowid"]

    local score = tonumber(value["score"])
    local severity_id = map_score_to_severity(score)
    local severity = alert_consts.alertSeverityById(severity_id)

    local tstamp = tonumber(value["alert_tstamp"] or value["tstamp"])
    record[BASE_RNAME.TSTAMP.name] = {
        value = tstamp,
        label = format_utils.formatPastEpochShort(tstamp),
        highlight = severity.color
    }

    record[BASE_RNAME.ALERT_ID.name] = {
        value = value["alert_id"],
        label = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, entity_id)
    }

    local category = alert_category_utils.getCategoryById(tonumber(value["alert_category"]))
    record[BASE_RNAME.ALERT_CATEGORY.name] = {
        value = value["alert_category"],
        label = i18n(category.i18n_title),
        icon = category.icon
    }

    record[BASE_RNAME.SCORE.name] = {
        value = score,
        label = format_utils.formatValue(score),
        color = severity.color
    }

    local severity_label = ""
    if severity then
        if no_html then
          severity_label = i18n(severity.i18n_title)
        else
          severity_label =
            "<i class='" .. severity.icon .. "' style='color: " .. severity.color .. "!important' title='" ..
                i18n(severity.i18n_title) .. "'></i> "
        end
    end

    record[BASE_RNAME.SEVERITY.name] = {
        value = severity_id,
        label = severity_label,
        color = severity.color
    }

    record[BASE_RNAME.USER_LABEL.name] = value["user_label"]

    if tonumber(value["duration"]) then
        record[BASE_RNAME.DURATION.name] = tonumber(value["duration"])
    elseif tonumber(value["tstamp_end"]) and tonumber(value["tstamp"]) then
        record[BASE_RNAME.DURATION.name] = (tonumber(value["tstamp_end"]) - tonumber(value["tstamp"]))
    else
        record[BASE_RNAME.DURATION.name] = 0 -- unable to compute
    end

    record[BASE_RNAME.COUNT.name] = tonumber(value["count"]) or 1

    local alert_json = {}
    if not isEmptyString(value["json"]) then
        alert_json = json.decode(value["json"]) or {}
    end

    record[BASE_RNAME.SCRIPT_KEY.name] = alert_json["alert_generation"] and alert_json["alert_generation"]["script_key"]

    return record
end

-- Convert from table to CSV string
function alert_store:to_csv(documents)
    local csv = ""

    local rnames = self:get_rnames_to_export()

    -- column heading output
    local row = self:build_csv_row_header(rnames)
    csv = csv .. row .. '\n'

    for _, document in ipairs(documents) do
        row = self:build_csv_row(rnames, document)
        csv = csv .. row .. '\n'
    end

    return csv
end

function alert_store:get_rnames_to_export()
    local rnames = {}

    for key, value in pairs(self:get_export_base_rnames()) do
        if value.export then
            rnames[key] = value
        end
    end

    for key, value in pairs(self:get_rnames()) do
        if value.export then
            rnames[key] = value
        end
    end

    return rnames
end

-- do not override in subclasses
function alert_store:get_export_base_rnames()
    return BASE_RNAME
end

-- to add new elements in subclasses define a RNAME table in subclass and returned it overring this function
function alert_store:get_rnames()
    return {}
end

-- do not override in subclasses
function alert_store:build_csv_row_header(rnames)
    local row = ""

    for _, value in pairsByKeys(rnames) do
        if value["elements"] == nil then
            row = row .. CSV_SEPARATOR .. value.name
        else
            for _, element in ipairs(value.elements) do
                row = row .. CSV_SEPARATOR .. value.name .. "_" .. string.gsub(element, "%.", "_")
            end
        end
    end

    row = string.sub(row, 2) -- remove first separator

    return row;
end

function alert_store:build_csv_row(rnames, document)
    local row = ""

    for _, rname in pairsByKeys(rnames) do
        local doc_value = document[rname.name]
        if type(doc_value) ~= "table" then
            row = row .. self:build_csv_row_single_element(doc_value)
        else
            if rname["elements"] ~= nil then
                row = row .. self:build_csv_row_multiple_elements(doc_value, rname.elements)
            else
                row = row .. self:build_csv_row_single_element(doc_value.value)
            end
        end
    end

    row = string.sub(row, 2) -- remove first separator

    return row
end

function alert_store:build_csv_row_single_element(value)
    return CSV_SEPARATOR .. self:escape_csv(tostring(value or ""))
end

function alert_store:build_csv_row_multiple_elements(value, elements)
    local row = ""
    for _, element in ipairs(elements) do
        local splitted = string.split(element, "%.")
        if (splitted == nil) then
            row = row .. CSV_SEPARATOR .. self:escape_csv(tostring(value[element]))
        else
            if #splitted > 2 then
                row = row ..
                          self:build_csv_row_multiple_elements(value[splitted[1]], self:rebuild_sub_elements(splitted))
            else
                row = row .. CSV_SEPARATOR .. self:escape_csv(tostring(value[splitted[1]][splitted[2]]))
            end
        end
    end
    return row
end

function alert_store:rebuild_sub_elements(splitted)
    local tmp_elements = {}
    for i = 2, #splitted, 1 do
        tmp_elements[#tmp_elements + 1] = splitted[i]
    end
    return {table.concat(tmp_elements, ".")}
end

-- Used to escape "'s by to_csv
function alert_store:escape_csv(s)
    if string.find(s, '[,"|\n]') then
        s = '"' .. string.gsub(s, '"', '""') .. '"'
    end
    return s
end
-- ##############################################

-- @brief Deletes old data according to the configuration or up to a safe limit
function alert_store:housekeeping(ifid)
    local table_name = self:get_write_table_name()
    local select_table_name = self:get_table_name()
    local prefs = ntop.getPrefs()

    -- By Number of records

    local max_entity_alerts = prefs.max_entity_alerts
    local limit = math.floor(max_entity_alerts * 0.8) -- deletes 20% more alerts than the maximum number

    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
            "ALTER TABLE `%s` DELETE WHERE %s = %d AND %s <= (SELECT %s FROM `%s` WHERE %s = %u ORDER BY %s DESC LIMIT 1 OFFSET %u)",
            table_name, self:get_column_name('interface_id', true), ifid, self:get_column_name('rowid', true),
            self:get_column_name('rowid'), table_name, self:get_column_name('interface_id'), ifid,
            self:get_column_name('rowid'), limit)
    else
        q = string.format(
            "DELETE FROM `%s` WHERE rowid <= (SELECT rowid FROM `%s` ORDER BY rowid DESC LIMIT 1 OFFSET %u)",
            table_name, table_name, limit)
    end

    local deleted = interface.alert_store_query(q)

    -- By Time

    local now = os.time()
    local max_time_sec = prefs.max_num_secs_before_delete_alert
    local expiration_epoch = now - max_time_sec

    if ntop.isClickHouseEnabled() then
        q = string.format("ALTER TABLE `%s` DELETE WHERE %s = %d AND tstamp < %u", table_name,
            self:get_column_name('interface_id', true), ifid,
            self:get_column_name(self:_get_tstamp_column_name(), true), expiration_epoch)
    else
        q = string.format("DELETE FROM `%s` WHERE tstamp < %u", table_name, expiration_epoch)
    end

    deleted = interface.alert_store_query(q)
end

-- ##############################################

return alert_store
