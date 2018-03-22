--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)

host = _GET["host"]

client_ports = nil
server_ports = nil

function fill_ports_array(field_key, flows_stats, host)
    local ports_array = {}
    for key, value in ipairs(flows_stats) do
      if ((host == nil) or (flows_stats[key][field_key..".ip"] == host)) then
        p = flows_stats[key][field_key..".port"]
        if(ports_array[p] == nil) then ports_array[p] = 0 end
        ports_array[p] = ports_array[p] + flows_stats[key]["bytes"]
      end
    end
    return ports_array
end

if (host == nil) then
  flows_stats = interface.getFlowsInfo()
else
 flows_stats = interface.getFlowsInfo(host)
end
flows_stats = flows_stats["flows"]

client_ports = fill_ports_array("cli", flows_stats, host)
server_ports = fill_ports_array("srv", flows_stats, host)

if(_GET["clisrv"] == "server") then
  ports = server_ports
else
  ports = client_ports
end

_ports = { } 
tot = 0

for k,v in pairs(ports) do
  _ports[v] = k
  tot = tot + v
end

threshold = (tot * 5) / 100

print "[ "

num = 0
accumulate = 0
for key, value in pairsByKeys(_ports, rev) do
      if(key < threshold) then
	 break
      end

      if(num > 0) then
	 print ",\n"
      end

      print("\t { \"label\": \"" .. value .."\", \"value\": ".. key ..", \"url\": \""..ntop.getHttpPrefix().."/lua/port_details.lua?port="..value)

      if(host ~= nil) then 
      print("&host="..host)
      end
      
      print("\" }")

       accumulate = accumulate + key
       num = num + 1

       if(num == max_num_entries) then
	  break
       end      
 end

    -- In case there is some leftover do print it as "Other"
    if(accumulate < tot) then
       if(num > 0) then
	  print (",\n")
       end

       print("\t { \"label\": \"Other\", \"value\": ".. (tot-accumulate) .." }")
    end

if(tot == 0) then
       print("\t { \"label\": \"Other\", \"value\": ".. 0 .." }")
end
    print "\n]"
