--
-- (C) 2025 - ntop.org
--
-- ASN (Autonomous System Number) Utilities Module
-- Provides functions for managing and retrieving ASN configurations and traffic statistics
-- Supports categorization of ASNs into customer, sub-customer, and remote types
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "check_redis_prefs"

--- Maximum number of top ASNs to return in getTop functions
local MAXIMUM_NUMBER_OF_TOP = 10
local HISTORICAL_SRC_ASN = "SRC_ASN"
local HISTORICAL_DST_ASN = "DST_ASN"

local ASN_PROFILING_KEY = "ntopng.profiling.asn"

local INTERFACE_ROLE_OTHER = 0
local INTERFACE_ROLE_TRANSIT = 1
local INTERFACE_ROLE_PEERING = 2

--- ASN utilities module
local as_utils = {}

---
-- Parses a comma-separated string of ASN numbers into a lookup table
-- @param string The comma-separated string of ASN numbers (e.g., "1234,5678,9012")
-- @return table A table with ASN numbers as keys for O(1) lookup
local function parseASNList(string)
    local asn = {}
    local tmp = split(string, ",")
    for _, val in pairs(tmp or {}) do
        asn[val] = 1
    end
    return asn
end

---
-- Formats SQL conditions for ASN filtering in historical queries
-- Translates ASN type selections (my_as, my_customer_as, remote_as, other_as) into SQL WHERE clauses
-- 
-- @param options Table containing filtering options with selected_asn field
-- @return string SQL condition string (e.g., "asn=123 OR asn=456") or empty string if no conditions
local function formatHistoricalASNFilters(options, historical_field)
    local check_as = nil -- Table of ASNs to filter by
    local invert = false -- Filter direction flag:
    -- false = INCLUSIVE (asn IN (...))
    -- true  = EXCLUSIVE (asn NOT IN (...))

    -- Determine filter type based on user selection
    if options.selected_asn == "my_as" then
        -- Customer ASNs only
        check_as = as_utils.getCustomerASNs()
    elseif options.selected_asn == "my_customer_as" then
        -- Sub-customer ASNs only
        check_as = as_utils.getSubCustomerASNs()
    elseif options.selected_asn == "remote_as" then
        -- Remote ASNs only
        check_as = as_utils.getRemoteASNs()
    elseif options.selected_asn == "other_as" then
        -- All configured ASNs (customer + sub-customer + remote)
        check_as = as_utils.getAllASNs()
        invert = true -- "other_as" means NOT in configured ASNs
        -- e.g., exclude all known ASNs to show "other" traffic
    end

    -- Build SQL conditions for each ASN in the filter list
    local conditions = {}
    for asn, _ in pairs(check_as or {}) do
        conditions[#conditions + 1] = string.format("%s=%s", historical_field, tostring(asn))
    end

    -- Return concatenated conditions or empty string if no filters
    -- Note: The caller is responsible for combining this with other WHERE clauses
    local filter = (table.concat(conditions, " OR ") or "")
    if not isEmptyString(filter) and (invert == true) then
        filter = string.format("NOT (%s)", filter)
    end

    return filter
end

---
-- Aggregates raw query rows (grouped by asn, INTERFACE_ROLE) into a single entry per ASN.
-- @param historical_asn_stats Table of rows as returned by the ClickHouse query
-- @return table ASN statistics keyed by ASN number (string)

local function aggregateHistoricalASNRows(historical_asn_stats)
    local asn_stats = {}
    for _, as_info in pairs(historical_asn_stats) do
        local asn = tostring(as_info["asn"])
        local role = tonumber(as_info["INTERFACE_ROLE"])
        local b_sent = tonumber(as_info["bytes.sent"]) or 0
        local b_rcvd = tonumber(as_info["bytes.rcvd"]) or 0
        local traffic = tonumber(as_info["traffic"]) or 0
        local score = tonumber(as_info["score"]) or 0
        local t_bps = tonumber(as_info["throughput_bps"]) or 0
        local first = tonumber(as_info["seen.first"]) or 0
        local last = tonumber(as_info["seen.last"]) or 0

        if not asn_stats[asn] then            
            asn_stats[tostring(asn)] = as_info
            asn_stats[asn] = {
                asn = as_info["asn"],
                asname = as_info["asname"],
                ["bytes.sent"] = b_sent,
                ["bytes.rcvd"] = b_rcvd,
                traffic = traffic,
                score = score,
                throughput_bps = t_bps,
                ["seen.first"] = first,
                ["seen.last"] = last,
                -- Per-role breakdown (roles outside 0/1/2 contribute to totals only)
                bytes_other = 0, 
                bytes_transit = 0, 
                bytes_peering = 0,
            }
        else
            -- Subsequent row for same ASN: aggregate into the existing entry.
            local existing = asn_stats[asn]
            local prev_traffic = existing["traffic"]
            local new_traffic = prev_traffic + traffic

            -- Weighted-average throughput (weight = traffic share of each role)
            if new_traffic > 0 then
                existing["throughput_bps"] = (existing["throughput_bps"] * prev_traffic + t_bps * traffic) / new_traffic
            end

            existing["bytes.sent"] = existing["bytes.sent"] + b_sent
            existing["bytes.rcvd"] = existing["bytes.rcvd"] + b_rcvd
            existing["traffic"] = new_traffic
            existing["score"] = existing["score"] + score

            -- Keep the widest possible time window
            if first < existing["seen.first"] then 
                existing["seen.first"] = first
            end
            if last > existing["seen.last"] then 
                existing["seen.last"]  = last  
            end
        end

        -- Accumulate per-role byte counters (roles 0, 1, 2 only;
        -- other roles are already reflected in the totals above)
        local existing = asn_stats[asn]
        if role == INTERFACE_ROLE_OTHER then
            existing.bytes_other = existing.bytes_other + b_sent + b_rcvd
        elseif role == INTERFACE_ROLE_TRANSIT then
            existing.bytes_transit = existing.bytes_transit + b_sent + b_rcvd
        elseif role == INTERFACE_ROLE_PEERING then
            existing.bytes_peering = existing.bytes_peering + b_sent + b_rcvd
        end

    end
    
    return asn_stats
end

function as_utils.formatFilters(options, add_to_existing_options)
    local filters = {}
    -- Interface Role available only from enterprise M
    if ntop.isEnterpriseM() then
        local interface_role_filter = options.interface_role
        if interface_role_filter and not tonumber(interface_role_filter) then
            package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
            local snmp_utils = require "snmp_utils"
            -- Filter in string format (value), convert to id
            interface_role_filter = snmp_utils.get_snmp_interface_role_id_by_value(interface_role_filter)
            -- -1 as interface role is all roles, so no filter needs to be applied
            if interface_role_filter.id >= 0 then
                if add_to_existing_options then
                    options.interface_role = nil
                end
                filters.interfaceRole = interface_role_filter.id
            end
        end
    end
    if add_to_existing_options then
        filters = table.merge(filters, options)
    end

    return filters
end

function as_utils.getProfilingKey()
    return ASN_PROFILING_KEY
end

---
-- Retrieves the customer ASN list from cache
-- @return string Comma-separated list of customer ASNs
function as_utils.getCustomerASNList()
    return ntop.getCache("ntopng.prefs.config_customer_asn_list") or ""
end

---
-- Retrieves the sub-customer ASN list from cache
-- @return string Comma-separated list of sub-customer ASNs
function as_utils.getSubCustomerASNList()
    return ntop.getCache("ntopng.prefs.config_sub_customer_asn_list") or ""
end

---
-- Retrieves the remote ASN list from cache
-- @return string Comma-separated list of remote ASNs
function as_utils.getRemoteASNList()
    return ntop.getCache("ntopng.prefs.config_remote_asn_list") or ""
end

--- Cached customer ASN lookup table
local cached_customer_asn = nil

---
-- Gets customer ASNs as a lookup table (with caching)
-- @return table Table with customer ASN numbers as keys
function as_utils.getCustomerASNs()
    if not cached_customer_asn then
        cached_customer_asn = parseASNList(as_utils.getCustomerASNList())
    end
    return cached_customer_asn or {}
end

--- Cached sub-customer ASN lookup table
local cached_subcustomer_asn = nil

---
-- Gets sub-customer ASNs as a lookup table (with caching)
-- @return table Table with sub-customer ASN numbers as keys
function as_utils.getSubCustomerASNs()
    if not cached_subcustomer_asn then
        cached_subcustomer_asn = parseASNList(as_utils.getSubCustomerASNList())
    end
    return cached_subcustomer_asn or {}
end

--- Cached remote ASN lookup table
local cached_remote_asn = nil

---
-- Gets remote ASNs as a lookup table (with caching)
-- @return table Table with remote ASN numbers as keys
function as_utils.getRemoteASNs()
    if not cached_remote_asn then
        cached_remote_asn = parseASNList(as_utils.getRemoteASNList())
    end
    return cached_remote_asn or {}
end

---
-- Retrieves all ASN configurations (customer, sub-customer, remote)
-- @return table Customer ASN lookup table
-- @return table Sub-customer ASN lookup table
-- @return table Remote ASN lookup table
function as_utils.getAllConfigurations()
    local customer_asn = as_utils.getCustomerASNs()
    local sub_customer_asn = as_utils.getSubCustomerASNs()
    local remote_asn = as_utils.getRemoteASNs()
    return customer_asn, sub_customer_asn, remote_asn
end

--- Cached table containing all configured ASNs
local cached_all_asn = nil

---
-- Gets all configured ASNs (customer + sub-customer + remote)
-- @return table Table containing all configured ASN numbers as keys
function as_utils.getAllASNs()
    local all_asn = nil
    if not cached_all_asn then
        local customer_asn, sub_customer_asn, remote_asn = as_utils.getAllConfigurations()
        local res = {}
        -- Merge customer and sub-customer ASNs
        local costumer_sub = table.merge(customer_asn, sub_customer_asn)
        -- Merge with remote ASNs
        local all_asn = table.merge(costumer_sub, remote_asn)
        cached_all_asn = all_asn
    end

    return cached_all_asn or {}
end

---
-- Determines the configuration type of a specific ASN
-- @param asn The ASN number to check
-- @return string|nil The configuration type ("customer_asn", "sub_customer_asn", "remote_asn") or nil if not configured
function as_utils.getASNConfiguration(asn)
    local res = nil
    local customer_asn, sub_customer_asn, remote_asn = as_utils.getAllConfigurations()

    if customer_asn[asn] ~= nil then
        res = "customer_asn"
    elseif sub_customer_asn[asn] ~= nil then
        res = "sub_customer_asn"
    elseif remote_asn[asn] ~= nil then
        res = "remote_asn"
    end

    return res
end

---
-- Gets all customer and sub-customer ASNs merged into a single table
-- @return table Combined lookup table of customer and sub-customer ASNs
function as_utils.getCustomerAndSubCustomerASNs()
    local res = {}
    local sub_customer_asns = as_utils.getSubCustomerASNs()
    local my_asns = as_utils.getCustomerASNs()

    -- Merge both tables
    for k, v in pairs(sub_customer_asns) do
        res[k] = v
    end
    for k, v in pairs(my_asns) do
        res[k] = v
    end

    return res
end

---
-- Retrieves live ASN traffic statistics from the current interface
-- @param options Table containing filtering options (selected_asn)
-- @return table ASN statistics keyed by ASN number
function as_utils.retrieveASLiveTraffic(options)
    local perform_profiling = ntop.getCache(ASN_PROFILING_KEY)

    if not isEmptyString(perform_profiling) then
        perform_profiling = true
    else
        perform_profiling = false
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] Start data retrieval (Live)\n", os.time()))
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] Start request to DB (Live)\n", os.time()))
    end
    -- Before getting the data, format the paginator, to filter flows
    local filter_options = as_utils.formatFilters(options)

    -- Get live ASN statistics from interface
    local live_asn_info = interface.getLiveASNStats(filter_options) or {}

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] End request to DB (Live)\n", os.time()))
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] Start data formatting (Live)\n", os.time()))
    end

    local live_src_asn = live_asn_info["src_asn"]
    local live_dst_asn = live_asn_info["dst_asn"]
    local asn_stats = {}

    -- Process source ASN statistics
    for asn, bytes_stats in pairs(live_src_asn) do
        asn = tostring(asn)
        
        local b_transit = bytes_stats.transit_bytes or 0
        local b_peering = bytes_stats.peering_bytes or 0
        local b_total = bytes_stats.total_bytes or 0
        
        if not asn_stats[asn] then
            -- New ASN: get info and initialize
            local as_info = interface.getASInfo(tonumber(asn), true)
            if (as_info) then
                as_info["bytes.sent"] = bytes_stats.bytes_sent
                as_info["bytes.rcvd"] = bytes_stats.bytes_rcvd
                as_info["traffic"] = b_total
                as_info["bytes_transit"] = b_transit
                as_info["bytes_peering"] = b_peering
                as_info["bytes_other"] = b_total - b_transit - b_peering
                asn_stats[asn] = as_info
            end
        else
            -- Existing ASN: aggregate statistics
            asn_stats[asn]["bytes.sent"] = asn_stats[asn]["bytes.sent"] + bytes_stats.bytes_sent
            asn_stats[asn]["bytes.rcvd"] = asn_stats[asn]["bytes.rcvd"] + bytes_stats.bytes_rcvd
            asn_stats[asn]["traffic"] = asn_stats[asn]["traffic"] + b_total
            asn_stats[asn]["bytes_transit"] = asn_stats[asn]["bytes_transit"] + b_transit
            asn_stats[asn]["bytes_peering"] = asn_stats[asn]["bytes_peering"] + b_peering
            asn_stats[asn]["bytes_other"] = asn_stats[asn]["bytes_other"] + b_total - b_transit - b_peering
        end
    end

    -- Process destination ASN statistics
    for asn, bytes_stats in pairs(live_dst_asn) do
        asn = tostring(asn)
        
        local b_transit = bytes_stats.transit_bytes or 0
        local b_peering = bytes_stats.peering_bytes or 0
        local b_total   = bytes_stats.total_bytes or 0
        
        if not asn_stats[asn] then
            -- New ASN: get info and initialize
            local as_info = interface.getASInfo(tonumber(asn))
            if (as_info) then
                as_info["bytes.sent"] = bytes_stats.bytes_sent
                as_info["bytes.rcvd"] = bytes_stats.bytes_rcvd                
                as_info["traffic"] = b_total
                as_info["bytes_transit"] = b_transit
                as_info["bytes_peering"] = b_peering
                as_info["bytes_other"] = b_total - b_transit - b_peering
                asn_stats[asn] = as_info
            end
        else
            -- Existing ASN: aggregate statistics
            asn_stats[asn]["bytes.sent"] = asn_stats[asn]["bytes.sent"] + bytes_stats.bytes_sent
            asn_stats[asn]["bytes.rcvd"] = asn_stats[asn]["bytes.rcvd"] + bytes_stats.bytes_rcvd
            asn_stats[asn]["traffic"] = asn_stats[asn]["traffic"] + b_total
            asn_stats[asn]["bytes_transit"] = asn_stats[asn]["bytes_transit"] + b_transit
            asn_stats[asn]["bytes_peering"] = asn_stats[asn]["bytes_peering"] + b_peering
            asn_stats[asn]["bytes_other"] = asn_stats[asn]["bytes_other"] + b_total - b_transit - b_peering
        end
    end

    -- Apply ASN type filtering if specified
    if not isEmptyString(options.selected_asn) and (options.selected_asn ~= "all") then
        local check_as = nil
        local invert = false

        -- Determine filter type
        if options.selected_asn == "my_as" then
            check_as = as_utils.getCustomerASNs()
        elseif options.selected_asn == "my_customer_as" then
            check_as = as_utils.getSubCustomerASNs()
        elseif options.selected_asn == "remote_as" then
            check_as = as_utils.getRemoteASNs()
        elseif options.selected_asn == "other_as" then
            check_as = as_utils.getAllASNs()
            invert = true -- "other_as" means NOT in configured ASNs
        end

        -- Filter ASNs based on selection
        for asn, as_info in pairs(asn_stats) do
            local present = check_as[asn] ~= nil
            if present == invert then
                asn_stats[asn] = nil
            end
        end
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] End data formatting (Live)\n", os.time()))
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] End data retrieval (Live)\n", os.time()))
    end

    return asn_stats
