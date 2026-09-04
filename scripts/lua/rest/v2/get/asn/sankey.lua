--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local snmp_utils
if ntop.isEnterpriseL and ntop.isEnterpriseL() then
	package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
	snmp_utils = require("snmp_utils")
end

require("ntop_utils")
require("check_redis_prefs")
require("flow_utils")
local rest_utils = require("rest_utils")
local flow_sankey = require("flow_sankey")
local format_utils = require("format_utils")
local as_utils = require("as_utils")

local snmp_utils
local matching_function = nil
local interface_role = nil
if ntop.isEnterpriseM and ntop.isEnterpriseM() then
	package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
	snmp_utils = require("snmp_utils")
	matching_function = snmp_utils.get_snmp_interface_role_value
	-- Otherwise it will return empty data
	interface_role = as_utils.parseInterfaceRoles(_GET["interface_role"])
end

local operators = flow_sankey.getOperators()

-- Retrieve the info from the rest
local asn = tonumber(_GET["asn"] or 0)
local ifid = _GET["ifid"] or interface.getId()
local criteria_as = _GET["criteria_as"]
-- Roles of the exporter interfaces to take into account, sent by the
-- ingress/egress criteria only, e.g. { "transit" } or { "transit", "peering", "ix" }
local data_type = _GET["type"] or ""
local epoch_begin = nil
local epoch_end = nil
local res = {}
local filters = {}
local queries = {}

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

