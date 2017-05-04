--
-- (C) 2013-17 - ntop.org
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

      -- Also look at the custom names
      local ip_to_name = ntop.getHashAllCache(getHostAltNamesKey()) or {}
      for ip,name in pairs(ip_to_name) do
        if string.contains(string.lower(name), string.lower(query)) then
          res[ip] = hostVisualization(ip, name)
        end
      end

      if(res ~= nil) then
	 for k, v in pairs(res) do
	    if(v ~= "") then
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

