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
local rsp = {
  labels = {},
  series = {},
  colors = {},
}

if host_stats then
  local eth_stats = interface.getMacInfo(host_stats["mac"])

  if eth_stats then
    local arp_sent = eth_stats["arp_requests.sent"] + eth_stats["arp_replies.sent"]
    local arp_rcvd = eth_stats["arp_requests.rcvd"] + eth_stats["arp_replies.rcvd"]

    rsp["labels"][1] = i18n("sent")
    rsp["series"][1] = arp_sent
    rsp["colors"][1] = graph_utils.get_html_color(1)

    rsp["labels"][2] = i18n("received")
    rsp["series"][2] = arp_rcvd
    rsp["colors"][2] = graph_utils.get_html_color(2)
  end
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
