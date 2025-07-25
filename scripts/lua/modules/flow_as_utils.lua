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
local tot_bytes_transit = {}
local tot_bytes_as = {}

-- Total bytes sent/rcvd per exporter/interface (key = <device ip>@<if index>)

local tot_bytes_exp_if = {}
local tot_bytes_as_transit = {}

-- ####################

local function resetAll()
    tot_bytes_exporter = {}
    tot_bytes_transit = {}
    tot_bytes_as = {}
    tot_bytes_exp_if = {}
    tot_bytes_as_transit = {}
end

-- ####################

local function init_exporter(device_ip)
    local key = device_ip
    if not tot_bytes_exporter[key] then
        tot_bytes_exporter[key] = {sent = 0, rcvd = 0}
    end
end

-- ####################

local function init_transit(transit)
    local key = transit
    if not tot_bytes_transit[key] then
        tot_bytes_transit[key] = {sent = 0, rcvd = 0}
    end
end

-- ####################

local function init_as(as)
    local key = as
    if not tot_bytes_as[key] then
        tot_bytes_as[key] = {sent = 0, rcvd = 0}
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

local function inc_transit_sent(key, bytes)
    tot_bytes_transit[key].sent = tot_bytes_transit[key].sent + bytes
end

-- ####################

local function inc_transit_rcvd(key, bytes)
    tot_bytes_transit[key].rcvd = tot_bytes_transit[key].rcvd + bytes
end

-- ####################

local function inc_as_sent(key, bytes)
    tot_bytes_as[key].sent = tot_bytes_as[key].sent + bytes
end

-- ####################

local function inc_as_rcvd(key, bytes)
    tot_bytes_as[key].rcvd = tot_bytes_as[key].rcvd + bytes
end

-- ####################

local function get_interface_key(device_ip, interface_index)
    return device_ip .. "@" .. interface_index
end

-- ####################

local function get_as_key(transit, src_dst_as)
    return transit .. "@" .. src_dst_as
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

local function init_link_as_transit(transit, as)
   local key = get_as_key(transit, as)
   if not tot_bytes_as_transit[key] then
        tot_bytes_as_transit[key] = {
	        sent = 0,
	        rcvd = 0,
	        transit = transit,
	        src_dst_as = as
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

local function inc_link_as_transit_sent(key, bytes)
    tot_bytes_as_transit[key].sent = tot_bytes_as_transit[key].sent + bytes
end

-- ####################

local function inc_link_as_transit_rcvd(key, bytes)
    tot_bytes_as_transit[key].rcvd = tot_bytes_as_transit[key].rcvd + bytes
end

-- ####################

local function callback_transit(src_dst_peer_as, src_dst_as, bytes_rcvd, bytes_sent)
    init_transit(src_dst_peer_as)
    init_as(src_dst_as)
    init_link_as_transit(src_dst_peer_as, src_dst_as)
    inc_link_as_transit_sent(get_as_key(src_dst_peer_as, src_dst_as), bytes_sent)
    inc_link_as_transit_rcvd(get_as_key(src_dst_peer_as, src_dst_as), bytes_rcvd)
    inc_as_sent(src_dst_as, bytes_sent)
    inc_as_rcvd(src_dst_as, bytes_rcvd)
    if (src_dst_peer_as ~= src_dst_as) then
        inc_transit_sent(src_dst_peer_as, bytes_sent)
        inc_transit_rcvd(src_dst_peer_as, bytes_rcvd)
    end
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
        -- Initialize transit
        if(flow.src_peer_as ~= nil) and (flow.dst_as ~= nil) and 
            (flow.src_peer_as ~= flow.dst_as) and (flow.src_peer_as ~= flow.src_as) then
                callback_transit(flow.src_peer_as, flow.dst_as, flow.bytes_sent, flow.bytes_rcvd)
        elseif((flow.dst_peer_as ~= nil) and (flow.dst_as ~= nil)) then
                callback_transit(flow.dst_peer_as, flow.dst_as, flow.bytes_sent, flow.bytes_rcvd)
        end

    elseif (flow.dst_as == asn) then
        init_interface(flow.device_ip, flow.out_index)
        inc_interface_sent(get_interface_key(flow.device_ip, flow.out_index), flow.bytes_sent)
        inc_interface_rcvd(get_interface_key(flow.device_ip, flow.out_index), flow.bytes_rcvd)
        inc_exporter_sent(flow.device_ip, flow.bytes_sent)
        inc_exporter_rcvd(flow.device_ip, flow.bytes_rcvd)
        if((flow.dst_peer_as ~= nil) and (flow.src_as ~= nil)) and
            (flow.dst_peer_as ~= flow.dst_as) and (flow.dst_peer_as ~= flow.src_as) then
            callback_transit(flow.dst_peer_as, flow.src_as, flow.bytes_rcvd, flow.bytes_sent) 
        elseif((flow.src_peer_as ~= nil) and (flow.src_as ~= nil)) then
            callback_transit(flow.src_peer_as, flow.src_as, flow.bytes_rcvd, flow.bytes_sent)
        end
    end
end

-- ###################################################

function flow_as_utils.loadFlows(as, ifid)
    asn = as
    local flows_filter = {
        asnFilter = as,
        detailsLevel = "normal",
    }
    callback_utils.foreachFlow(ifid, os.time() + 30, -- deadline
		    callback, flows_filter)
end

function flow_as_utils.getTransit(as, ifid)
    if tot_bytes_transit == nil or asn ~= as then flow_as_utils.loadFlows(as, ifid) end
    return tot_bytes_transit
end

function flow_as_utils.getAs(as, ifid)
    if tot_bytes_as == nil or asn ~= as then flow_as_utils.loadFlows(as, ifid) end
    return tot_bytes_as
end

function flow_as_utils.getExporter(as, ifid)
    if tot_bytes_exporter == nil or asn ~= as then flow_as_utils.loadFlows(as, ifid) end
    return tot_bytes_exporter
end

function flow_as_utils.getExporterIf(as, ifid)
    if tot_bytes_exp_if == nil or asn ~= as then flow_as_utils.loadFlows(as, ifid) end
    return tot_bytes_exp_if
end

function flow_as_utils.getAsTransit(as, ifid)
    if tot_bytes_as_transit == nil or asn ~= as then flow_as_utils.loadFlows(as, ifid) end
    return tot_bytes_as_transit
end

function flow_as_utils.getAll(as, ifid)
    if tot_bytes_as_transit == nil or asn ~= as then flow_as_utils.loadFlows(as, ifid) end
    return {
        exporter = tot_bytes_exporter,
        transit = tot_bytes_transit,
        as = tot_bytes_as,
        exp_if = tot_bytes_exp_if,
        as_transit = tot_bytes_as_transit
    }
end

return flow_as_utils