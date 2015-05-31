--
-- (C) 2014-15 - ntop.org
--

-- ########

function updateKey(hash_name, key_name, value) 
  io.write("# "..key_name.." += "..value.."\n")

  if(hash_name[key_name] == nil) then
     hash_name[key_name] = value
  else
     hash_name[key_name] = hash_name[key_name] + value
  end
end

-- ######

function hash2json(hash_name, label) 
  print "[\n"

  n = 0
  for k, v in pairs(hash_name) do
    if(n > 0) then print(',\n') end
    print('{ "label": "'..k..'", "url": "'..label..'='..k..'", "value": '..v..' }\n')
    n = n + 1
  end

  print("]")
end

-- ######

function sliceHash(hash_name, max_num_entries, sort_direction, url, url_trailer)   
  local sortedKeys

  if(sort_direction == "desc") then
    sortedKeys = getKeysSortedByValue(hash_name, function(a, b) return a > b end)
  else
    sortedKeys = getKeysSortedByValue(hash_name, function(a, b) return a < b end)
  end

  print "[\n"
  n = 0

  for _, key in ipairs(sortedKeys) do
     if((max_num_entries > 0) and (n > max_num_entries)) then
        break
     else
        if(url == "") then
          print('{ "label": "'..key..'", "url": "", "value": '..hash_name[key]..' }\n')
        else
          print('{ "label": "'..key..'", "url": "'..url..'='..key..url_trailer..'", "value": '..hash_name[key]..' }\n')
        end
     end
     n = n + 1
  end

  print("]")
end


-- ######

-- host, vlan, unit (bytes/packets), mode (rcvd/sent/both), max_num_entries (10), sort(desc/asc)
function getTalkers(ifname, vlan, unit, mode, max_num_entries, sort_direction)  
   interface.select(ifname)
   hosts_stats = interface.getHostsInfo()   

   hosts = { }
   for key, value in pairs(hosts_stats) do
      skip = false

      io.write(key.."\n")
      if(hosts_stats[key]["ip"] == nil) then
        skip = true
      else
        if(vlan ~= 0) then
          if(hosts_stats[key]["vlan"] ~= vlan) then
	    skip = true
          end
        end
      end

      if(skip == false) then	
      if((mode == "recv") or (mode == "sent")) then
      	v = hosts_stats[key][unit.."."..mode]
      else
        v = hosts_stats[key][unit..".sent"] + hosts_stats[key][unit..".rcvd"]
      end

       updateKey(hosts, key, v)
      end
   end

   sliceHash(hosts, max_num_entries, sort_direction, "/lua/host_details.lua?host", "")
end

-- ########

-- vlan, unit (bytes/packets), mode (rcvd/sent/both), max_num_entries (10), sort(desc/asc)
function getVLANTraffic(ifname, vlan, unit, mode, max_num_entries, sort_direction) 
   interface.select(ifname)
   hosts_stats = interface.getHostsInfo()   

   hosts = { }
   for key, value in pairs(hosts_stats) do
      skip = false

      io.write(key.."\n")
      if(hosts_stats[key]["ip"] == nil) then
        skip = true
      else
        if(vlan ~= 0) then
          if(hosts_stats[key]["vlan"] ~= vlan) then
	    skip = true
          end
        end
      end

      if(skip == false) then	
      if((mode == "recv") or (mode == "sent")) then
      	v = hosts_stats[key][unit.."."..mode]
      else
        v = hosts_stats[key][unit..".sent"] + hosts_stats[key][unit..".rcvd"]
      end

       updateKey(hosts, hosts_stats[key]["vlan"], v)
      end
   end

   sliceHash(hosts, max_num_entries, sort_direction, "", "")
end

-- ########

-- AS, unit (bytes/packets), mode (rcvd/sent/both), max_num_entries (10), sort(desc/asc)
function getASTraffic(ifname, vlan, as, unit, mode, max_num_entries, sort_direction) 
   interface.select(ifname)
   hosts_stats = interface.getHostsInfo()   

   hosts = { }
   for key, value in pairs(hosts_stats) do
      skip = false

      io.write(key.."\n")
      if(hosts_stats[key]["ip"] == nil) then
        skip = true
      else
        if(vlan ~= 0) then
          if(hosts_stats[key]["vlan"] ~= vlan) then
	    skip = true
          end
        end
      end

      if(skip == false) then	
      if((mode == "recv") or (mode == "sent")) then
      	v = hosts_stats[key][unit.."."..mode]
      else
        v = hosts_stats[key][unit..".sent"] + hosts_stats[key][unit..".rcvd"]
      end

       updateKey(hosts, hosts_stats[key]["asn"], v)
      end
   end

   sliceHash(hosts, max_num_entries, sort_direction, "https://www.robtex.com/as/as", ".html")
end

-- host, vlan, unit (bytes/packets), mode (rcvd/sent/both), max_num_entries (10), sort(desc/asc)
function getFlowTalkers(ifname, vlan, unit, mode, max_num_entries, sort_direction) 
   interface.select(ifname)
   hosts_stats = interface.getFlowsInfo()

   hosts = { }
   for key, value in pairs(hosts_stats) do
      skip = false

      if(vlan ~= 0) then
         if(hosts_stats[key]["vlan"] ~= vlan) then
	   skip = true
         end
      end

      if(skip == false) then	
      if(mode == "recv") then
      	updateKey(hosts, hosts_stats[key]["cli.ip"], hosts_stats[key]["srv2cli."..unit])
      	updateKey(hosts, hosts_stats[key]["srv.ip"], hosts_stats[key]["cli2srv."..unit])
      elseif(mode == "sent") then
      	updateKey(hosts, hosts_stats[key]["cli.ip"], hosts_stats[key]["cli2srv."..unit])
      	updateKey(hosts, hosts_stats[key]["srv.ip"], hosts_stats[key]["srv2cli."..unit])
      else
        v = hosts_stats[key]["cli2srv."..unit] + hosts_stats[key]["srv2cli."..unit]
      	updateKey(hosts, hosts_stats[key]["cli.ip"], v)
      	updateKey(hosts, hosts_stats[key]["srv.ip"], v)
      end
      end
   end

   for k, v in pairs(hosts) do
     io.write(k.."="..v.."\n")
   end

end

