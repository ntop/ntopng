--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

max_num_to_find = 5

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

      if(res ~= nil) then
	 values = {}
	 for k, v in pairs(res) do
	    if(v ~= "") then
	       if not values[v] then
	          values[v] = 1
	       else
	          values[v] = values[v] + 1
	       end
	    end
	 end
	 
	 for k, v in pairs(res) do
	    if(v ~= "") then
	       if values[v] > 1 then
	          -- we matched both an ipv4 and ipv6 with same host name, display differently
	          if findString(v, ":") == nil then
	            v = v .. " (IPv4)"
	          else
	            v = v .. " (IPv6)"
	          end
	       end
	       
	       if(num > 0) then print(",\n") end
	       print('\t{"name": "'..v..'", "ip": "'..k..'"}')
	       num = num + 1
	    end -- if
	  end -- for
       end -- if

      print [[

	 ]
      }
]]

