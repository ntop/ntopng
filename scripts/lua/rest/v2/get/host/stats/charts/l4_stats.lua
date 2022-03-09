--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local rest_utils = require "rest_utils"

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
  ifid = interface.getId()
end

interface.select(tostring(ifid))

local host_ip     = _GET["host"]
local host_vlan   = _GET["vlan"] or 0
local host = interface.getHostInfo(host_ip, host_vlan)

local total = 0
local total_bytes_sent = 0
local total_bytes_rcvd = 0
local proto_stats = {}
local max_num_entries = 5
local colors1 = {}
local labels1 = {}
local series1 = {}
local colors2 = {}
local labels2 = {}
local series2 = {}
local rsp = {}
local rc = rest_utils.consts.success.ok

for id, _ in ipairs(l4_keys) do
  local key = l4_keys[id][2]
  local traffic = 0
  
  if(host[key..".bytes.sent"] ~= nil) then 
    traffic = traffic + host[key..".bytes.sent"] 
    total_bytes_sent = total_bytes_sent + host[key..".bytes.sent"] 
  end
  
  if(host[key..".bytes.rcvd"] ~= nil) then 
    traffic = traffic + host[key..".bytes.rcvd"] 
    total_bytes_rcvd = total_bytes_rcvd + host[key..".bytes.rcvd"] 
  end

  if traffic > 0 then
    proto_stats[l4_keys[id][1]] = traffic
    total = total + traffic
  end
end


for key, value in pairsByValues(proto_stats, rev) do
  series1[#series1 + 1] = value
  labels1[#labels1 + 1] = key
  colors1[#colors1 + 1] = graph_utils.get_html_color(#colors1 + 1)
  max_num_entries = max_num_entries - 1

  -- Just return the top 5 l4 protocols
  if max_num_entries == 1 then
    break
  end
end

if(host.cardinality) then
  series2[#series2 + 1] = formatValue(host.cardinality.num_contacted_hosts_as_client) or 0
  series2[#series2 + 1] = formatValue(host.cardinality.num_contacted_hosts_as_server) or 0
else
  series2[#series2 + 1] = {}
  series2[#series2 + 1] = {}
end

colors2[#colors2 + 1] =  graph_utils.get_html_color(#colors2 + 1)
colors2[#colors2 + 1] =  graph_utils.get_html_color(#colors2 + 1)
labels2[#labels2 + 1] = i18n("traffic_page.num_contacted_hosts_as_client")
labels2[#labels2 + 1] = i18n("traffic_page.num_contacted_hosts_as_server")

-- L4 proto total distribution
rsp["serie1"] = {
  ["series"] = series1,
  ["labels"] = labels1,
  ["colors"] = colors1
}

-- Host contacts
rsp["serie2"] = {
  ["series"] = series2,
  ["labels"] = labels2,
  ["colors"] = colors2
}

-- Bytes sent vs Bytes rcvd
rsp["serie3"] = {
  ["series"] = { total_bytes_sent, total_bytes_rcvd },
  ["labels"] = { i18n("traffic_page.bytes_sent"), i18n("traffic_page.bytes_rcvd") },
  ["colors"] = colors2 -- Still two colors like the second serie, reuse it
}

rest_utils.answer(rc, rsp)
