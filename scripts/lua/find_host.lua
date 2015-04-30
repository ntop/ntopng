--
-- (C) 2013-15 - ntop.org
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
      if(true) then
	 res = interface.findHost(query)
	 
	 for k, v in pairs(res) do
	    if(v ~= "") then 
	       if(num > 0) then print(",\n") end
	       print('\t"'..v..'"')
	       num = num + 1
	    end
	 end
      else
      hosts_stats = interface.getHostsInfo(true)
      --   query = "192"

      if(query ~= nil) then
	 query = string.lower(query)

	 for _key, value in pairs(hosts_stats) do
	    if(num >= max_num_to_find) then
	       break
	    end
	    found = 0
	    if((hosts_stats[_key]["name"] == nil) and (hosts_stats[_key]["ip"] ~= nil)) then
	       hosts_stats[_key]["name"] = ntop.getResolvedAddress(hosts_stats[_key]["ip"])
	    end
	    what = hosts_stats[_key]["name"]

	    if((what ~= nil) and (string.contains(string.lower(what), query))) then
	       found = 1
	    else
	       what = hosts_stats[_key]["mac"]
	       if(starts(what, query)) then
		  found = 1
	       else
		  if(hosts_stats[_key]["ip"] ~= nil) then
		     what = hosts_stats[_key]["ip"]
		     if(starts(what, query)) then
			found = 1
		     end
		  end
	       end
	    end
	    
	    if(found == 1) then
	       if(num > 0) then print(",\n") end
	       print("\t\""..what .. "\"")
	       num = num + 1	 
	    end
	 end

	 if(num < max_num_to_find) then
	    aggregated_hosts_stats = interface.getAggregatedHostsInfo()
	    for _key, value in pairs(aggregated_hosts_stats) do
	       if(num >= max_num_to_find) then
		  break
	       end      
	       found = 0
	       if((aggregated_hosts_stats[_key]["name"] == nil) and (aggregated_hosts_stats[_key]["ip"] ~= nil)) then
		  aggregated_hosts_stats[_key]["name"] = ntop.getResolvedAddress(aggregated_hosts_stats[_key]["ip"])
	       end
	       what = aggregated_hosts_stats[_key]["name"]
	       if((what ~= nil) and (starts(what, query))) then
		  found = 1
		  what = what .. " (" .. aggregated_hosts_stats[_key]["family"] .. ")"
	       end

	       if(found == 1) then
		  if(num > 0) then print(",\n") end
		  print("\t\""..what .. "\"")
		  num = num + 1
	       end
	    end
	 end
      end
   end

      print [[

	 ]
      }
]]

