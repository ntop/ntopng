--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "flow_utils"
require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Return graph (sankey) data for active flows
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/flow/graph.lua
--

local flows_filter = getFlowsFilter()
local rc = rest_utils.consts.success.ok

local ifid = _GET["ifid"]
local tracked_host = _GET["host"]
local sankey_version = _GET["sankey_version"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local max_num_peers = 100
local max_num_links = 32
local peers = getTopFlowPeers(tracked_host, max_num_peers, true --[[ high details for cli2srv.last/srv2cli.last fields ]])
local is_pcap_dump = interface.isPcapDumpInterface()
local debug = false

-- In community version, due to dimension problems, restricting to 16 links
if not ntop.isPro() then
   max_num_links = 16
end

-- 1. compute total traffic
local total_traffic = 0

for _, values in ipairs(peers) do
   local key
   local bytes
   if(values["cli.ip"] == tracked_host) then
      key = hostinfo2hostkey(values, "srv")
   else
      key = hostinfo2hostkey(values, "cli")
   end

   if is_pcap_dump then
      bytes = values["bytes"]
   else
      bytes = values["bytes.last"]
   end

   total_traffic = total_traffic + bytes
   if(debug) then io.write("->"..key.."\t[".. (values["bytes.last"]) .."][".. values["duration"].."]" .. "\n") end
end

if(debug) then io.write("\n") end

-- 2. compute flow threshold under which we do not add any relation
local threshold
if(tracked_host == nil) then
   threshold = (total_traffic * 3) / 100
else
   threshold = 1
end

if(debug) then io.write("\nThreshold: "..threshold.."\n") end

-- map host -> incremental number

local hosts = {}
local num = 0

local nodes = {}

-- fills hosts table with available hosts
while(num == 0) do
   for _, values in ipairs(peers) do
      local key
      if(values["cli.ip"] == tracked_host) then
	 key = hostinfo2hostkey(values, "srv")
      else
	 key = hostinfo2hostkey(values, "cli")
      end

      local bytes
      if(values["bytes.last"] == 0 and values.duration < 3) or is_pcap_dump then
	 bytes = values["bytes"]
      else
         bytes = values["bytes.last"]
      end

      if(bytes > threshold) then
	 if(debug) then io.write("==>" .. key .. "\t[T:" .. tracked_host .. "][" .. values["duration"] .. "][" .. bytes .. "]\n") end
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

	    -- for each cli, srv
	    for k, word in pairs(k) do
	       if(hosts[word] == nil) then
		  hosts[word] = num

		  host_info = hostkey2hostinfo(word)

		  -- 3. add node
		  local hinfo = hostkey2hostinfo(word)
		  name = hostinfo2label(hinfo)

                  nodes[#nodes + 1] = {
                     -- sankey_version == 3
                     node_id = #nodes,
                     label = name,
                     link = ntop.getHttpPrefix() .. "/lua/host_details.lua?" .. hostinfo2url(host_info),

                     -- old version
                     name = name,
                     host = host_info["host"],
                     vlan = host_info["vlan"]
                  }

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
   --     Then we take the host with most traffic and add flows belonging to it

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

      nodes[#nodes + 1] = {
         -- sankey_version == 3
         node_id = #nodes,
         label = top_host,
         link = "#",

         -- old version
         name = top_host,
         host = host_info["host"],
         vlan = host_info["vlan"]
      }

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

		  -- 3. add host
                  nodes[#nodes + 1] = {
                     -- sankey_version == 3
                     node_id = #nodes,
                     label = word,
                     link = "#",

                     -- old version
                     name = word,
                     host = host_info["host"],
                     vlan = host_info["vlan"]
                  }

		  num = num + 1
	       end --if
	    end -- for
	 end -- if
      end -- for
   end -- if
end -- if

-- 4. compute links

local links = {}
num = 0

-- Avoid to have a link A->B, and B->A
local reverse_nodes = {}
for _, values in ipairs(peers) do
   local key = {hostinfo2hostkey(values, "cli"), hostinfo2hostkey(values, "srv")}  --string.split(key, " ")
   local val
   if is_pcap_dump then
     val = values["bytes"]
   else
     val = values["bytes.last"]
   end

   if(((val == 0) or (val > threshold)) or ((top_host ~= nil) and (findString(table.concat(key, " "), top_host) ~= nil)) and (num < max_num_links)) then
      e = {}
      id = 0
      for k, word in pairs(key) do
	 e[id] = hosts[word]
	 id = id + 1
      end

      if((e[0] ~= nil) and (e[1] ~= nil) and (e[0] ~= e[1]) and (reverse_nodes[e[0]..":"..e[1]] == nil)) then

	 reverse_nodes[e[1]..":"..e[0]] = 1

         if is_pcap_dump then
	    sentv = values["cli2srv.last"]
	    recvv = values["srv2cli.last"]
         else
	    sentv = values["cli2srv.bytes"]
	    recvv = values["srv2cli.bytes"]
         end

	 if(val == 0) then
	    val = 1
	 end

         links[#links+1] = {
            -- sankey_version == 3
            source_node_id = tostring(e[0]),
            target_node_id = tostring(e[1]),
            label = "",
            optional_info = {
               link_color = "",
               link = "#"
            },

            -- common
            value = val,

            -- old version
	    source = e[0],
            target = e[1],
            sent = sentv,
            rcvd = recvv
         }

	 num = num + 1
      end
   end

end

local res = {
   nodes = nodes,
   links = links,
   max_entries_reached = true
}

rest_utils.answer(rc, res)
