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
local host_ip = _GET["host"]
local vlan = _GET["vlan"]
local host_stats = interface.getHostInfo(host_ip, vlan) or {}
local max_data = 10
local current_data = 0
local rsp = {
  labels = {},
  series = {},
  colors = {},
}

local ifstats = computeL7Stats(host_stats, true --[[ show breed ]], false --[[ show ndpi category ]])

for key, value in pairsByValues(ifstats, rev) do
  current_data = current_data + 1
  rsp["labels"][#rsp["labels"] + 1] = key
  rsp["series"][#rsp["series"] + 1] = value
  rsp["colors"][#rsp["colors"] + 1] = graph_utils.get_html_color(current_data)

  if current_data >= max_data then
    break
  end
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
