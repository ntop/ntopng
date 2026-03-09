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
local total = 0
local data  = {}

local pkt_distribution = {
  syn    = "SYN",
  synack = "SYN/ACK",
  finack = "FIN/ACK",
  rst    = "RST",
}

if host_stats and host_stats["pktStats.sent"] then
  local serie = {}

  for label, value in pairs(host_stats["pktStats.sent"]["tcp_flags"] or {}) do
    total = total + value
    serie[label] = value
  end

  for label, value in pairs((host_stats["pktStats.recv"] or {})["tcp_flags"] or {}) do
    serie[label] = (serie[label]) + value
  end

  for label, value in pairs(serie) do
    if value > 0 then
      data[#data + 1] = {
        label = pkt_distribution[label] or label,
        value = value
      }
    end
  end
end

rest_utils.answer(rest_utils.consts.success.ok, data)