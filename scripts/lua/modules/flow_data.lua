--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_gui"

local flow_data = {}
local callback_utils = require "callback_utils"
local flow_data_preset = require "flow_data_preset"
local trace_stats = false
local separator = " | "
local flow_data_historical = nil

if ntop.isEnterpriseXL() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" ..
                       package.path
    flow_data_historical = require "flow_data_historical"
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key to pair the values,
--        using the columns, basically simulating a group by
-- @param data List, generate by formatEmptyStats
-- @return a unique key composed by the elements requested
local function formatKey(data)
    local all_key = ""
    local trace_string = "Checking new flow" -- string only used for tracing data
    -- Iterate all the requested info
    for key, value in pairs(data) do
        -- Find the info inside the preformatted empty data
        if type(value) == "string" then -- Key values are string
            all_key = string.format("%s%s%s", all_key, separator, value)
            trace_string =
                string.format("%s [%s: %s]", trace_string, key, value)
        end
    end
    if trace_stats then traceError(TRACE_NORMAL, TRACE_CONSOLE, trace_string) end

    return all_key
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param columns List, as key an id and as value a boolean, telling if the element
--                      has to be used as an id or not (e.g. bytes_sent are NOT ids)
-- @param flow List, containing all the elements
-- @param rename_field_list Array, containing a list of elements to be renamed;
--                          NOTE: if the column[1] needs to be renamed, an element with a new
--                          name needs to be in rename_field_list[1] (SAME EXACT POSITION)
-- @param check_different_list Array, containing a list of elements, the element inside column
--                             in position i, needs to be different from element inside check_different_list
--                             in position i, see line 74;
-- @param skip_flow Array, with a pair { key = key, value = value }, containing a list of values
--                  that excludes the flow from the aggregation (e.g. ASN = 0)
-- @return an array with a list of elements at 0 with are not ids, correctly compiled otherwise
local function formatEmptyStats(columns, flow, rename_field_list,
                                check_different_list, skip_flow)
    local element = {}
    local trace_string = "Creating entry for new key"
    -- Iterate all columns and create an entry for each KEY column (see scripts/lua/modules/flow_data_preset.lua)
    for position, column_info in pairs(columns) do
        local key = column_info.id
        -- Check if an other name is requested to be used
        if rename_field_list and rename_field_list[position] then
            key = rename_field_list[position]
        end
        local col_value = flow[column_info.key] or flow[column_info.id]

        -- Check if the requested element is a key and if it's present
        if (column_info.is_key) then
            -- Skip if it's not in the flow
            if (col_value) then
                local flow_element = tostring(col_value)
                element[key] = flow_element
                -- Check if there is an other field to be checked
                if (check_different_list) and (check_different_list[position]) then
                    local other_flow_element = tostring(
                                                   flow[check_different_list[position]["key"]] or
                                                       flow[check_different_list[position]["id"]])
                    if flow_element == other_flow_element then
                        element[key] = nil
                    end
                end
                -- In case the value needs to be removed,
                -- e.g. if the peer ASN are 0, they needs to be skipped.
                if (column_info.hide_if_value) and
                    (flow_element == column_info.hide_if_value) then
                    element[key] = nil
                end
                if trace_stats then
                    trace_string = string.format("%s [%s: %s]", trace_string,
                                                 key,
                                                 tostring(element[key] or ""))
                end
            end
        else
            -- Not a key, so a value, set it to 0
            element[key] = 0
        end
    end

    for _, skip_info in pairs(skip_flow or {}) do
        if (skip_info.key) and (element[skip_info.key]) and
            (tostring(element[skip_info.key]) == tostring(skip_info.value)) then
            return nil
        end
    end

    if trace_stats then traceError(TRACE_NORMAL, TRACE_CONSOLE, trace_string) end

    return element
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param columns List, as key an id and as value a boolean, telling if the element
--                      has to be used as an id or not (e.g. bytes_sent are NOT ids)
-- @param invert_direction Boolean, true if traffic directions needs to be inverted
-- @param flow List, containing all the elements
-- @param current_element List, containing the statistics previously collected, needs to be updated
-- @return an updated list of stats, contained in current_element
local function updateStats(columns, invert_direction, flow, current_element)
    -- Iterate the requested fields
    for _, column_info in pairs(columns) do
        if (not column_info.is_key) then -- Not a key, so a value to be updated (e.g. bytes)
            local flow_key_stat = column_info.key
            local id = column_info.id
            current_element[id] = (current_element[id] or 0) +
                                      tonumber(
                                          flow[flow_key_stat] or flow[id] or 0)

            if trace_stats then
                traceError(TRACE_NORMAL, TRACE_CONSOLE,
                           string.format(
                               "Increasing stats [Column Id: %s]->[%s: %u] [Tot: %u]",
                               id, flow_key_stat,
                               tonumber(flow[flow_key_stat] or flow[id] or 0),
                               current_element[id]))
            end
        end
    end

    return current_element
