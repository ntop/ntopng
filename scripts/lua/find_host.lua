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
	 for k, v in pairs(res) do
	    if(v ~= "") then 
	       if(num > 0) then print(",\n") end
	       print('\t"'..v..'"')
	       num = num + 1
	    end -- if
	  end -- for
       end -- if

      print [[

	 ]
      }
]]

