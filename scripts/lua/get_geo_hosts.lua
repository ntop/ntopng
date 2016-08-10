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
       t = values["sent"]+values["rcvd"]

       if(t > maxval) then maxval = t end
    end

    min_threshold = 0 --  0.5%
    for key, values in pairs(peers) do
       t = values["sent"]+values["rcvd"]
       pctg = (t*100)/maxval

       if(not(values["client.private"])
       and not(values["server.private"])
    and not(isBroadMulticast(values["client"])) 
 and not(isBroadMulticast(values["server"]))) then
	  if((pctg >= min_threshold)
	  and (values["client.latitude"] ~= nil)
       and (values["client.longitude"] ~= nil)) then 
	     if(num > 0) then print(",") end
	     print('\n{\n"host":\n[	\n{\n')
	     print('"lat": '..values["client.latitude"]..',\n')
	     print('"lng": '..values["client.longitude"]..',\n')

	     print('"html": "')
	     if((values["client.city"] ~= nil) and (values["client.city"] ~= "")) then
		print('City: '..values["client.city"])
	     end

	     print(getFlag(values["country"]))
	     print('",\n')

	     print('"name": "'..values["client"].."@"..values["client.vlan"]..'"\n')
	     print('},\n{\n')
	     print('"lat": '..values["server.latitude"]..',\n')
	     print('"lng": '..values["server.longitude"]..',\n')
	     
	     print('"html": "')
	     if((values["server.city"] ~= nil) and (values["server.city"] ~= "")) then
		print('City: '..values["server.city"])
	     end
	     print(getFlag(values["server.country"]))
	     print('",\n')

	     print('"name": "'..values["server"].."@"..values["client.vlan"]..'"\n')
	     print('}\n],\n"flusso": '.. pctg..',"html":"Flow '.. key .. '"\n')
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