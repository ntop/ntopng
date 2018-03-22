--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')
interface.select(ifname)

local mac = _GET["mac"]
local distr = _GET["distr"]
local res = {}
local found = false

if distr == "ipver" then
  local mac_hosts = interface.getHostsInfo(true --[[ no details ]], nil, nil, toSkip, nil, nil, nil, nil, nil, nil, mac)

  if mac_hosts ~= nil and mac_hosts.hosts ~= nil then
    local ipv4_packets = 0
    local ipv6_packets = 0

    for _, host in pairs(mac_hosts.hosts) do
      local host_packets = host["packets.sent"] + host["packets.rcvd"]

      if isIPv6Address(host.ip) then
        ipv6_packets = ipv6_packets + host_packets
      else
        ipv4_packets = ipv4_packets + host_packets
      end
    end

    if ipv4_packets > 0 then
      res[#res + 1] = {
        label = i18n("ipv4"),
        value = ipv4_packets,
      }
      found = true
    end

    if ipv6_packets > 0 then
      res[#res + 1] = {
        label = i18n("ipv6"),
        value = ipv6_packets,
      }
      found = true
    end
  end
end

if(not(found)) then
   res[#res + 1] = {
      label = "No IP",
      value = 1,
   }
end

print(json.encode(res))
