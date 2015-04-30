--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)

host = _GET["host"]

flows_stats = interface.getFlowsInfo()

client_ports = { }
server_ports = { }

for key, value in pairs(flows_stats) do
    if((host == nil) or (flows_stats[key]["cli.ip"] == host)) then
     	p = flows_stats[key]["cli.port"]
	if(client_ports[p] == nil) then client_ports[p] = 0 end
        client_ports[p] = client_ports[p] + flows_stats[key]["bytes"]
    end
    if((host == nil) or (flows_stats[key]["srv.ip"] == host)) then
     	p = flows_stats[key]["srv.port"]
	if(server_ports[p] == nil) then server_ports[p] = 0 end
        server_ports[p] = server_ports[p] + flows_stats[key]["bytes"]
    end
end

if(_GET["mode"] == "server") then
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
