--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

--sendHTTPHeader('text/html; charset=iso-8859-1')
sendHTTPHeader('application/json')


host_info = url2hostinfo(_GET)
interface.select(ifname)

print [[
{"center":[0, 0],
 "objects":
 []]


    max_num = 100
    num = 0

    if (host_info["host"] == nil) then
       hosts_stats = interface.getHostsInfo()
       hosts_stats = hosts_stats["hosts"]

       for key, value in pairs(hosts_stats) do
	  if(value["ip"] ~= nil) then
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
	     
	     if(num > max_num) then break end      
	  end
       end

       print ("\n]\n}\n")
       
       return
    end

    -- Flows with trajectory

    interface.select(ifname)
    peers = interface.getFlowPeers(host_info["host"],host_info["vlan"])

    maxval = 0
    for key, values in pairs(peers) do
       t = values["bytes"]

       if(t > maxval) then maxval = t end
    end

    min_threshold = 0 --  0.5%
    for key, values in pairs(peers) do
       t = values["bytes"]
       pctg = (t*100)/maxval

       if(not(values["cli.private"])
       and not(values["srv.private"])
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
	     
	     if(num > max_num) then break end
	  end
       end
    end


    print [[
       ]
    }
]]
