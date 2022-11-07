--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Imports
require "lua_utils"
local rest_utils = require "rest_utils"
local graph_utils = require "graph_utils"

-- Local variables

local ifid        = _GET["ifid"] or interface.getId()
local host_ip     = _GET["host"]
local host_vlan   = _GET["vlan"] or 0
interface.select(tostring(ifid))

local host = interface.getHostInfo(host_ip, host_vlan)
local series = {}
local labels = {}
local colors = {}
local rsp = {
  labels = {},
  series = {},
  colors = {},
}

if(host and host.cardinality) then
  series[#series + 1] = tonumber(host.cardinality.num_contacted_hosts_as_client or 0)
  series[#series + 1] = tonumber(host.cardinality.num_contacted_hosts_as_server or 0)
else
  series[#series + 1] = 0
  series[#series + 1] = 0
end

colors[#colors + 1] =  graph_utils.get_html_color(#colors + 1)
colors[#colors + 1] =  graph_utils.get_html_color(#colors + 1)
labels[#labels + 1] = i18n("traffic_page.num_contacted_hosts_as_client")
labels[#labels + 1] = i18n("traffic_page.num_contacted_hosts_as_server")

rsp["series"] = series
rsp["labels"] = labels
rsp["colors"] = colors

rest_utils.answer(rest_utils.consts.success.ok, rsp)
