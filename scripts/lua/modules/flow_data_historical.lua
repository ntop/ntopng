--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local TABLE_NAME = "hourly_asn"
local flow_data_historical = {}

-- ###################################################

local function filterResults(query_info, results)
	local filtered_results = {}
	local where_post_query = query_info.where_post_query or {}

	if not where_post_query then
		return results
	end

	for _, result_value in pairs(results or {}) do
		for _, filter in pairs(where_post_query) do
			-- No value provided by the filter, skip the filtering
			if not filter.value then
				filtered_results[#filtered_results + 1] = result_value -- OK
            goto continue
			end
			-- Search for the info inside the select
			local param_info = nil
			for _, select_info in pairs(query_info.select_query or {}) do
				if (select_info.key == filter.key) or (select_info.rename == filter.key) then
					param_info = select_info
					break
				end
			end

			if not param_info then
				goto continue -- Skip, no select found with this parameter
			end

			if not result_value[filter.key] then
				goto continue -- Skip
			end

			local curr_value = result_value[filter.key]

			if filter.matching_funct then
				if param_info.depends_on then
					if result_value[param_info.depends_on] then
						curr_value = filter.matching_funct(result_value[param_info.depends_on], curr_value)
					else
						goto continue -- Skip
					end
				else
					curr_value = filter.matching_funct(curr_value)
				end
			end

			if not curr_value then
				goto continue -- Skip
			end

			for _, value in pairs(filter.value or {}) do
				if value == curr_value then
					filtered_results[#filtered_results + 1] = result_value -- OK
					goto continue
				end
			end

			::continue::
		end
	end

	return filtered_results
end

-- ###################################################

-- Helper used just to correctly format the Limit clause
local function buildLimitClause(query_info)
	local limit_keys = query_info.limit_query or {}
	local formatted_limit_query = "LIMIT "

	if not limit_keys or (table.len(limit_keys) == 0) then
		formatted_limit_query = ""
	end

	-- Multiple limit allowed only in Historical, just skip all except the first limit
	if not isHistorical then
		limit_keys = { limit_keys[1] }
	end

	for index, num_limit in pairs(limit_keys) do
		formatted_limit_query = string.format("%s%s", formatted_limit_query, num_limit)
		if index ~= #limit_keys then
			-- Add the separator
			formatted_limit_query = string.format("%s, ", formatted_limit_query)
		end
	end

	return formatted_limit_query
end

-- ###################################################

-- Helper used just to correctly format the order by clause
local function buildOrderByClause(query_info)
	local order_by_keys = query_info.order_by_query or {}
	local formatted_order_by_query = "ORDER BY "

	if not order_by_keys or (table.len(order_by_keys) == 0) then
		formatted_order_by_query = ""
	end

	-- Multiple order by allowed only in Historical, just skip all except the first order by
	if not isHistorical then
		order_by_keys = { order_by_keys[1] }
	end

	-- ###### ORDER BY ######
	for index, order_by_info in pairs(order_by_keys) do
		formatted_order_by_query =
			string.format("%s%s %s", formatted_order_by_query, order_by_info.key, tostring(order_by_info.value))
		if index ~= #order_by_keys then
			-- Add the separator
			formatted_order_by_query = string.format("%s, ", formatted_order_by_query)
		end
	end

	return formatted_order_by_query
end

-- ###################################################

-- Helper used just to correctly format the where clause
local function buildSelectClause(query_info)
	local select_keys = query_info.select_query
	local formatted_select_query = "SELECT "

	-- ###### SELECT ######
	for index, select_info in pairs(select_keys) do
		formatted_select_query = string.format("%s%s", formatted_select_query, select_info.key)
		if select_info.rename then
			-- Add the AS if requested
			formatted_select_query = string.format("%s AS %s", formatted_select_query, select_info.rename)
		end
		if index ~= #select_keys then
			-- Add the separator
			formatted_select_query = string.format("%s, ", formatted_select_query)
		end
	end

	return formatted_select_query
end

-- ###################################################

-- Helper used just to correctly format the group by clause
local function buildGroupByClause(query_info)
	local select_keys = query_info.select_query
	local formatted_group_by = "GROUP BY "

	-- ###### GROUP BY ######
	for index, select_keys_info in pairs(select_keys) do
		if select_keys_info.is_key then
			formatted_group_by =
				string.format("%s%s", formatted_group_by, (select_keys_info.rename or select_keys_info.key))
			-- Add the separator
			formatted_group_by = string.format("%s, ", formatted_group_by)
		end
	end

	formatted_group_by = formatted_group_by:sub(1, -3)

	return formatted_group_by
end

-- ###################################################

-- Helper used just to correctly format the where clause
local function buildWhereClause(query_info)
	local where_keys = query_info.where_query or {}
	local formatted_where_query = "WHERE "

	-- First of all add the basic filters (ifid and epoch) to the where
	if query_info.basic_filters then
		local basic_filters = query_info.basic_filters
		-- IFID
		if basic_filters.ifid then
			formatted_where_query =
				string.format("%sINTERFACE_ID=%s AND ", formatted_where_query, tostring(basic_filters.ifid))
		end
		if basic_filters.epoch_begin then
			formatted_where_query =
				string.format("%sFIRST_SEEN>=%s AND ", formatted_where_query, tostring(basic_filters.epoch_begin))
		end
		if basic_filters.epoch_end then
			formatted_where_query = string.format(
				"%sFIRST_SEEN<=%u AND LAST_SEEN<=%s AND ",
				formatted_where_query,
				tostring(basic_filters.epoch_end),
				tostring(basic_filters.epoch_end)
			)
		end
	end

	-- Now format the others where
	for index, where_info in pairs(where_keys) do
		-- It means that there is an array of keys that needs to be put in an OR condition
		if where_info.or_condition then
			formatted_where_query = formatted_where_query .. "("
			for _, info in pairs(where_info.key) do
				formatted_where_query =
					string.format("%s%s%s%s OR ", formatted_where_query, info.key, info.operator, tostring(info.value))
			end
			formatted_where_query = formatted_where_query:sub(1, -4)
			formatted_where_query = formatted_where_query .. ") AND "
		else
			formatted_where_query = string.format(
				"%s%s%s%s AND ",
				formatted_where_query,
				where_info.key,
				where_info.operator,
				tostring(where_info.value)
			)
		end
	end

	-- Remove the last "AND " string alwais added
	if not isEmptyString(formatted_where_query) and formatted_where_query:sub(-5) == " AND " then
		formatted_where_query = formatted_where_query:sub(1, -5)
	end

	return formatted_where_query
end

-- ###################################################

function flow_data_historical.retrieveFlowData(query_info)
	local results = nil
	local error_code = nil
	-- Handle the select first
	local isLive = not query_info.basic_info
		or isEmptyString(query_info.basic_info.epoch_begin)
		or isEmptyString(query_info.basic_info.epoch_end)

	-- In case no select keys are requested return empty -> error
	if not query_info.select_query then
		traceError(TRACE_ERROR, TRACE_CONSOLE, "No SELECT keys provided\n")
		return {}
	end

	local select_query = buildSelectClause(query_info)
	local group_by_query = buildGroupByClause(query_info)
	local where_query = buildWhereClause(query_info)
	local order_by_query = buildOrderByClause(query_info)
	local limit_query = buildLimitClause(query_info)

	local query = string.format(
		"%s FROM %s %s %s %s %s",
		select_query,
		TABLE_NAME,
		where_query,
		group_by_query,
		order_by_query,
		limit_query
	)

	if not isLive and hasClickHouseSupport() then
		results, error_code = interface.execSQLQuery(query)
	else
		results, error_code = interface.execInMemoryQuery(query)
	end

	results = filterResults(query_info, results)

	return results or {}
end

-- ###################################################

return flow_data_historical
