--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
require "label_utils"
local flow_as_utils = {}
local as_utils = require "as_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"
local info = ntop.getInfo()
local callback_utils = require "callback_utils"

local ifid
local asn = -1

local transit_utils_debug = false

-- ####################

-- Total bytes sent/rcvd per exporter (key = <device ip>)

local tot_bytes_exporter = {}

-- Total bytes sent/rcvd per exporter/interface (key = <device ip>@<if index>)

local tot_bytes_exp_if = {}

-- ####################

local function resetAll()
    tot_bytes_exporter = {}
    tot_bytes_exp_if = {}
end

-- ####################

local function init_exporter(device_ip)
    local key = device_ip
    if not tot_bytes_exporter[key] then
        tot_bytes_exporter[key] = {sent = 0, rcvd = 0}
    end
end

-- ####################

local function inc_exporter_sent(key, bytes)
    tot_bytes_exporter[key].sent = tot_bytes_exporter[key].sent + bytes
end

-- ####################

local function inc_exporter_rcvd(key, bytes)
    tot_bytes_exporter[key].rcvd = tot_bytes_exporter[key].rcvd + bytes
end

-- ####################

local function get_interface_key(device_ip, interface_index)
    return device_ip .. "@" .. interface_index
end

-- ####################

local function init_interface(device_ip, interface_index)
    local key = get_interface_key(device_ip, interface_index)
    if not tot_bytes_exp_if[key] then
        tot_bytes_exp_if[key] = {
	        sent = 0,
	        rcvd = 0,
	        exporter_ip = device_ip,
	        port_index = interface_index
        }
   end
end

-- ####################

local function inc_interface_sent(key, bytes)
    tot_bytes_exp_if[key].sent = tot_bytes_exp_if[key].sent + bytes
end

-- ####################

local function inc_interface_rcvd(key, bytes)
    tot_bytes_exp_if[key].rcvd = tot_bytes_exp_if[key].rcvd + bytes
end

-- ####################

local aggregation_keys = {}

local field_keys = {}

local aggregated_table = {}

local function get_aggregation_key(keys)
    local result = ""
    for _,key in pairs(keys) do
        if result == "" then result = key 
        else
            result = result .. "@" .. key
        end
    end
    return result
end

-- ####################

-- Flow iterator callback
local function callback(_, flow)
    if (transit_utils_debug) then
        -- tprint(flow.bytes_sent .. " / " .. flow.bytes_rcvd)
        tprint("[AS] " .. flow.src_as .. " -> " .. flow.dst_as .. " | [IDX] " ..
            flow.in_index .. " -> " .. flow.out_index .. " | " ..
            flow.bytes_sent .. " / " .. flow.bytes_rcvd)
    end

    local key = ""
    for _,k in ipairs(aggregation_keys) do
        if flow[k] ~= nil then
            if key == "" then key = flow[k] 
            else
                key = key .. "@" .. flow[k]
            end
        end
    end
    for _,k in ipairs(field_keys) do
        if flow[k] ~= nil then
            if aggregated_table[key] == nil then 
                aggregated_table[key] = {}
                aggregated_table[key][k] = flow[k]
            elseif aggregated_table[key][k] ~= nil and 
                    (k == "bytes_sent" or k == "bytes_rcvd" or k == "bytes_total") then
                aggregated_table[key][k] = aggregated_table[key][k] + flow[k]
            else
                aggregated_table[key][k] = flow[k]
            end
        end
    end

    -- Initialize hash entries if not yet popupated
    init_exporter(flow.device_ip)
    --init_interface(flow.device_ip, flow.in_index)
    --init_interface(flow.device_ip, flow.out_index)
    if (flow.src_as == asn) then
        init_interface(flow.device_ip, flow.in_index)
        inc_interface_sent(get_interface_key(flow.device_ip, flow.in_index), flow.bytes_rcvd)
        inc_interface_rcvd(get_interface_key(flow.device_ip, flow.in_index), flow.bytes_sent)
        inc_exporter_sent(flow.device_ip, flow.bytes_rcvd)
        inc_exporter_rcvd(flow.device_ip, flow.bytes_sent)

    elseif (flow.dst_as == asn) then
        init_interface(flow.device_ip, flow.out_index)
        inc_interface_sent(get_interface_key(flow.device_ip, flow.out_index), flow.bytes_sent)
        inc_interface_rcvd(get_interface_key(flow.device_ip, flow.out_index), flow.bytes_rcvd)
        inc_exporter_sent(flow.device_ip, flow.bytes_sent)
        inc_exporter_rcvd(flow.device_ip, flow.bytes_rcvd)
    end
end

-- ###################################################

function flow_as_utils.loadFlows(as, ifid)
    asn = as
    aggregated_table = {}
    local flows_filter = {
        asnFilter = as,
        detailsLevel = "normal",
    }
    callback_utils.foreachFlow(ifid, os.time() + 30, -- deadline
		    callback, flows_filter)
end

function flow_as_utils.getAsTransit(asn, ifid, src_dst)
    aggregation_keys = {"src_as", "dst_as", "dst_peer_as", "src_peer_as"}
    if src_dst == 0 then
        field_keys = {"src_as", "dst_as", "dst_peer_as", "src_peer_as", "bytes_rcvd"} 
    elseif src_dst == 0 then
        field_keys = {"src_as", "dst_as", "dst_peer_as", "src_peer_as", "bytes_sent"} 
    else 
        field_keys = {"src_as", "dst_as", "dst_peer_as", "src_peer_as", "bytes_sent", "bytes_rcvd"}
    end
    flow_as_utils.loadFlows(as, ifid)
    --tprint(aggregated_table)
    return aggregated_table
end

function flow_as_utils.getTransitList(asn, ifid, src_dst)
    if src_dst == 0 then
        aggregation_keys = {"dst_peer_as"}
        field_keys = {"dst_peer_as", "bytes_rcvd"} 
    else
        aggregation_keys = {"src_peer_as"}
        field_keys = {"src_peer_as", "bytes_sent"}
    end
    flow_as_utils.loadFlows(as, ifid)
    return aggregated_table
end

function flow_as_utils.getExporter(as, ifid)
    if tot_bytes_exporter == nil or asn ~= as then flow_as_utils.loadFlows(as, ifid) end
    return tot_bytes_exporter
end

function flow_as_utils.getExporterIf(as, ifid)
    if tot_bytes_exp_if == nil or asn ~= as then flow_as_utils.loadFlows(as, ifid) end
    return tot_bytes_exp_if
end


return flow_as_utils