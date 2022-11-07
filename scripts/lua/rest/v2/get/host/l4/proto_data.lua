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

local host = interface.getHostInfo(host_ip, host_vlan)
local series = {}
local labels = {}
local colors = {}
local max_num_entries = 5
local proto_stats = {}
local rsp = {
  series = {},
  labels = {},
  colors = {},
}

-- ##################################

if host then
  for id, _ in ipairs(l4_keys) do
    local key = l4_keys[id][2]
    local traffic = 0
    
    if(host[key..".bytes.sent"] ~= nil) then 
      traffic = traffic + host[key..".bytes.sent"] 
    end
    
    if(host[key..".bytes.rcvd"] ~= nil) then 
      traffic = traffic + host[key..".bytes.rcvd"] 
    end

    if traffic > 0 then
      proto_stats[l4_keys[id][1]] = traffic
    end
  end
end

for key, value in pairsByValues(proto_stats, rev) do
  series[#series + 1] = value
  labels[#labels + 1] = key
  colors[#colors + 1] = graph_utils.get_html_color(#colors + 1)
  max_num_entries = max_num_entries - 1

  -- Just return the top 5 l4 protocols
  if max_num_entries == 1 then
    break
  end
end

rsp["series"] = series
rsp["labels"] = labels
rsp["colors"] = colors

-- Just in case no data were found put an empty serie
if table.len(rsp["series"]) == 0 then
  rsp["series"] = { 0 }
  rsp["labels"] = { i18n('no_data_available') }
  rsp["colors"] = { graph_utils.get_html_color(#colors + 1) }
end

-- ##################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
