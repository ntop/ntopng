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
local alert_severities = require "alert_severities"
local tag_utils = require "tag_utils"
local json = require "dkjson"

-- ##############################################

local all_alert_store = classes.class(alert_store)

-- ##############################################

function all_alert_store:init(args)
    local table_name = "all_alerts"

    self.super:init()

    if ntop.isClickHouseEnabled() then
        table_name = "all_alerts_view"
    end

    -- This is a VIEW, not a real table, but still available in SQL
    self._table_name = table_name
    self._alert_entity = nil -- No entity
end

-- ##############################################

function all_alert_store:insert(alert)
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Unsupported!")
end

-- ##############################################

function all_alert_store:delete()
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Unsupported!")
end

-- ##############################################

function all_alert_store:acknowledge()
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Unsupported!")
end

-- ##############################################

function all_alert_store:__add_alert_stats(alert, alerts_by_entity, alerts_by_entity_flat)
    local entity_id = alert.entity_id

    local tstamp = tonumber(alert.tstamp)

    -- Engaged alerts are currently active, ignore begin epoch
    -- if self._epoch_begin and tstamp < self._epoch_begin then return end

    -- Exclude alerts falling outside requested time ranges
    if self._epoch_end and tstamp > self._epoch_end then
        return
    end

    if not alerts_by_entity[entity_id] then
        -- Initialize grouped data with some defaults
        alerts_by_entity[entity_id] = {
            entity_id = entity_id,
            score = 0,
            count_group_notice_or_lower = 0,
            count_group_warning = 0,
            count_group_error = 0,
            count_group_critical = 0,
            count_group_emergency = 0,
            count = 0,
            tstamp = 0,
            tstamp_end = 0,
            json = '{}'
        }

        -- Preserve a reference in a table which is flattened
        alerts_by_entity_flat[#alerts_by_entity_flat + 1] = alerts_by_entity[entity_id]
    end

    alerts_by_entity[entity_id].score = alerts_by_entity[entity_id].score + alert.score
    alerts_by_entity[entity_id].count = alerts_by_entity[entity_id].count + 1
    local count_group
    if alert.severity <= alert_severities.notice.severity_id then
        count_group = "count_group_notice_or_lower"
    elseif alert.severity == alert_severities.warning.severity_id then
        count_group = "count_group_warning"
    elseif alert.severity == alert_severities.error.severity_id then
        count_group = "count_group_error"
    elseif alert.severity == alert_severities.critical.severity_id then
        count_group = "count_group_critical"
    elseif alert.severity >= alert_severities.emergency.severity_id then
        count_group = "count_group_emergency"
    end

    alerts_by_entity[entity_id][count_group] = alerts_by_entity[entity_id][count_group] + 1
end

-- ##############################################

-- @brief Selects engaged alerts from memory
-- @return Selected engaged alerts, and the total number of engaged alerts
function all_alert_store:select_engaged(filter)
    -- No filter, get all active interface alerts
    local alerts_by_entity_flat = {}
    local alerts_by_entity = {}

    local total_rows = 0
    local sort_2_col = {}

    -- Compute alert stats for this interface
    local alerts = interface.getEngagedAlerts()

    for _, alert in pairs(alerts) do
        self:__add_alert_stats(alert, alerts_by_entity, alerts_by_entity_flat)
    end

    -- Compute alert stats for system alerts
    local ifid = interface.getId()
    local sys_ifid = getSystemInterfaceId()
    if ifid ~= sys_ifid then
        interface.select(tostring(sys_ifid))
        alerts = interface.getEngagedAlerts()
        for _, alert in pairs(alerts) do
            self:__add_alert_stats(alert, alerts_by_entity, alerts_by_entity_flat)
        end
        interface.select(tostring(sys_ifid))
    end

    -- Sort and filtering
    for idx, alert in pairs(alerts_by_entity_flat) do
        if self._order_by and self._order_by.sort_column and alert[self._order_by.sort_column] then
            sort_2_col[#sort_2_col + 1] = {
                idx = idx,
                val = tonumber(alert[self._order_by.sort_column]) or alert[self._order_by.sort_column]
            }
        else
            sort_2_col[#sort_2_col + 1] = {
                idx = idx,
                val = count_group_error
            }
        end

        total_rows = total_rows + 1
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
            res[#res + 1] = alerts_by_entity_flat[val.idx]
        end

        i = i + 1
    end

    return res, total_rows
end

-- ##############################################

function all_alert_store:select_historical(filter, fields)
    local res = {}
    local where_clause = ''
    local group_by_clause = ''
    local order_by_clause = ''
    local limit_clause = ''
    local offset_clause = ''

    -- TODO handle fields (e.g. add entity value to WHERE)

    -- Select everything by defaul
    fields = fields or '*'

    if not self:_valid_fields(fields) then
        return res
    end

    where_clause = self:build_where_clause()

    -- [OPTIONAL] Add sort criteria
    if self._order_by then
        order_by_clause = string.format("ORDER BY %s %s", self._order_by.sort_column, self._order_by.sort_order)
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
    -- NOTE: there's a forceful GROUP BY using the entity id
    -- Groups are those used to group alerts in levels that are coarser than individual severities.
    -- and are defined in ntop_typedefs.h AlertLevelGroup.
    local q = string.format(" SELECT entity_id, SUM(score) score, " ..
                                "SUM(group_notice_or_lower) count_group_notice_or_lower, " ..
                                "SUM(group_warning) count_group_warning, " .. "SUM(group_error) count_group_error, " ..
                                "SUM(group_critical) count_group_critical, " ..
                                "SUM(group_emergency) count_group_emergency, " .. "COUNT(*) count, " ..
                                "0 tstamp, 0 tstamp_end, '{}' json FROM " .. "    (SELECT entity_id, score, " ..
                                "    CASE WHEN severity <= 3 THEN 1 ELSE 0 END AS group_notice_or_lower, " ..
                                "    CASE WHEN severity  = 4 THEN 1 ELSE 0 END AS group_warning, " ..
                                "    CASE WHEN severity  = 5 THEN 1 ELSE 0 END AS group_error, " ..
                                "    CASE WHEN severity  = 6 THEN 1 ELSE 0 END AS group_critical, " ..
                                "    CASE WHEN severity >= 7 THEN 1 ELSE 0 END AS group_emergency, " ..
                                "    score FROM `%s` WHERE %s) " .. "GROUP BY entity_id %s %s %s ", self._table_name,
        where_clause, order_by_clause, limit_clause, offset_clause)

    res = interface.alert_store_query(q)

    return res
end

-- ##############################################

-- @brief Performs a query for the top alerts by alert count
-- @param count_by A valid column to be used as group-by criteria along with the entity id
function all_alert_store:_get_counters(count_by)
    local res = {}
    local where_clause = ''
    local limit_clause = ''
    local offset_clause = ''

    where_clause = self:build_where_clause()

    -- [OPTIONAL] Add limit for pagination
    if self._limit then
        limit_clause = string.format("LIMIT %u", self._limit)
    end

    -- [OPTIONAL] Add offset for pagination
    if self._offset then
        offset_clause = string.format("OFFSET %u", self._offset)
    end

    -- Prepare the final query
    -- NOTE: there's a forceful GROUP BY using the entity id
    -- Groups are those used to group alerts in levels that are coarser than individual severities.
    -- and are defined in ntop_typedefs.h AlertLevelGroup.
    local q = string.format(" SELECT entity_id, %s, " .. "COUNT(*) count " .. "FROM `%s` WHERE %s " ..
                                "GROUP BY entity_id, %s ORDER BY count DESC %s %s ", count_by, self._table_name,
        where_clause, count_by, limit_clause, offset_clause)

    res = interface.alert_store_query(q)

    return res
end

-- ##############################################

-- @brief Returns alert counters by type in descending order
function all_alert_store:get_counters_by_type()
    return self:_get_counters("alert_id")
end

-- ##############################################

-- @brief Returns alert counters by severity, in descending order
function all_alert_store:get_counters_by_severity()
    return self:_get_counters("severity")
end

-- ##############################################

-- @brief Handle alerts select request (GET) from memory (engaged) or database (historical)
--       NOTE: OVERRIDES alert_store:select_request
-- @param filter A filter on the entity value (no filter by default)
-- @param select_fields The fields to be returned (all by default or in any case for engaged)
-- @return Selected alerts, and the total number of alerts
function all_alert_store:select_request(filter, select_fields)
    local is_system_interface = (interface.getId() == tonumber(getSystemInterfaceId()))

    -- Add filters
    self:add_request_filters()

    if ntop.isClickHouseEnabled() and not is_system_interface then
        -- Add the system interface (-1 = 65535) to show alerts both on the selected
        -- interface and non-interface related.
        self:add_filter_condition_list('interface_id', 65535, 'number')
    end

    -- Add limits and sort criteria
    self:add_request_ranges()

    if self._status == alert_consts.alert_status.engaged.alert_status_id then -- Engaged
        local alerts, total_rows = self:select_engaged(filter)

        return alerts, total_rows
    else -- Historical
        local res = self:select_historical(filter, select_fields) or {}
        return res, #res
    end
end

-- ##############################################

local RNAME = {
    ENTITY = {
        name = "entity",
        export = true
    },
    SCORE = {
        name = "score",
        export = true
    },
    COUNT_GROUP_NOTICE_OR_LOWER = {
        name = "count_group_notice_or_lower",
        export = true
    },
    COUNT_GROUP_WARNING = {
        name = "count_group_warning",
        export = true
    },
    COUNT_GROUP_ERROR = {
        name = "count_group_error",
        export = true
    },
    COUNT_GROUP_CRITICAL = {
        name = "count_group_critical",
        export = true
    },
    COUNT_GROUP_EMERGENCY = {
        name = "count_group_emergency",
        export = true
    }
}

function all_alert_store:get_rnames()
    return RNAME
end

-- @brief Convert an alert coming from the DB (value) to a record returned by the REST API
function all_alert_store:format_record(value, no_html)
    local href_icon = "<i class='fas fa-laptop'></i>"
    local record = self:format_json_record_common(value, alert_entities.host.entity_id, no_html)

    local url = string.format('%s/lua/alert_stats.lua?page=%s&epoch_begin=%u&epoch_end=%u&status=%s',
        ntop.getHttpPrefix(), alert_consts.alertEntityRaw(value["entity_id"]), _GET["epoch_begin"], _GET["epoch_end"],
        _GET["status"] or "historical")

    local entity = i18n(alert_consts.alertEntityById(value["entity_id"]).i18n_label)
    if no_html then
        record[RNAME.ENTITY.name] = entity
    else
        record[RNAME.ENTITY.name] = string.format('<a href="%s">%s</a>', url, entity)
    end

    local score = tonumber(value["score"])
    record[RNAME.SCORE.name] = {
        value = score,
        label = format_utils.formatValue(score)
    }

    record[RNAME.COUNT_GROUP_NOTICE_OR_LOWER.name] = {
        value = value["count_group_notice_or_lower"],
        color = alert_severities.notice.color,
        url = url .. "&severity=3" .. tag_utils.SEPARATOR .. "lte"
    }

    record[RNAME.COUNT_GROUP_WARNING.name] = {
        value = value["count_group_warning"],
        color = alert_severities.warning.color,
        url = url .. "&severity=4" .. tag_utils.SEPARATOR .. "eq"
    }

    record[RNAME.COUNT_GROUP_ERROR.name] = {
        value = value["count_group_error"],
        color = alert_severities.error.color,
        url = url .. "&severity=5" .. tag_utils.SEPARATOR .. "gte"
    }

    record[RNAME.COUNT_GROUP_CRITICAL.name] = {
        value = value["count_group_critical"],
        color = alert_severities.critical.color,
        url = url .. "&severity=6" .. tag_utils.SEPARATOR .. "gte"
    }

    record[RNAME.COUNT_GROUP_EMERGENCY.name] = {
        value = value["count_group_emergency"],
        color = alert_severities.emergency.color,
        url = url .. "&severity=8" .. tag_utils.SEPARATOR .. "gte"
    }

    return record
end

-- ##############################################

-- @brief Deletes old data according to the configuration or up to a safe limit
function all_alert_store:housekeeping(ifid)
    -- Nothing do do, nothing do delete or vacuum, this is just a view
end

-- ##############################################

return all_alert_store
