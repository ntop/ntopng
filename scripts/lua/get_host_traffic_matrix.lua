--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
--require "dumper"

--function dump(...)
--  print(DataDumper(...), "\n---")
--end

interface.select(ifname)

num_top_hosts = 10

if(host_ip == nil) then
   host_ip = _GET["host"]
   num = 1
else
   hosts = interface.getHostsInfo()
   num = 0
   --[[key ritorna ip computer]]--
   --[[value e sempre null]]--
   for key, value in pairs(hosts) do
      num = num + 1
   end
end

print ('{"data":{"links":[ ')
--[[ Link ]]--

if(host_ip == nil) then
   hosts_stats = getTopInterfaceHosts(num_top_hosts, true)
else
   hosts_stats = {}
   hosts_stats[host_ip] = 1
end

hosts_id = {} --[[Tutti gli host trovati]]--
ids = {}
num = 0 --[[Numero di host trovati]]--
links = 0
local host

--[[Itero per tutti gli host]]--
for key,_ in pairs(hosts_stats) do --[[key ritorna ip computer]]--
   
   host = interface.getHostInfo(key)
   --dump(host)  

   if(host ~= nil) then
	 

	 if(hosts_id[key] == nil) then --[[se host di indice key e vuoto lo inizializzo]]--
	    hosts_id[key] = { }
	    hosts_id[key]['count'] = 0
	    hosts_id[key]['id'] = num
	    ids[num] = key
	    key_id = num
	    num = num + 1
	 else
	    key_id = hosts_id[key]['id']
	 end
	 
	 --[[Itero tutti i contatti di tipo client]]--
	 if(host["contacts"]["client"] ~= nil) then 
	    for k,v in pairs(host["contacts"]["client"]) do
        if((host_ip ~= nil) or isLocal(k)) then
          if(hosts_id[k] == nil) then
            hosts_id[k] = { }
            hosts_id[k]['count'] = 0
            hosts_id[k]['id'] = num
            ids[num] = k
            peer_id = num
            num = num + 1
          else
            peer_id = hosts_id[k]['id']
          end
          
          hosts_id[key]['count'] = hosts_id[key]['count'] + v

          if(links > 0) then print(",") end
          print('\n\t{ "source":'..key_id..', "source_ip":"'..key..'", "target":'..peer_id..', "target_ip":"'..k..'", "value":'..v..' }')
          links = links + 1
        end
	    end
	 end
	 
	 --[[Itero tutti i contatti di tipo server ]]--
	 if(host["contacts"]["server"] ~= nil) then
	    for k,v in pairs(host["contacts"]["server"]) do 
	    if((host_ip ~= nil) or isLocal(k)) then
	       if(hosts_id[k] == nil) then
		  hosts_id[k] = { }
		  hosts_id[k]['count'] = 0
		  hosts_id[k]['id'] = num
		  ids[num] = k
		  peer_id = num
		  num = num + 1
	       else
		  peer_id = hosts_id[k]['id']
	       end
	       hosts_id[key]['count'] = hosts_id[key]['count'] + v
	       if(links > 0) then print(",") end
	       print('\n\t{ "source":'..key_id..', "source_ip":"'..key..'", "target":'..peer_id..', "target_ip":"'..k..'", "value":'..v..' }')
	       links = links + 1
	    end
	 end
      end
   end
end

if(false) then
   aggregation_ids = {}
   if(host_ip ~= nil) then
      aggregations = interface.getAggregationsForHost(host_ip)
   else
      aggregations = {}
   end
   
   for name,num_contacts in pairs(aggregations) do
      aggregation_ids[name] = num
      hosts_id[name] = { }
      hosts_id[name]['count'] = num_contacts
      hosts_id[name]['id'] = num
      ids[num] = name
      if(links > 0) then print(",") end
      print('\n\t{ "source":'..num..', "target": 0, "value":'..num_contacts..', "styleColumn":"aggregation" }')
      links = links + 1
      num = num + 1
   end
end

tot_hosts = num

print('\n],"nodes":[')

--[[ Nodi ]]--

min_size = 5
maxval = 0
for k,v in pairs(hosts_id) do 
   if(v['count'] > maxval) then maxval = v['count'] end
end

num = 0
for i=0,tot_hosts-1 do
   k = ids[i]
   v = hosts_id[k]
   
   target_host = interface.getHostInfo(k)
   
   if(target_host ~= nil) then 
      name = target_host["name"] 
      if(name ~= nil) then 
	 name = name
      else
	 name = ntop.getResolvedAddress(k)
      end
      if(target_host['localhost'] ~= nil) then label = "local" else label = "remote" end 
      v['sent'] = target_host['packets.sent'] and target_host['packets.sent'] or 0
      v['rcvd'] = target_host['packets.rcvd'] and target_host['packets.rcvd'] or 0       
   else
      v['sent'] = 0
      v['rcvd'] = 0
      name = k
      if(aggregations[k] ~= nil) then
	 label = "aggregation"
      else
	 label = "remote"
      end
   end
   
   if((host_ip ~= nil) and (host_ip == k)) then label = "sun" end
   -- f(name == k) then name = ntop.getResolvedAddress(k) end
   if(name == nil) then name = k end
   if(maxval == 0) then 
      tot = maxval
   else
      tot = math.floor(0.5+(v['count']*100)/maxval) 
      if(tot < min_size) then tot = min_size end
   end
   
   if(num > 0) then print(",") end
   print('\n\t{"name":"'.. name ..'", "count":'..v['count']..', "count_perc":'.. tot ..', "group":"' .. label .. '", "label":"'.. name..'", "sent":'..v['sent']..', "rcvd":'..v['rcvd']..',"tot":'..v['sent']+v['rcvd']..' }')
   
   num = num + 1
end

if((num == 0) and (host_ip ~= nil)) then
   tot = 1
   label = ""
   
   print('\n\t{"name":"'.. host_ip ..'", "count":'..v['count']..'", "count_perc":'.. tot ..', "group":"' .. label .. '", "label":"'.. host_ip..'", "sent":'..v['sent']..', "rcvd":'..v['rcvd']..',"tot":'..v['sent']+v['rcvd']..' }')
end
print ('\n]}}')
