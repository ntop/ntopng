--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"


local host_ip    = _GET["host"]
local vlan       = _GET["vlan"]
local host_stats = interface.getHostInfo(host_ip, vlan) or {}
local max_data   = 10
local data       = {}

local ifstats = computeL7Stats(host_stats, false --[[ show breed ]], false --[[ show ndpi category ]])

for key, value in pairsByValues(ifstats, rev) do
  data[#data + 1] = {
    label = key,
    value = value
  }

  if #data >= max_data then break end
end

rest_utils.answer(rest_utils.consts.success.ok, data)