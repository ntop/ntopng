--
-- (C) 2013-25 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "check_redis_prefs"
require "flow_utils"
local rest_utils = require "rest_utils"
local flow_pie = require "flow_pie"
local format_utils = require "format_utils"
local graph_utils = require "graph_utils"

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
                "src_asn", "total_bytes"
            },
            rename_key_field = {"costumer"},
            different_from = {nil, "src_asn", "dst_asn"},
            skip_flow = {{key = "src_asn", value = "0"}},
            where_query = {"dst_asn"},
            sort_by = {"total_bytes"},
            filters = {
                dst_asn = asn,
                ifid = ifid,
                first_seen = epoch_begin,
                last_seen = epoch_end
            },
            only_costumers = true,
            value_ref = "total_bytes",
            section_ref = "costumer",
            section_format = format_utils.formatASN
        }, {
            select_query = {
                "dst_asn", "total_bytes"
            },
            rename_key_field = {"costumer"},
            where_query = {"src_asn"},
            sort_by = {"total_bytes"},
            different_from = {"src_asn", "dst_asn"},
            skip_flow = {{key = "dst_asn", value = 0}},
            filters = {
                src_asn = asn,
                ifid = ifid,
                first_seen = epoch_begin,
                last_seen = epoch_end
            },
            only_costumers = true,
            value_ref = "total_bytes",
            section_ref = "costumer",
            section_format = format_utils.formatASN
        }
    }
end

local sections
sections = flow_pie.generatePie(queries, 10000, not isEmptyString(epoch_begin))

table.sort(sections, function(a, b)
  return a.value > b.value
end)

local js_formatter = "formatValue"
rest_utils.extended_answer(rest_utils.consts.success.ok, graph_utils.convert_pie_data(sections, true, js_formatter))
