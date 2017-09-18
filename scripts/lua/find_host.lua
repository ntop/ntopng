--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

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

      if(res ~= nil) then
	 for k, v in pairs(res) do
	    if isIPv6(k) and (not string.contains(v, "%[IPv6%]")) then
	      v = v.." [IPv6]"
	    end

	    if((v ~= "") and (already_printed[v] == nil)) then
	       if(num > 0) then print(",\n") end
	       print('\t{"name": "'..v..'", "ip": "'..k..'"}')
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

