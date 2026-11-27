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

local INTERFACE_ROLE_OTHER = 0
local INTERFACE_ROLE_TRANSIT = 1
local INTERFACE_ROLE_PEERING = 2
-- See SNMPInterfaceRole in ntop_typedefs.h
local INTERFACE_ROLE_INTERNET_EXCHANGE = 4

--- Interface roles that can be used to filter the AS traffic
local INTERFACE_ROLE_VALUES = { "transit", "peering", "ix" }

--- Columns the historical AS rows can be sorted by: column id of the GUI table (as_stats.json) or
--- field of the row -> SQL column. Names: case insensitive, the ASes missing in asn_info (no name
--- in the query) last
local HISTORICAL_SORT_COLUMNS = {
    as_number = "asn", asn = "asn",
    name = "asname = '', lowerUTF8(asname)", asname = "asname = '', lowerUTF8(asname)",
    score = "score", throughput = "throughput_bps", traffic = "traffic",
}

--- Numeric fields of the historical AS rows (ClickHouse answers strings)
local HISTORICAL_NUMERIC_FIELDS = {
    "seen.first", "seen.last", "score", "traffic", "bytes.sent", "bytes.rcvd",
    "bytes_other", "bytes_transit", "bytes_peering", "bytes_ix", "throughput_bps",
}

--- Redis keys of the ASN roles, also read by C++ (see ntop_defines.h, Prefs::reloadASNConfiguration)
local CUSTOMER_ASN_KEY = "ntopng.prefs.config_customer_asn_list"
local SUB_CUSTOMER_ASN_KEY = "ntopng.prefs.config_sub_customer_asn_list"
local REMOTE_ASN_KEY = "ntopng.prefs.config_remote_asn_list"

--- ASN utilities module
local as_utils = {}

--- Lists of Admin > Network Configuration > ASN Configuration.
--- group "role": relationship of the ASN with this network.
--- group "category": kind of network of the ASN, independent of its role (e.g. a remote ASN that is a CDN).
as_utils.asn_lists = {
    { key = "customer_asn", group = "role", redis_key = CUSTOMER_ASN_KEY,
      i18n_title = "asn_configuration.customer_asn_title", i18n_description = "asn_configuration.customer_asn_description" },
    { key = "sub_customer_asn", group = "role", redis_key = SUB_CUSTOMER_ASN_KEY,
      i18n_title = "asn_configuration.sub_customer_asn_title", i18n_description = "asn_configuration.sub_customer_asn_description" },
    { key = "remote_asn", group = "role", redis_key = REMOTE_ASN_KEY,
      i18n_title = "asn_configuration.remote_asn_title", i18n_description = "asn_configuration.remote_asn_description" },
    { key = "cdn_asn", group = "category", redis_key = "ntopng.prefs.config_cdn_asn_list",
      i18n_title = "asn_configuration.cdn_asn_title", i18n_description = "asn_configuration.cdn_asn_description" },
    { key = "hosting_asn", group = "category", redis_key = "ntopng.prefs.config_hosting_asn_list",
      i18n_title = "asn_configuration.hosting_asn_title", i18n_description = "asn_configuration.hosting_asn_description" },
    { key = "transit_asn", group = "category", redis_key = "ntopng.prefs.config_transit_asn_list",
      i18n_title = "asn_configuration.transit_asn_title", i18n_description = "asn_configuration.transit_asn_description" },
    { key = "isp_asn", group = "category", redis_key = "ntopng.prefs.config_isp_asn_list",
      i18n_title = "asn_configuration.isp_asn_title", i18n_description = "asn_configuration.isp_asn_description" },
}

---
-- Parses a comma-separated string of ASN numbers into a lookup table
-- @param string The comma-separated string of ASN numbers (e.g., "1234,5678,9012")
-- @return table A table with ASN numbers as keys for O(1) lookup
local function parseASNList(string)
    local asn = {}
    local tmp = split(string, ",")
    if not isEmptyString(tmp) then
        for _, val in pairs(tmp or {}) do
            if not isEmptyString(val) then
                asn[val] = 1
            end
        end
    end
    return asn
end

