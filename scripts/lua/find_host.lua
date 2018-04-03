--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   require("snmp_utils")
end

sendHTTPHeader('application/json')

max_num_to_find = 5
local already_printed = {}

print [[
      {
	 "interface" : "]] print(ifname) print [[",
	 "results": [
      ]]

      query = _GET["query"]
      if(query == nil) then query = "" end
      num = 0

      interface.select(ifname)
      res = interface.findHost(query)

      -- Also look at the custom names
      local ip_to_name = ntop.getHashAllCache(getHostAltNamesKey()) or {}
      for ip,name in pairs(ip_to_name) do
        if string.contains(string.lower(name), string.lower(query)) then
          res[ip] = hostVisualization(ip, name)
        end
      end

      -- Also look at the DHCP cache
      local mac_to_name = ntop.getHashAllCache(getDhcpNamesKey(getInterfaceId(ifname))) or {}
      for mac, name in pairs(mac_to_name) do
        if string.contains(string.lower(name), string.lower(query)) then
          res[mac] = hostVisualization(mac, name)
        end
      end

      if isMacAddress(query) and ntop.isPro() then
	    local mac = string.upper(query)
	    local devices = get_snmp_devices()

	    for snmp_device_ip, _ in pairs(devices) do
		  local v = ntop.getCache("cachedsnmp."..snmp_device_ip.."." .. mac .. ".port")
		  if v ~= nil then
			print('\t{"name": "' .. mac .. ' [SNMP]", "ip": "' .. snmp_device_ip .. '", "type": "snmp"}')
			num = num + 1
			break
		  end
	    end
      end

      if(res ~= nil) then
	 for k, v in pairs(res) do
	    if isIPv6(v) and (not string.contains(v, "%[IPv6%]")) then
	      v = v.." [IPv6]"
	    end

	    if((v ~= "") and (already_printed[v] == nil)) then
	       if(num > 0) then print(",\n") end
	       print('\t{"name": "'..v..'", ')
	       if isMacAddress(v) then
	          print('"ip": "'..v..'", "type": "mac"}')
	       elseif isMacAddress(k) then
		  print('"ip": "'..k..'", "type": "mac"}')
	       else
	          print('"ip": "'..k..'", "type": "ip"}')
	       end
	       num = num + 1
	       already_printed[v] = true
	    end -- if

	    if num >= max_num_to_find then
	      break
	    end
	  end -- for
       end -- if

      print [[

	 ]
      }
]]

