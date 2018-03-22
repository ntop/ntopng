--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

tracked_host = _GET["host"]

interface.select(ifname)
max_num_peers = 10
max_num_links = 32

peers = getTopFlowPeers(tracked_host, max_num_peers, true --[[ high details for cli2srv.last/srv2cli.last fields ]])

local debug = false

-- 1. compute total traffic
total_traffic = 0

for _, values in ipairs(peers) do
   local key
   if(values["cli.ip"] == tracked_host) then
      key = hostinfo2hostkey(values, "srv")
   else
      key = hostinfo2hostkey(values, "cli")
   end

   total_traffic = total_traffic + values["bytes.last"]
   if(debug) then io.write("->"..key.."\t[".. (values["bytes.last"]) .."][".. values["duration"].."]" .. "\n") end
end

if(debug) then io.write("\n") end

-- 2. compute flow threshold under which we do not print any relation
if(tracked_host == nil) then
   threshold = (total_traffic * 3) / 100
else
   threshold = 1
end

if(debug) then io.write("\nThreshold: "..threshold.."\n") end

-- map host -> incremental number
hosts = {}
num = 0
print '{"nodes":[\n'

-- print(" >>>[" .. tracked_host .. "]\n")

-- fills hosts table with available hosts and prints out some json code
while(num == 0) do
   for _, values in ipairs(peers) do
      local key
      if(values["cli.ip"] == tracked_host) then
	 key = hostinfo2hostkey(values, "srv")
      else
	 key = hostinfo2hostkey(values, "cli")
      end

      -- print("[" .. key .. "][" .. values["client"] .. ",".. values["client.vlan_id"] .. "][" .. values["server"] .. ",".. values["client.vlan_id"] .. "]\n")
      last = values["bytes.last"]
      if((last == 0) and (values.duration < 3)) then
	 last = values["bytes"]
      end
      if(last > threshold) then

	 if(debug) then io.write("==>"..key.."\t[T:"..tracked_host.. (values["bytes.last"]) .."][".. values["duration"].."][" .. last.. "]\n") end
	 if((debug) and (findString(key, tracked_host) ~= nil))then io.write("findString(key, tracked_host)==>"..findString(key, tracked_host)) end
	 if((debug) and (findString(values["cli.ip"], tracked_host) ~= nil)) then io.write("findString(values[cli.ip], tracked_host)==>"..findString(values["cli.ip"], tracked_host)) end
	 if((debug) and (findString(values["srv.ip"], tracked_host) ~= nil)) then io.write("findString(values[srv.ip], tracked_host)==>"..findString(values["srv.ip"], tracked_host)) end

	 local k = {hostinfo2hostkey(values, "cli"), hostinfo2hostkey(values, "srv")}  --string.split(key, " ")

	 -- Note some checks are redundant here, they are already performed in getFlowPeers
	 if((tracked_host == nil)
   	    or findString(k[1], tracked_host)
            or findString(k[2], tracked_host)
	    or findString(values["cli.ip"], tracked_host) 
	    or findString(values["srv.ip"], tracked_host)) then
	    -- print("[" .. key .. "]")
	    -- print("[" .. tracked_host .. "]\n")

	    -- for each cli, srv
	    for key,word in pairs(k) do
	       if(hosts[word] == nil) then
		  hosts[word] = num

		  if(num > 0) then
		     print ",\n"
		  end

		  host_info = hostkey2hostinfo(word)

		  -- 3. print nodes
		  name = shortHostName(getResolvedAddress(hostkey2hostinfo(word)))

		  print ("\t{\"name\": \"" .. name .. "\", \"host\": \"" .. host_info["host"] .. "\", \"vlan\": \"" .. host_info["vlan"] .. "\"}")
		  num = num + 1
	       end
	    end
	 end
      end
   end

   if(num == 0) then
      -- Lower the threshold to hope finding hosts
      threshold = threshold / 2
   end

   if(threshold <= 1) then
      break
   end
end

top_host = nil
top_value = 0

if ((num == 0) and (tracked_host == nil)) then
   -- 2.1 It looks like in this network there are many flows with no clear predominant traffic
   --     Then we take the host with most traffic and print flows belonging to it

   hosts_stats = interface.getHostsInfo(true, "column_traffic", max_num_peers)
   hosts_stats = hosts_stats["hosts"]
   for key, value in pairs(hosts_stats) do
      value = hosts_stats[key]["traffic"]
      if((value ~= nil) and (value > top_value)) then
	 top_host = key
	 top_value = value
      end -- if
   end -- for

   if(top_host ~= nil) then
      -- We now have have to find this host and some peers
      hosts[top_host] = 0

      host_info = hostkey2hostinfo(top_host)

      print ("{\"name\": \"" .. top_host .. "\", \"host\": \"" .. host_info["host"] .. "\", \"vlan\": \"" .. host_info["vlan"] .. "\"}")
      num = num + 1

      for _, values in ipairs(peers) do
	 local key
	 if(values["cli.ip"] == tracked_host) then
	    key = hostinfo2hostkey(values, "srv")
	 else
	    key = hostinfo2hostkey(values, "cli")
	 end

	 if(findString(key, ip) or findString(values["client"], ip) or findString(values["server"], ip)) then
	    for key,word in pairs(split(key, " ")) do
	       if(hosts[word] == nil) then
		  hosts[word] = num

		  host_info = hostkey2hostinfo(word)

		  -- 3. print nodes
		  print ("{\"name\": \"" .. word .. "\", \"host\": \"" .. host_info["host"] .. "\", \"vlan\": \"" .. host_info["vlan"] .. "\"}")
		  num = num + 1
	       end --if
	    end -- for
	 end -- if
      end -- for
   end -- if
end -- if


print "\n],\n"
print '"links" : [\n'

-- 4. print links
--  print (top_host)
num = 0

-- Avoid to have a link A->B, and B->A
reverse_nodes = {}
for _, values in ipairs(peers) do
   key = {hostinfo2hostkey(values, "cli"), hostinfo2hostkey(values, "srv")}  --string.split(key, " ")
   val = values["bytes.last"]

   if(((val == 0) or (val > threshold)) or ((top_host ~= nil) and (findString(table.concat(key, " "), top_host) ~= nil)) and (num < max_num_links)) then
      e = {}
      id = 0
      --print("->"..key.."\n")
      for key,word in pairs(key) do
	 --print(word .. "=" .. hosts[word].."\n")
	 e[id] = hosts[word]
	 id = id + 1
      end

      if((e[0] ~= nil) and (e[1] ~= nil) and (e[0] ~= e[1]) and (reverse_nodes[e[0]..":"..e[1]] == nil)) then
	 if(num > 0) then
	    print ",\n"
	 end

	 reverse_nodes[e[1]..":"..e[0]] = 1

	 sentv = values["cli2srv.last"]
	 recvv = values["srv2cli.last"]

	 if(val == 0) then
	    val = 1
	 end

	 print ("\t{\"source\": " .. e[0] .. ", \"target\": " .. e[1] .. ", \"value\": " .. val .. ", \"sent\": " .. sentv .. ", \"rcvd\": ".. recvv .. "}")
	 num = num + 1
      end
   end

end



print ("\n]}\n")


