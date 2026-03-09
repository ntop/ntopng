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
local data       = {}

if host_stats then
  local eth_stats = interface.getMacInfo(host_stats["mac"])

  if eth_stats then
    local arp_sent = (eth_stats["arp_requests.sent"]) + (eth_stats["arp_replies.sent"])
    local arp_rcvd = (eth_stats["arp_requests.rcvd"]) + (eth_stats["arp_replies.rcvd"])

    if arp_sent + arp_rcvd > 0 then
      data[1] = { label = i18n("sent"),     value = arp_sent }
      data[2] = { label = i18n("received"), value = arp_rcvd }
    end
  end
end

rest_utils.answer(rest_utils.consts.success.ok, data)