end

-- ###################################################

function flow_data.getStats(queries, isHistorical)
    local results = {}

    -- tprint(isHistorical)
    if isHistorical ~= nil then
        if not isHistorical then
            -- In case of sankey, the aggregation function is called by flow_sankey.lua
            interface.aggregateASNFlows()
        end
    end
    -- tprint("##########################################")

    for _, query_info in pairs(queries or {}) do
        local isHistorical = false
        if (query_info.filters and query_info.filters.last_seen) then
            isHistorical = true
        end
        local select_columns = flow_data_preset.retrieveColumns(
                                   query_info.select_query)
        local sort_columns =
            flow_data_preset.retrieveColumns(query_info.sort_by) or {}
        local where_filters = flow_data_preset.convertFilters(
                                  query_info.where_query, query_info.filters,
                                  isHistorical)
        local different_columns = flow_data_preset.retrieveColumns(
                                      query_info.different_from)

        -- Function used to, given a flow, merge all the same data togheter
        local function formatData(_, flow)
            -- Create an empty table, composed only by key values
            -- e.g. ip: 1.1.1.1
            --      asn: 2222
            --      bytes_sent: 0
            --      bytes_rcvd: 0
            local empty = formatEmptyStats(select_columns, flow,
                                           query_info.rename_key_field,
                                           different_columns,
                                           query_info.skip_flow)
            -- In case no record is created, skip the flow
            if not empty then goto skip_flow end
            -- Now given the empty table created, create a unique key, where only
            -- flows with the same exact requested data are going to have the same
            -- key
            local key = formatKey(empty)
            if not results[key] then -- Entry still not created
                results[key] = empty
                -- tprint("-------------------")
                -- tprint("Creating new entry: " .. key)
            end

            -- Now update the data (e.g. bytes_sent and bytes_rcvd)
            results[key] = updateStats(select_columns,
                                       query_info.invert_direction, flow,
                                       results[key])
            ::skip_flow::
        end

        local first_seen = query_info.filters.first_seen
        local last_seen = query_info.filters.last_seen
        local query_result = {}
        if flow_data_historical then
            query_result = flow_data_historical.retrieveFlowData(
                                    select_columns, where_filters, sort_columns,
                                    query_info.invert_direction, first_seen,
                                    last_seen, isHistorical)
        end

        for _, flow in pairs(query_result or {}) do formatData(_, flow) end
    end

    -- tprint(results)
    -- Now we have equal table for live and historical, so now format the data and run the checks
    return results
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param columns Array of stats to format
-- @return an Array of formatted elements
function flow_data.formatStats(stats_to_format)
    local formatted_stats = {}

    -- For each element, see if there is a defined formatter in
    -- scripts/lua/modules/flow_data_preset.lua:format_functions
    -- if there is, split the value in { id = id, name = formattedName }
    -- otherwise keep that as it is
    for _, values in pairs(stats_to_format) do
        local formatted_element = {}
        for key, value in pairs(values or {}) do
            -- Format the data
            local formatted_data, url_link =
                flow_data_preset.getFormattedDataAndLink(key, value, values)

            if (formatted_data ~= value) or (type(formatted_data) == "string") then
                formatted_element[key] = {
                    id = value,
                    name = formatted_data,
                    url = url_link
                }
            else
                formatted_element[key] = value
            end
        end

        if values.bytes_sent and values.bytes_rcvd then
            formatted_element.total_bytes = values.bytes_sent +
                                                values.bytes_rcvd
        end

        formatted_stats[#formatted_stats + 1] = formatted_element
    end

    return formatted_stats
end

-- ###################################################

return flow_data
