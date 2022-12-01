--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Imports
require "lua_utils"
local graph_utils = require "graph_utils"
local rest_utils = require "rest_utils"

-- Local variables

local ifid        = _GET["ifid"] or interface.getId()
local host_ip     = _GET["host"]
local host_vlan   = _GET["vlan"] or 0
interface.select(tostring(ifid))

local formatted_host = hostinfo2hostkey({ host = host_ip, vlan_id = host_vlan })
local flows_stats = interface.getFlowsInfo(formatted_host) or {}
local series = {}
local labels = {}
local colors = {}
local max_num_ports = 16
local port_stats = {}
local rsp = {}

-- ##################################

if flows_stats["flows"] then
  flows_stats = flows_stats["flows"]
end

-- ##################################

local function fill_ports_array(field_key, flows_stats)
  local ports_array = {}

  for _, value in ipairs(flows_stats) do
     local p = value[field_key..".port"]
     if(ports_array[p] == nil) then ports_array[p] = 0 end
     ports_array[p] = ports_array[p] + value["bytes"]
  end

  return ports_array
end

-- ##################################

port_stats = fill_ports_array("srv", flows_stats)

for port, num_flows in pairsByKeys(port_stats, rev) do
  series[#series + 1] = num_flows
  labels[#labels + 1] = port
  colors[#colors + 1] = graph_utils.get_html_color(tonumber(port))
  max_num_ports = max_num_ports - 1

  if max_num_ports == 0 then
    break
  end
end

rsp = {
  series = series,
  labels = labels,
  colors = colors,
}

-- ##################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
