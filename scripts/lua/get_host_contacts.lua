--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

currentPage = _GET["currentPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]
protocol_id = _GET["protocol"]
mode        = _GET["mode"]
host        = _GET["host"]
format      = _GET["format"]

if(sortColumn == nil) then
   sortColumn = "column_"
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
end

if((mode == nil) or (mode == "")) then mode = "contacted_peers" end

interface.select(ifname)
hosts_stats = interface.getHostsInfo()
hosts_stats = hosts_stats["hosts"]
host_info = interface.getHostInfo(host)
if(protocol_id == "") then protocol_id = nil end
if(protocol_id ~= nil) then protocol_id = tonumber(protocol_id) end
host_peers = {}


if((protocol_id == nil) or (protocol_id == 65535)) then
   if(host_info.contacts ~= nil) then
      if(host_info["contacts"]["client"] ~= nil) then
	 for k,v in pairs(host_info["contacts"]["client"]) do

	    if(host_peers[k] == nil) then
	       e = {}
	       e['protocol'] = 65535
	       e['num_contacts'] = v
	       host_peers[k] = e
	    else
	       host_peers[k]['num_contacts'] = host_peers[k]['num_contacts'] + v
	    end
	 end
      end

      if(host_info["contacts"]["server"] ~= nil) then
	 for k,v in pairs(host_info["contacts"]["server"]) do
	    if(host_peers[k] == nil) then
	       e = {}
	       e['protocol'] = 65535
	       e['num_contacts'] = v
	       host_peers[k] = e
	    else
	       host_peers[k]['num_contacts'] = host_peers[k]['num_contacts'] + v
	    end
	 end
      end
   end
end

if((protocol_id == nil) or (protocol_id ~= 65535)) then
   hosts_stats = interface.getAggregatedHostsInfo(tonumber(protocol))

   for key, value in pairs(hosts_stats) do
      for k,v in pairs(hosts_stats[key]["contacts"]["client"]) do
	 if(k == host) then 
	

	    if(host_peers[key] == nil) then
	       e = {}
	       e['protocol'] = hosts_stats[key]["family"]
	       e['num_contacts'] = v
	       host_peers[key] = e
	    else
	       host_peers[key]['num_contacts'] = host_peers[key]['num_contacts'] + v
	    end	    
	 end
      end
      
      for k,v in pairs(hosts_stats[key]["contacts"]["server"]) do
	 if(k == host) then 
	

	    if(host_peers[key] == nil) then
	       e = {}
	       e['protocol'] = hosts_stats[key]["family"]
	       e['num_contacts'] = v
	       host_peers[key] = e
	    else
	       host_peers[key]['num_contacts'] = host_peers[key]['num_contacts'] + v
	    end	    
	 end
      end
   end
end

t = os.time()
when = os.date("%y%m%d", t)
base_name = when.."|"..ifname.."|"..host
keyname = base_name.."|"..mode

v1 = ntop.getHashKeysCache(keyname)
if(v1 ~= nil) then
   for k,_ in pairs(v1) do
      v = ntop.getHashCache(keyname, k)

      if(v ~= nil) then
	 --print(k.."\n")

	 values = split(k, "@");
	 name = values[1]
	 protocol = tonumber(values[2])

	 -- 254 is OperatingSystem
	 if(not(protocol == 254)) then
	    if(host_peers[k] == nil) then
	       e = {}
	       e['protocol'] = tonumber(protocol)
	       e['num_contacts'] = v
	       host_peers[name] = e
	    else
	       host_peers[k]['num_contacts'] = host_peers[k]['num_contacts'] + v
	    end
	 end
      end
   end
end

if(format ~= "json") then
   print("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
else
   print("[\n")
end

num = 0
total = 0
to_skip = (currentPage-1) * perPage

now = os.time()
vals = {}
num = 0

--for k,v in pairs(host_peers) do io.write(k.."\n") end
if(protocol_id ~= nil) then protocol_id = tonumber(protocol_id) end
--print(protocol_id)
for key, value in pairs(host_peers) do
   if((protocol_id ~= nil) and (protocol_id ~= tonumber(host_peers[key]["protocol"]))) then
      ok = false
   else
      ok = true
   end

   if(ok) then
      num = num + 1
      postfix = string.format("0.%04u", num)

      if(sortColumn == "column_num_contacts") then
	 vals[tonumber(host_peers[key]["num_contacts"]+postfix)] = key
	 elseif(sortColumn == "column_protocol") then
	 vals[host_peers[key]["protocol"]+postfix] = key
      else
	 vals[key] = key
      end
   end
end

table.sort(vals)

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

if(format == "json") then
   perPage = -1
end

num = 0
for _key, _value in pairsByKeys(vals, funct) do
   key = vals[_key]

   if((key ~= nil) and (not(key == ""))) then
      value = host_peers[key]

      if(to_skip > 0) then
	 to_skip = to_skip-1
      else
	 if((perPage == -1) or (num < perPage)) then
	    if(num > 0) then
	       print ",\n"
	    end

	    print("{ \"column_ip\" : ")
	    info = interface.getHostInfo(key)
	    if(info ~= nil) then
	       print(" \"<A HREF='"..ntop.getHttpPrefix().."/lua/")
	       print("host_details.lua?host=" .. key .. "'>")
	       print(mapOS2Icon(key))
	       print(" </A> ".. getOSIcon(value["os"]))
	       print("&nbsp;"..getFlag(info["country"]).." ")
	       print("\",")
	    else
	       print(" \""..key.."\", ")
	    end

	    print("\"column_name\" : \"")
	    if(value["protocol"] == 65535) then
	       print(getResolvedAddress(hostkey2hostinfo(key)))
	    else
	       print(key)
	    end

	    print("\", \"column_num_contacts\" : "..value["num_contacts"])
	    if tonumber(value["protocol"]) ~= nil then	       
	       -- protocol is numeric
	       p = interface.getnDPIProtoName(value["protocol"])
	    else
	       p = value["protocol"]
	    end
	    print(", \"column_protocol\" : \""..p.."\"")
	    print(" } ")
	    num = num + 1
	 end
      end

      total = total + 1
   end
end -- for

if(format ~= "json") then
   print("\n], \"perPage\" : " .. perPage .. ",\n")

   if(sortColumn == nil) then
      sortColumn = ""
   end

   if(sortOrder == nil) then
      sortOrder = ""
   end

   print("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
   print("\"totalRows\" : " .. total .. " \n}")
else
   print("\n]\n")
end