end

---
-- Retrieves historical ASN traffic statistics from ClickHouse database
-- @param options Table containing filtering options (epoch_begin, epoch_end, ifid, selected_asn)
-- @return table Historical ASN statistics keyed by ASN number
function as_utils.retrieveASHistoricalTraffic(options)
    -- Check if ClickHouse support is available
    if not hasClickHouseSupport() then
        return {}
    end
    local perform_profiling = ntop.getCache(ASN_PROFILING_KEY)

    if not isEmptyString(perform_profiling) then
        perform_profiling = true
    else
        perform_profiling = false
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] Start data retrieval (Historical)\n", os.time()))
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] Start request to DB (Historical)\n", os.time()))
    end

    -- Before getting the data, format the paginator, to filter flows
    local filter_options = as_utils.formatFilters(options)
    local interface_role_filter = ""
    if (filter_options.interfaceRole) then
        interface_role_filter = string.format(" AND INTERFACE_ROLE = %u", filter_options.interfaceRole)
    end
    -- Built two different where for efficiency reasons, filtering inside the UNION
    -- is a lot faster the filtering outside even if the code readability is a bit less
    local src_asn_filters = formatHistoricalASNFilters(options, HISTORICAL_SRC_ASN)
    local dst_asn_filters = formatHistoricalASNFilters(options, HISTORICAL_DST_ASN)
    -- Build WHERE clause for time range and interface
    local where = string.format("(FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u) AND INTERFACE_ID = %u %s",
        tonumber(options.epoch_begin), tonumber(options.epoch_end), tonumber(options.epoch_end), tonumber(options.ifid), interface_role_filter)

    -- Complex SQL query to aggregate ASN statistics from flows table
    -- Combines both source and destination ASNs
    local query = string.format(
        "SELECT asn, INTERFACE_ROLE, min(FIRST_SEEN) as \"seen.first\", max(LAST_SEEN) as \"seen.last\", sum(SCORE) as score, sum(total_bytes) AS traffic, sum(bytes_sent) as \"bytes.sent\", sum(bytes_rcvd) as \"bytes.rcvd\", sum(total_bytes) / sum(dateDiff('second', FIRST_SEEN, LAST_SEEN) + 1) AS throughput_bps " ..
            "FROM (SELECT SRC_ASN AS asn, INTERFACE_ROLE, FLOW_ID, TOTAL_BYTES as total_bytes, SRC2DST_BYTES as bytes_sent, DST2SRC_BYTES as bytes_rcvd, FIRST_SEEN, LAST_SEEN, INTERFACE_ID, SCORE FROM flows WHERE %s %s UNION ALL " ..
            "SELECT DST_ASN AS asn, INTERFACE_ROLE, FLOW_ID, TOTAL_BYTES as total_bytes, DST2SRC_BYTES as bytes_sent, SRC2DST_BYTES as bytes_rcvd, FIRST_SEEN, LAST_SEEN, INTERFACE_ID, SCORE FROM flows WHERE %s %s AND DST_ASN != SRC_ASN " ..
            ") GROUP BY asn, INTERFACE_ROLE", where, ternary(isEmptyString(src_asn_filters), "", " AND " .. src_asn_filters), where,
        ternary(isEmptyString(dst_asn_filters), "", " AND " .. dst_asn_filters))

    local historical_asn_stats,err = interface.execSQLQuery(query)
    historical_asn_stats = historical_asn_stats or {}
    
    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] End request to DB (Historical)\n", os.time()))
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] Start data formatting (Historical)\n", os.time()))
    end

    -- Process historical data.
    -- The query groups by (asn, INTERFACE_ROLE), so the same ASN can appear in multiple
    -- rows. We aggregate all rows into a single entry per ASN, and additionally track
    -- bytes for the three roles of interest (other/transit/peering).
    local asn_stats = aggregateHistoricalASNRows(historical_asn_stats)
    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] End data formatting (Historical)\n", os.time()))
    end

    -- For recent time periods, merge live data with historical data
    -- This ensures complete statistics for the requested time range

    -- Merge live and historical data
    --[[ For now do not unify live and historical data
    local live_info = as_utils.retrieveASLiveTraffic(options) or {}
    for asn, as_info in pairs(live_info) do
        if not asn_stats[asn] then
            -- New ASN: add live data
            asn_stats[asn] = as_info
        else
            -- Existing ASN: aggregate statistics
            asn_stats[asn]["bytes.sent"] = asn_stats[asn]["bytes.sent"] + as_info["bytes.sent"]
            asn_stats[asn]["bytes.rcvd"] = asn_stats[asn]["bytes.rcvd"] + as_info["bytes.rcvd"]
            asn_stats[asn]["traffic"] = asn_stats[asn]["traffic"] + as_info["traffic"]
            asn_stats[asn]["score"] = asn_stats[asn]["score"] + as_info["score"]
            
            -- Calculate weighted average for throughput
            local time_diff = asn_stats[asn]["seen.last"] - asn_stats[asn]["seen.first"]
            asn_stats[asn]["throughput_bps"] = ((asn_stats[asn]["throughput_bps"] * time_diff) +
                                                   as_info["throughput_bps"]) / (time_diff + 1)

            -- Update first seen timestamp if necessary
            if tonumber(asn_stats[asn]["seen.first"]) < as_info["seen.first"] then
                asn_stats[asn]["seen.first"] = as_info["seen.first"]
            end
        end
    end]]

    return asn_stats
