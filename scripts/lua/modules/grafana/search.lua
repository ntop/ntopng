--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "grafana_utils"



if isCORSpreflight() then
   processCORSpreflight()
else
   interface.select(ifname)

   local corsr = {}
   corsr["Access-Control-Allow-Origin"] = _SERVER["Origin"]
   sendHTTPHeader('application/json', nil, corsr)

   -- tprint("SEARCH")
   -- tprint(_POST)

   local target = _POST["payload"]["target"]
   --[[
      example targets:
      interface_eth0
      host_192.168.2.0
      host_192.168.2.0_interface_eth0
   --]]
   if target == nil then
      target = ""
   end

   local host_info
   local target_interfaces = {}

   -- PARSE the host part of the target
   -- the host part is preceeded by prefix host_
   if isEmptyString(target) or string.starts("host_", target) or string.starts(target, "host_") then
      local addr = string.match(target or '', "_(.-)_") -- assumes address is between the first two underscores
      if isEmptyString(addr) then
	 addr = string.match(target or '', "_(.-)$") -- assumes address is between the first underscore and the end of string
      end
      host_info = hostkey2hostinfo(addr or '')
      -- tprint(host_info)

      local a, b = string.find(target, addr or '')
      target = string.sub(target, b + 2 --[[ +2 removes the optional uderscore preceding interface_ --]])
      -- tprint({target=target})
   end

   -- PARSE the interface part of the target
   -- the interface part is preceeded by prefix interface_
   if isEmptyString(target) or string.starts("interface_", target) or string.starts(target, "interface_") then
      local ifnames = interface.getIfNames()
      for _, n in pairs(ifnames) do
	 local t  = "interface_"..n

	 if isEmptyString(target) or string.starts(t, target) or string.starts(target, t) then
	    target_interfaces[n] = 1
	 end

      end
   end

   local matches = {}

   for n,_ in pairs(target_interfaces) do
      interface.select(n)
      matches[n] = {}
      if host_info ~= nil then
	 local matching_hosts = interface.findHost(hostinfo2hostkey(host_info))
	 for addr, label in pairs(matching_hosts) do
	    matches[n][addr] = label
	 end
      end
   end

   local rsp_targets = {}
   local metrics = {"traffic_bps", "traffic_total_bytes", "allprotocols_bps", "allcategories_bps"}
   if host_info == nil then -- packets only for interfaces
      metrics[#metrics + 1] = "traffic_pps"
      metrics[#metrics + 1] = "traffic_total_packets"
   end

   for _, metric in pairs(metrics) do

      for n, hosts in pairs(matches) do
	 local interface_series = "interface_"..n.."_"..metric

	 for addr, label in pairs(hosts) do
	    local host_series = "host_"..addr
	    rsp_targets[#rsp_targets + 1] = host_series.."_"..interface_series
	 end

	 if host_info == nil then
	    rsp_targets[#rsp_targets + 1] = interface_series
	 end

      end
   end

   -- tprint({matches=matches, rsp_targets=rsp_targets})

   print(json.encode(rsp_targets, nil))
end
