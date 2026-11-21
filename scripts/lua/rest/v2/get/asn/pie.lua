--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("check_redis_prefs")
require("flow_utils")
local rest_utils = require("rest_utils")
local flow_data = require("flow_data")
local flow_pie = require("flow_pie")
local format_utils = require("format_utils")
local graph_utils = require("graph_utils")

local operators = flow_data.getOperators()

-- Retrieve the info from the rest
local asn = tonumber(_GET["asn"] or 0)
local ifid = _GET["ifid"] or interface.getId()
local criteria_as = _GET["criteria_as"]
local data_type = _GET["type"] or ""
local epoch_begin = nil
local epoch_end = nil
local res = {}
local filters = {}
local queries = {}

interface.select(tostring(ifid))
if tostring(interface.getId()) ~= tostring(ifid) then
	rest_utils.answer(rest_utils.consts.err.invalid_interface)
	return
end

-- Empty ASN return an error
if isEmptyString(asn) or (asn == 0) then
	rest_utils.answer(rest_utils.consts.err.invalid_args)
	return
end

-- In case historical data has been requested, add the epoch_begin and epoch_end
if data_type == "historical" and hasClickHouseSupport() then
	-- Handle the epoch only with the historical
	epoch_begin = tonumber(_GET["epoch_begin"])
	epoch_end = tonumber(_GET["epoch_end"])
end

if criteria_as == "user_traffic_breakdown" then
	queries = {
		{
			select_query = {
				{
					key = "SRC_ASN",
					rename = "customer",
					is_key = true,
					remove_if_equal_to = { "0" },
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{ key = "SUM(TOTAL_BYTES)", rename = "total_bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "DST_ASN", value = asn, operator = operators.eq }, -- DST_ASN = SEARCHED_ASN
				{ key = "customer", value = asn, operator = operators.neq }, -- SRC_ASN != SEARCHED_ASN
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			only_customers = true,
			value_ref = "total_bytes",
			section_ref = "customer",
			section_format = format_utils.formatASN,
		},
		{
			select_query = {
				{
					key = "DST_ASN",
					rename = "customer",
					is_key = true,
					remove_if_equal_to = { "0" },
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{ key = "SUM(TOTAL_BYTES)", rename = "total_bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "SRC_ASN", value = asn, operator = operators.eq }, -- DST_ASN = SEARCHED_ASN
				{ key = "customer", value = asn, operator = operators.neq }, -- SRC_ASN != SEARCHED_ASN
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			only_customers = true,
			value_ref = "total_bytes",
			section_ref = "customer",
			section_format = format_utils.formatASN,
		},
	}
end

local sections = flow_pie.generatePie(queries, 8, not isEmptyString(epoch_begin))

table.sort(sections, function(a, b)
	return a.value > b.value
end)

local js_formatter = "formatValue"
rest_utils.extended_answer(rest_utils.consts.success.ok, graph_utils.convert_pie_data(sections, true, js_formatter))
