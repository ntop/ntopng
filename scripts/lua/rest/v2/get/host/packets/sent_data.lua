--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Imports
require "lua_utils"
local rest_utils = require "rest_utils"
local stats_utils = require "stats_utils"
local graph_utils = require "graph_utils"

-- Local variables
local host_ip = _GET["host"]
local vlan = _GET["vlan"]
local host_stats = interface.getHostInfo(host_ip, vlan) or {}
local rsp = {
  labels = {},
  series = {},
  colors = {},
}

if host_stats and host_stats["pktStats.sent"] then
  local serie = {}
  local current_data = 0
  local data = host_stats["pktStats.sent"]["size"]

  for label, value in pairs(data or {}) do
    serie[#serie + 1] = { label = label, value = value }
  end

  local collapsed = stats_utils.collapse_stats(serie, 1, 5 --[[ threshold ]])
  for _, value in pairs(collapsed or {}) do
    current_data = current_data + 1
    rsp["labels"][#rsp["labels"] + 1] = value.label
    rsp["series"][#rsp["series"] + 1] = value.value
    rsp["colors"][#rsp["colors"] + 1] = graph_utils.get_html_color(current_data)
  end
end


rest_utils.answer(rest_utils.consts.success.ok, rsp)
