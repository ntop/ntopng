--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

--sendHTTPContentTypeHeader('text/html')
sendHTTPHeader('application/json')

host_info = url2hostinfo(_GET)
interface.select(ifname)

print [[
{"center":[0, 0],
 "objects":
 []]


    local max_num = 100
    num = 0

    if (host_info["host"] == nil) then
       -- here no host has been specified
       hosts_stats = interface.getHostsInfo(true, "column_traffic", max_num)
       hosts_stats = hosts_stats["hosts"]

       for key, value in pairs(hosts_stats) do
	  if((value["ip"] ~= nil) and (not value["privatehost"]) and (not isBroadMulticast(value["ip"]))) then
	     if(num > 0) then print(",") end
	     print('{\n"host": [ { ')
	     print('"lat": '..value["latitude"]..',\n')
	     print('"lng": '..value["longitude"]..',\n')

	     print('"html": "')
	     if((value["city"] ~= nil) and (value["city"] ~= "")) then
		print('City: '..value["city"])
	     end

	     print(getFlag(value["country"]))
	     print('",\n')

	     print('"name": "'..key..'"\n')
	     print('} ] }\n')
	     num = num + 1
	     
	  end
       end

       print ("\n]\n}\n")
       
       return
    end

    -- Flows with trajectory

    interface.select(ifname)
    peers = getTopFlowPeers(hostinfo2hostkey(host_info), max_num - num, nil, {detailsLevel="max"})

    maxval = 0
    for key, values in pairs(peers) do
       t = values["bytes"]

       if(t > maxval) then maxval = t end
    end

    min_threshold = 0 --  0.5%
    for key, values in pairs(peers) do
       t = values["bytes"]
       pctg = (t*100)/maxval

       if(not(values["cli.private"] and values["srv.private"]) -- at least one of the two must be public
    and not(isBroadMulticast(values["cli.ip"])) 
 and not(isBroadMulticast(values["srv.ip"]))) then
	  if((pctg >= min_threshold)
	  and (values["cli.latitude"] ~= nil)
       and (values["cli.longitude"] ~= nil)) then
	     if(num > 0) then print(",") end
	     print('\n{\n"host":\n[	\n{\n')
	     print('"lat": '..values["cli.latitude"]..',\n')
	     print('"lng": '..values["cli.longitude"]..',\n')

	     print('"html": "')
	     if((values["cli.city"] ~= nil) and (values["cli.city"] ~= "")) then
		print('City: '..values["cli.city"])
	     end

	     print(getFlag(values["cli.country"]))
	     print('",\n')

	     print('"name": "'..hostinfo2hostkey(values, "cli")..'"\n')
	     print('},\n{\n')
	     print('"lat": '..values["srv.latitude"]..',\n')
	     print('"lng": '..values["srv.longitude"]..',\n')
	     
	     print('"html": "')
	     if((values["srv.city"] ~= nil) and (values["srv.city"] ~= "")) then
		print('City: '..values["srv.city"])
	     end
	     print(getFlag(values["srv.country"]))
	     print('",\n')

	     print('"name": "'..hostinfo2hostkey(values, "srv")..'"\n')
	     print('}\n],\n"flusso": '.. pctg..',"html":"Flow '.. hostinfo2hostkey(values, "cli").." "..hostinfo2hostkey(values, "srv") .. '"\n')
	     print('}\n')
	     num = num + 1
	  end
       end
    end


    print [[
       ]
    }
]]
