--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local stats_utils = require "stats_utils"

local host_ip    = _GET["host"]
local vlan       = _GET["vlan"]
local host_stats = interface.getHostInfo(host_ip, vlan) or {}
local total = 0
local data  = {}

if host_stats and host_stats["pktStats.recv"] then
  local serie = {}

  for label, value in pairs(host_stats["pktStats.recv"]["size"] or {}) do
    total = total + value
    serie[#serie + 1] = { label = label, value = value }
  end

  local collapsed = stats_utils.collapse_stats(serie, 1, 5)
  for i, item in pairs(collapsed or {}) do
    if item.value > 0 then
      data[#data + 1] = {
        label = item.label,
        value = item.value
      }
    end
  end
end

rest_utils.answer(rest_utils.consts.success.ok, data)