end

---
-- Retrieves top ASNs by traffic for live data
-- @param options Table containing filtering options (selected_asn)
-- @return table Array of top ASN statistics, sorted by traffic
function as_utils.getTopASLive(options)
    local counter = 0
    local asn_tops = {}
    local perform_profiling = ntop.getCache(ASN_PROFILING_KEY)

    if not isEmptyString(perform_profiling) then
        perform_profiling = true
    else
        perform_profiling = false
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] Start Top ASN (Live)\n", os.time()))
    end

    local live_info = as_utils.retrieveASLiveTraffic(options) or {}

    -- Sort by traffic (descending) and take top N
    for _, as_info in pairsByField(live_info, 'traffic', rev) do
        counter = counter + 1
        asn_tops[#asn_tops + 1] = as_info
        if (counter >= MAXIMUM_NUMBER_OF_TOP) then
            break
        end
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] End Top ASN (Live)\n", os.time()))
    end

    return asn_tops
end

---
-- Retrieves top ASNs by traffic for historical data
-- @param options Table containing filtering options (epoch_begin, epoch_end, ifid, selected_asn)
-- @return table Array of top ASN statistics, sorted by traffic
function as_utils.getTopASHistorical(options)
    local counter = 0
    local asn_tops = {}
    local perform_profiling = ntop.getCache(ASN_PROFILING_KEY)

    if not isEmptyString(perform_profiling) then
        perform_profiling = true
    else
        perform_profiling = false
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] Start Top ASN (Historical)\n", os.time()))
    end
    local historical_info = as_utils.retrieveASHistoricalTraffic(options) or {}

    -- Sort by traffic (descending) and take top N
    for _, as_info in pairsByField(historical_info, 'traffic', rev) do
        counter = counter + 1
        asn_tops[#asn_tops + 1] = as_info
        if (counter >= MAXIMUM_NUMBER_OF_TOP) then
            break
        end
    end

    if (perform_profiling) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("[ASN Profiling][Time: %s] End Top ASN (Historical)\n", os.time()))
    end

    return asn_tops
end

return as_utils