if criteria_as == "ingress_egress_traffic_criteria" then
	local probe_key = "PROBE_IP"
	queries = {
		{
			select_query = {
            {
					key = "SRC_ASN",
					rename = "src_asn",
					is_key = true,
					formatter = format_utils.formatASN,
					linker = generateASNLink,
            },
				{
					key = "INPUT_SNMP",
					rename = "in_iface_index",
					is_key = true,
					formatter = format_portidx_name_with_role,
					depends_on = "device_in",
					linker = generateExporterInterfaceLink,
				},
				{
					key = probe_key,
					rename = "device_in",
					is_key = true,
					formatter = getExporterName,
					linker = generateExporterLink,
				},
				{ key = "SUM(SRC2DST_BYTES)", rename = "bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "DST_ASN", value = asn, operator = operators.eq }, -- DST_ASN = SEARCHED_ASN
				{ key = "SRC2DST_BYTES", value = "0", operator = operators.gt },
			},
			where_post_query = {
				{ key = "in_iface_index", value = interface_role, matching_funct = matching_function },
			},
			order_by_query = {
				{ key = "bytes", value = "DESC" },
			},
			limit_query = {
				1000,
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			root = {
				formatter = format_utils.formatASN,
				id = asn,
				add_root_last = true,
			},
		},
		{
			select_query = {
            {
					key = "DST_ASN",
					rename = "src_asn",
					is_key = true,
					formatter = format_utils.formatASN,
					linker = generateASNLink,
            },
				{
					key = "INPUT_SNMP",
					rename = "in_iface_index",
					is_key = true,
					formatter = format_portidx_name_with_role,
					depends_on = "device_in",
					linker = generateExporterInterfaceLink,
				},
				{
					key = probe_key,
					rename = "device_in",
					is_key = true,
					formatter = getExporterName,
					linker = generateExporterLink,
				},
				{ key = "SUM(DST2SRC_BYTES)", rename = "bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "SRC_ASN", value = asn, operator = operators.eq }, -- DST_ASN = SEARCHED_ASN
				{ key = "DST2SRC_BYTES", value = "0", operator = operators.gt },
			},
			where_post_query = {
				{ key = "in_iface_index", value = interface_role, matching_funct = matching_function },
			},
			order_by_query = {
				{ key = "bytes", value = "DESC" },
			},
			limit_query = {
				1000,
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			root = {
				formatter = format_utils.formatASN,
				id = asn,
				add_root_last = true,
			},
		},
		{
			select_query = {
				{
					key = probe_key,
					rename = "device_out",
					is_key = true,
					formatter = getExporterName,
					linker = generateExporterLink,
				},
				{
					key = "OUTPUT_SNMP",
					rename = "out_iface_index",
					is_key = true,
					formatter = format_portidx_name_with_role,
					depends_on = "device_out",
					linker = generateExporterInterfaceLink,
				},
            {
					key = "DST_ASN",
					rename = "dst_asn",
					is_key = true,
					formatter = format_utils.formatASN,
					linker = generateASNLink,
            },
				{ key = "SUM(SRC2DST_BYTES)", rename = "bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "SRC_ASN", value = asn, operator = operators.eq }, -- SRC_ASN != 0
				{ key = "SRC2DST_BYTES", value = "0", operator = operators.gt },
			},
			where_post_query = {
				{ key = "out_iface_index", value = interface_role, matching_funct = matching_function },
			},
			order_by_query = {
				{ key = "bytes", value = "DESC" },
			},
			limit_query = {
				1000,
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			root = {
				formatter = format_utils.formatASN,
				id = asn,
				add_root_first = true,
			},
		},
		{
			select_query = {
				{
					key = probe_key,
					rename = "device_out",
					is_key = true,
					formatter = getExporterName,
					linker = generateExporterLink,
				},
				{
					key = "OUTPUT_SNMP",
					rename = "out_iface_index",
					is_key = true,
					formatter = format_portidx_name_with_role,
					depends_on = "device_out",
					linker = generateExporterInterfaceLink,
				},
            {
					key = "SRC_ASN",
					rename = "dst_asn",
					is_key = true,
					formatter = format_utils.formatASN,
					linker = generateASNLink,
            },
				{ key = "SUM(DST2SRC_BYTES)", rename = "bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "DST_ASN", value = asn, operator = operators.eq }, -- SRC_ASN != 0
				{ key = "DST2SRC_BYTES", value = "0", operator = operators.gt },
			},
			where_post_query = {
				{ key = "out_iface_index", value = interface_role, matching_funct = matching_function },
			},
			order_by_query = {
				{ key = "bytes", value = "DESC" },
			},
			limit_query = {
				1000,
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			root = {
				formatter = format_utils.formatASN,
				id = asn,
				add_root_first = true,
			},
		},
	}
elseif isEmptyString(criteria_as) or (criteria_as == "traffic_between_ases") then
	queries = {
		{
			select_query = {
				{
					key = "SRC_ASN",
					rename = "src_asn",
					is_key = true,
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{
					key = "SRC_PEER_ASN",
					rename = "src_peer_asn",
					is_key = true,
					remove_if_equal_to = { "src_asn", "0" },
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{ key = "SUM(SRC2DST_BYTES)", rename = "bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "src_asn", value = "0", operator = operators.neq }, -- SRC_ASN != 0
				{ key = "DST_ASN", value = asn, operator = operators.eq }, -- DST_ASN = SEARCHED_ASN
				{ key = "SRC2DST_BYTES", value = "0", operator = operators.gt },
			},
			order_by_query = {
				{ key = "bytes", value = "DESC" },
			},
			limit_query = {
				1000,
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			root = {
				formatter = format_utils.formatASN,
				id = asn,
				add_root_last = true,
			},
		},
		{
			select_query = {
				{
					key = "DST_ASN",
					rename = "src_asn",
					is_key = true,
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{
					key = "DST_PEER_ASN",
					rename = "src_peer_asn",
					is_key = true,
					remove_if_equal_to = { "src_asn", "0" },
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{ key = "SUM(DST2SRC_BYTES)", rename = "bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "src_asn", value = "0", operator = operators.neq }, -- DST_ASN != 0
				{ key = "SRC_ASN", value = asn, operator = operators.eq }, -- SRC_ASN = SEARCHED_ASN
				{ key = "DST2SRC_BYTES", value = "0", operator = operators.gt },
			},
			order_by_query = {
				{ key = "bytes", value = "DESC" },
			},
			limit_query = {
				1000,
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			root = {
				formatter = format_utils.formatASN,
				id = asn,
				add_root_last = true,
			},
		},
		{
			select_query = {
				{
					key = "SRC_ASN",
					rename = "dst_asn",
					is_key = true,
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{
					key = "DST_PEER_ASN",
					rename = "src_peer_asn_2",
					is_key = true,
					remove_if_equal_to = { asn, "0" },
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{ key = "SUM(DST2SRC_BYTES)", rename = "bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "dst_asn", value = "0", operator = operators.neq }, -- SRC_ASN != 0
				{ key = "DST_ASN", value = asn, operator = operators.eq }, -- DST_ASN = SEARCHED_ASN
				{ key = "DST2SRC_BYTES", value = "0", operator = operators.gt },
			},
			order_by_query = {
				{ key = "bytes", value = "DESC" },
			},
			limit_query = {
				1000,
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			root = {
				formatter = format_utils.formatASN,
				id = asn,
				add_root_first = true,
			},
		},
		{
			select_query = {
				{
					key = "DST_ASN",
					rename = "dst_asn",
					is_key = true,
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{
					key = "SRC_PEER_ASN",
					rename = "src_peer_asn_2",
					is_key = true,
					remove_if_equal_to = { asn, "0" },
					formatter = format_utils.formatASN,
					linker = generateASNLink,
				},
				{ key = "SUM(SRC2DST_BYTES)", rename = "bytes", formatter = format_utils.bytesToSize },
			},
			where_query = {
				{ key = "dst_asn", value = "0", operator = operators.neq }, -- DST_ASN != 0
				{ key = "SRC_ASN", value = asn, operator = operators.eq }, -- SRC_ASN = SEARCHED_ASN
				{ key = "SRC2DST_BYTES", value = "0", operator = operators.gt },
			},
			order_by_query = {
				{ key = "bytes", value = "DESC" },
			},
			limit_query = {
				1000,
			},
			basic_filters = { -- These info are used internally to filter the data, being pretty strange the
				ifid = ifid, -- where generated, it is better to manually format inside
				epoch_begin = epoch_begin,
				epoch_end = epoch_end,
			},
			root = {
				formatter = format_utils.formatASN,
				id = asn,
				add_root_first = true,
			},
		},
	}
end

local nodes = {}
local links = {}
local MAX_NODES_PER_LEVEL = 10
nodes, links = flow_sankey.generateSankey(queries, MAX_NODES_PER_LEVEL, not isEmptyString(epoch_begin))

res["nodes"] = nodes
res["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, res)