---
-- Formats SQL conditions for ASN filtering in historical queries
-- Translates ASN type selections (my_as, my_customer_as, remote_as, other_as) into SQL WHERE clauses
-- 
-- @param options Table containing filtering options with selected_asn field
-- @return string SQL condition on the asn column (e.g., "asn IN (123,456)") or empty string if no conditions
local function formatHistoricalASNFilters(options)
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

    if not check_as then
        return ""
    end

    local asns = {}
    for asn, _ in pairs(check_as) do
        asns[#asns + 1] = tonumber(asn)
    end

    -- Same as the live data: no configured ASN means nothing to show, or everything for "other_as"
    if #asns == 0 then
        return ternary(invert, "", "1 = 0")
    end

    return string.format("asn %s (%s)", ternary(invert, "NOT IN", "IN"), table.concat(asns, ","))
end

---
-- Formats the WHERE clause of the historical flows: time range, interface and interface role
-- (as for live flows, a flow matches a role if either its input or output interface does)
-- @param options Table containing epoch_begin, epoch_end, ifid and interface_role
-- @return string SQL condition on the flows table
local function formatHistoricalFlowsWhere(options)
    local filter_options = as_utils.formatFilters(options)
    local interface_role_filter = ""
    if (filter_options.interfaceRole) then
        interface_role_filter = string.format(" AND (INPUT_INTERFACE_ROLE = %u OR OUTPUT_INTERFACE_ROLE = %u)",
            filter_options.interfaceRole, filter_options.interfaceRole)
    end
    return string.format("(FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u) AND INTERFACE_ID = %u %s",
        tonumber(options.epoch_begin), tonumber(options.epoch_end), tonumber(options.epoch_end), tonumber(options.ifid), interface_role_filter)
end

---
-- Keeps only the characters of the AS names and numbers (UTF-8 included) of a search: nothing that
-- needs to be escaped in the SQL
-- @param search The text typed in the search box of the table
-- @return string The text to search
function as_utils.cleanASSearch(search)
    return ((search or ""):gsub("[^%w%s%.%-_,&()/\128-\255]", ""))
end

---
-- SQL of the historical AS statistics: one row per ASN, with the bytes of each interface role.
-- A flow counts for its source and for its destination AS (once if they are the same):
-- ARRAY JOIN gets both from a single read of the table, a UNION would read it twice
-- @param options Table containing epoch_begin, epoch_end, ifid, selected_asn and interface_role
-- @return string The query
local function historicalASNStatsSQL(options)
    local asn_filters = formatHistoricalASNFilters(options)
    local where = formatHistoricalFlowsWhere(options)
    -- Same as Flow::getMainRole(): the input role if meaningful, otherwise the output one
    local interface_role = string.format(
        "if(INPUT_INTERFACE_ROLE IN (%u, %u, %u), INPUT_INTERFACE_ROLE, OUTPUT_INTERFACE_ROLE)",
        INTERFACE_ROLE_TRANSIT, INTERFACE_ROLE_PEERING, INTERFACE_ROLE_INTERNET_EXCHANGE)
    local function role_bytes(role, name)
        return string.format("sumIf(SRC2DST_BYTES + DST2SRC_BYTES, INTERFACE_ROLE = %u) AS %s", role, name)
    end

    return string.format(
        "SELECT asn, toUnixTimestamp(min(FIRST_SEEN)) AS \"seen.first\", toUnixTimestamp(max(LAST_SEEN)) AS \"seen.last\", " ..
            "sum(SCORE) AS score, sum(TOTAL_BYTES) AS traffic, " ..
            "sum(if(asn = SRC_ASN, SRC2DST_BYTES, DST2SRC_BYTES)) AS \"bytes.sent\", " ..
            "sum(if(asn = SRC_ASN, DST2SRC_BYTES, SRC2DST_BYTES)) AS \"bytes.rcvd\", %s, %s, %s, %s, " ..
            -- Average throughput (bytes/s like the live throughput_bps) while the AS was seen in the range
            "traffic / (\"seen.last\" - \"seen.first\" + 1) AS throughput_bps " ..
            "FROM (SELECT SRC_ASN, DST_ASN, %s AS INTERFACE_ROLE, TOTAL_BYTES, SRC2DST_BYTES, DST2SRC_BYTES, FIRST_SEEN, LAST_SEEN, SCORE " ..
            "FROM flows WHERE %s) ARRAY JOIN arrayDistinct([SRC_ASN, DST_ASN]) AS asn %s GROUP BY asn",
        role_bytes(INTERFACE_ROLE_OTHER, "bytes_other"), role_bytes(INTERFACE_ROLE_TRANSIT, "bytes_transit"),
        role_bytes(INTERFACE_ROLE_PEERING, "bytes_peering"), role_bytes(INTERFACE_ROLE_INTERNET_EXCHANGE, "bytes_ix"),
        interface_role, where, ternary(isEmptyString(asn_filters), "", "WHERE " .. asn_filters))
end

---
-- Converts the `interface_role` parameter coming from the GUI into the list of
-- the interface roles that have to be taken into account
-- A single role is returned as a one element list, whereas "all" (as well as an
-- empty or unknown value) returns every supported role
--
function as_utils.parseInterfaceRoles(interface_role)
    local roles = {}

    if isEmptyString(interface_role) or (interface_role == 'ix_transit_peering') then
        -- Add the traffic of all the roles
        for _, role in ipairs(INTERFACE_ROLE_VALUES) do
            roles[#roles + 1] = role
        end
        return roles
    end

    if (interface_role == "all") then
        return nil
    end

    -- A single, known role is returned as a one element list
    if not isEmptyString(interface_role) and (interface_role ~= "all") then
        for _, role in ipairs(INTERFACE_ROLE_VALUES) do
            if interface_role == role then
                return { role }
            end
        end
    end

    return roles
end

function as_utils.formatFilters(options, add_to_existing_options)
    local filters = {}
    -- Interface Role available only from enterprise M
    if ntop.isEnterpriseM and ntop.isEnterpriseM() then
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

---
-- Retrieves the customer ASN list from cache
-- @return string Comma-separated list of customer ASNs
function as_utils.getCustomerASNList()
    return ntop.getCache(CUSTOMER_ASN_KEY) or ""
end

---
-- Retrieves the sub-customer ASN list from cache
-- @return string Comma-separated list of sub-customer ASNs
function as_utils.getSubCustomerASNList()
    return ntop.getCache(SUB_CUSTOMER_ASN_KEY) or ""
end

---
-- Retrieves the remote ASN list from cache
-- @return string Comma-separated list of remote ASNs
function as_utils.getRemoteASNList()
    return ntop.getCache(REMOTE_ASN_KEY) or ""
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

local cached_asn_category = nil

---
-- Returns the category of an ASN (an ASN can be in one category only)
-- @param asn The ASN number (string or number)
-- @return string|nil The key of its category in as_utils.asn_lists (e.g. "cdn_asn"), nil if not configured
function as_utils.getASNCategory(asn)
    if not cached_asn_category then
        cached_asn_category = {}
        for _, list in ipairs(as_utils.asn_lists) do
            if list.group == "category" then
                for category_asn in pairs(parseASNList(ntop.getCache(list.redis_key) or "")) do
                    cached_asn_category[category_asn] = list.key
                end
            end
        end
    end
    return cached_asn_category[tostring(asn)]
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
    -- Before getting the data, format the paginator, to filter flows
    local filter_options = as_utils.formatFilters(options)

    -- Get live ASN statistics from interface
    local live_asn_info = interface.getLiveASNStats(filter_options) or {}

    local live_src_asn = live_asn_info["src_asn"]
    local live_dst_asn = live_asn_info["dst_asn"]
    local asn_stats = {}

    -- Process source ASN statistics
    for asn, bytes_stats in pairs(live_src_asn) do
        asn = tostring(asn)
        
        local b_transit = bytes_stats.transit_bytes or 0
        local b_peering = bytes_stats.peering_bytes or 0
        local b_ix = bytes_stats.ix_bytes or 0
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
		as_info["bytes_ix"] = b_ix
                as_info["bytes_other"] = b_total - b_transit - b_peering - b_ix
                asn_stats[asn] = as_info
            end
        else
            -- Existing ASN: aggregate statistics
            asn_stats[asn]["bytes.sent"] = asn_stats[asn]["bytes.sent"] + bytes_stats.bytes_sent
            asn_stats[asn]["bytes.rcvd"] = asn_stats[asn]["bytes.rcvd"] + bytes_stats.bytes_rcvd
            asn_stats[asn]["traffic"] = asn_stats[asn]["traffic"] + b_total
            asn_stats[asn]["bytes_transit"] = asn_stats[asn]["bytes_transit"] + b_transit
            asn_stats[asn]["bytes_peering"] = asn_stats[asn]["bytes_peering"] + b_peering
	    asn_stats[asn]["bytes_ix"] = asn_stats[asn]["bytes_ix"] + b_ix
            asn_stats[asn]["bytes_other"] = asn_stats[asn]["bytes_other"] + b_total - b_transit - b_peering - b_ix
        end
    end

    -- Process destination ASN statistics
    for asn, bytes_stats in pairs(live_dst_asn) do
        asn = tostring(asn)
        
        local b_transit = bytes_stats.transit_bytes or 0
        local b_peering = bytes_stats.peering_bytes or 0
	local b_ix      = bytes_stats.ix_bytes or 0
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
		as_info["bytes_ix"] = b_ix
                as_info["bytes_other"] = b_total - b_transit - b_peering - b_ix
                asn_stats[asn] = as_info
            end
        else
            -- Existing ASN: aggregate statistics
            asn_stats[asn]["bytes.sent"] = asn_stats[asn]["bytes.sent"] + bytes_stats.bytes_sent
            asn_stats[asn]["bytes.rcvd"] = asn_stats[asn]["bytes.rcvd"] + bytes_stats.bytes_rcvd
            asn_stats[asn]["traffic"] = asn_stats[asn]["traffic"] + b_total
            asn_stats[asn]["bytes_transit"] = asn_stats[asn]["bytes_transit"] + b_transit
            asn_stats[asn]["bytes_peering"] = asn_stats[asn]["bytes_peering"] + b_peering
	    asn_stats[asn]["bytes_ix"] = asn_stats[asn]["bytes_ix"] + b_ix
            asn_stats[asn]["bytes_other"] = asn_stats[asn]["bytes_other"] + b_total - b_transit - b_peering - b_ix
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

        -- Filter ASNs based on selection ("transit_as" has a table of its own, see retrieveTransitASLiveTraffic)
        if check_as then
            for asn, as_info in pairs(asn_stats) do
                local present = check_as[asn] ~= nil
                if present == invert then
                    asn_stats[asn] = nil
                end
            end
        end
    end

    return asn_stats
end

---
-- Retrieves a page of the historical AS statistics from ClickHouse: the rows are aggregated,
-- named (asn_info), searched, sorted and paged by the database, only the page comes back
-- @param options Table containing filtering options (epoch_begin, epoch_end, ifid, selected_asn, interface_role)
-- @param page Table { sort = column id (HISTORICAL_SORT_COLUMNS), order = "asc"|"desc", start, length
--             (no length: every row), search = text matched on the ASN number and name }
-- @return table Array of the rows of the page
-- @return number Rows matching the search (all the pages)
function as_utils.retrieveASHistoricalPage(options, page)
    if not hasClickHouseSupport() then
        return {}, 0
    end

    local sort_column = HISTORICAL_SORT_COLUMNS[page.sort] or "traffic"
    local order = ternary(page.order == "asc", "ASC", "DESC")
    local search = as_utils.cleanASSearch(page.search)
    local search_where = ""

    if not isEmptyString(search) then
        -- ASN 0 (private hosts) has no name: the label the table shows for it
        local private_hosts = string.find(string.lower(i18n("as_stats.private_hosts") or ""), string.lower(search), 1, true)

        search_where = string.format(
            "WHERE position(toString(asn), '%s') > 0 OR positionCaseInsensitiveUTF8(asname, '%s') > 0%s",
            search, search, ternary(private_hosts, " OR asn = 0", ""))
    end

    local limit = ""

    if tonumber(page.length) then
        limit = string.format(" LIMIT %u OFFSET %u", tonumber(page.length), tonumber(page.start) or 0)
    end

    local query = string.format(
        "SELECT stats.*, names.asname AS asname, count() OVER () AS total_rows FROM (%s) AS stats " ..
            "LEFT JOIN (SELECT asn, if(description != '', description, handle) AS asname FROM asn_info) AS names USING (asn) " ..
            "%s ORDER BY %s %s, asn ASC%s",
        historicalASNStatsSQL(options), search_where, sort_column, order, limit)

    local rows = interface.execSQLQuery(query) or {}
    local total = tonumber(rows[1] and rows[1]["total_rows"]) or 0

    for _, row in ipairs(rows) do
        for _, field in ipairs(HISTORICAL_NUMERIC_FIELDS) do
            row[field] = tonumber(row[field]) or 0
        end
        row["total_rows"] = nil
    end

    return rows, total
end

---
-- Retrieves top ASNs by traffic for live data
-- @param options Table containing filtering options (selected_asn)
-- @return table Array of top ASN statistics, sorted by traffic
function as_utils.getTopASLive(options)
    local counter = 0
    local asn_tops = {}

    local live_info = as_utils.retrieveASLiveTraffic(options) or {}

    -- Sort by traffic (descending) and take top N
    for _, as_info in pairsByField(live_info, 'traffic', rev) do
        counter = counter + 1
        asn_tops[#asn_tops + 1] = as_info
        if (counter >= MAXIMUM_NUMBER_OF_TOP) then
            break
        end
    end

    return asn_tops
end

---
-- Retrieves top ASNs by traffic for historical data
-- @param options Table containing filtering options (epoch_begin, epoch_end, ifid, selected_asn)
-- @return table Array of top ASN statistics, sorted by traffic
function as_utils.getTopASHistorical(options)
    local format_utils = require "format_utils"
    local asn_tops = {}

    -- The top N by traffic, sorted by ClickHouse
    local historical_info = as_utils.retrieveASHistoricalPage(options,
        { sort = "traffic", order = "desc", start = 0, length = MAXIMUM_NUMBER_OF_TOP })

    for _, as_info in ipairs(historical_info) do
        as_info["asname"] = format_utils.formatASN(as_info["asn"], true, false)
        asn_tops[#asn_tops + 1] = as_info
    end

    return asn_tops
end

---
-- Retrieves the live traffic of the transit ASNs (peer ASN of a flow endpoint other than the
-- ASN of the endpoint itself), per destination ASN
-- @param options Table containing filtering options (interface_role)
-- @return table Array of { transit_asn, dst_asn, traffic, transit_traffic } (transit_traffic: total of the transit ASN)
function as_utils.retrieveTransitASLiveTraffic(options)
    local live_asn_info = interface.getLiveASNStats(as_utils.formatFilters(options)) or {}
    local rows = {}

    for transit_asn, destinations in pairs(live_asn_info["transit_asn"] or {}) do
        local transit_traffic = 0
        for _, bytes in pairs(destinations) do
            transit_traffic = transit_traffic + bytes
        end

        for dst_asn, bytes in pairs(destinations) do
            rows[#rows + 1] = {
                transit_asn = tonumber(transit_asn),
                dst_asn = tonumber(dst_asn),
                traffic = bytes,
                transit_traffic = transit_traffic,
            }
        end
    end

    return rows
end

---
-- Retrieves the historical traffic of the transit ASNs, per destination ASN, from ClickHouse
-- (same definition of transit ASN as retrieveTransitASLiveTraffic)
-- @param options Table containing filtering options (epoch_begin, epoch_end, ifid, interface_role)
-- @return table Array of { transit_asn, dst_asn, traffic, transit_traffic }
function as_utils.retrieveTransitASHistoricalTraffic(options)
    -- A flow counts for its source and for its destination transit ASN (once if they are the same):
    -- flows without a transit ASN have an empty array and are dropped by the ARRAY JOIN
    local query = string.format(
        "SELECT transit_asn, DST_ASN AS dst_asn, sum(TOTAL_BYTES) AS traffic, " ..
            "sum(sum(TOTAL_BYTES)) OVER (PARTITION BY transit_asn) AS transit_traffic " ..
            "FROM (SELECT SRC_ASN, DST_ASN, SRC_PEER_ASN, DST_PEER_ASN, TOTAL_BYTES FROM flows WHERE %s) " ..
            "ARRAY JOIN arrayDistinct(arrayFilter(x -> x != 0, " ..
            "[if(SRC_PEER_ASN != SRC_ASN, SRC_PEER_ASN, 0), if(DST_PEER_ASN != DST_ASN, DST_PEER_ASN, 0)])) AS transit_asn " ..
            "GROUP BY transit_asn, dst_asn",
        formatHistoricalFlowsWhere(options))
    return interface.execSQLQuery(query) or {}
end

---
-- Adds the role flags and the category (ASN Configuration) of an ASN to a record
-- (read by FormatterUtils.formatAsConfigurationIcons)
-- @param record The table where the flags are added
-- @param asn The ASN number (string or number)
function as_utils.addASNConfiguration(record, asn)
    local customer_asn, sub_customer_asn, remote_asn = as_utils.getAllConfigurations()
    asn = tostring(asn)
    if customer_asn[asn] then
        record.is_customer_asn = true
    elseif sub_customer_asn[asn] then
        record.is_sub_customer_asn = true
    elseif remote_asn[asn] then
        record.is_remote_asn = true
    end
    record.asn_category = as_utils.getASNCategory(asn)
end

return as_utils
