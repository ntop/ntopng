--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/json')

interface.select(ifname)
local flows_stats = interface.getFlowsInfo()
flows_stats = flows_stats["flows"]

local debug = false
local httpdocs = dirs.installdir..'/httpdocs'
local icon_root = ntop.getHttpPrefix() .. '/img/interaction-graph-icons/'
local icon_extension = '.png'
links = {}

function get_icon_url(name)
   local icon_url = icon_root..name..icon_extension
   if (ntop.exists(httpdocs..icon_url)) then return icon_url else return '' end
end

is_loopback = isLoopback(ifname)

for key, value in ipairs(flows_stats) do
   -- Find client and server name
   srv_name = flows_stats[key]["srv.host"]
   if((srv_name == "") or (srv_name == nil)) then
      srv_name = flows_stats[key]["srv.ip"]
   end
   srv_name = getResolvedAddress(hostkey2hostinfo(srv_name))

   cli_name = flows_stats[key]["cli.host"]
   if((cli_name == "") or (cli_name == nil)) then
      cli_name = flows_stats[key]["cli.ip"]
   end
   cli_name = getResolvedAddress(hostkey2hostinfo(cli_name))

   -- consider only full meshed connections
   if((flows_stats[key]["client_process"] ~= nil) or (flows_stats[key]["system_process"] ~= nil) ) then
      -- Get client and server information
      if (flows_stats[key]["client_process"] ~= nil) then 
	 if(is_loopback) then
	    client_id = flows_stats[key]["cli.source_id"]..'-localhost-'..flows_stats[key]["client_process"]["pid"]
	 else
	    client_id = flows_stats[key]["cli.source_id"]..'-'..flows_stats[key]["cli.ip"]..'-'..flows_stats[key]["client_process"]["pid"]
	 end
	 client_name = flows_stats[key]["client_process"]["name"]
	 client_type = "syshost"
      else
	 client_id = flows_stats[key]["cli.source_id"]..'-'..flows_stats[key]["cli.ip"]
	 client_name = shortenString(cli_name)
	 client_type = "host"
      end

      if (flows_stats[key]["server_process"] ~= nil) then 
	 if(is_loopback) then
	    server_id = flows_stats[key]["srv.source_id"]..'-localhost-'..flows_stats[key]["server_process"]["pid"]
	 else
	    server_id = flows_stats[key]["srv.source_id"]..'-'..flows_stats[key]["srv.ip"]..'-'..flows_stats[key]["server_process"]["pid"]
	 end
	 server_name = flows_stats[key]["server_process"]["name"]
	 server_type = "syshost"
      else
	 server_id = flows_stats[key]["srv.source_id"]..'-'..flows_stats[key]["srv.ip"]
	 server_name = shortenString(srv_name)
	 server_type = "host"
      end

      -- Create link key (0-127.0.0.1-24829-chromium-browser:0-127.0.0.1-29911-ntopng)
      key_link = client_id.."-"..client_name..":"..server_id.."-"..server_name
      if (debug) then io.write("Link key:"..key_link.."\n") end
      if (links[key_link] == nil) then
	 -- Init links whit default values
	 links[key_link] = {};
	 links[key_link]["client_id"] = client_id
	 links[key_link]["client_system_id"] = flows_stats[key]["cli.source_id"];
	 links[key_link]["client_name"] = client_name
	 links[key_link]["client_type"] = client_type
	 links[key_link]["server_id"] = server_id
	 links[key_link]["server_system_id"] = flows_stats[key]["srv.source_id"];
	 links[key_link]["server_name"] = server_name
	 links[key_link]["server_type"] = server_type
	 -- Init Links aggregation values
	 links[key_link]["bytes"] = flows_stats[key]["bytes"]
	 links[key_link]["srv2cli.bytes"] = flows_stats[key]["srv2cli.bytes"]
	 links[key_link]["cli2srv.bytes"] = flows_stats[key]["cli2srv.bytes"]
      else
	 -- Aggregate values
	 links[key_link]["bytes"] = links[key_link]["bytes"] + flows_stats[key]["bytes"]
	 links[key_link]["cli2srv.bytes"] = links[key_link]["cli2srv.bytes"] + flows_stats[key]["cli2srv.bytes"]
	 links[key_link]["srv2cli.bytes"] = links[key_link]["srv2cli.bytes"] + flows_stats[key]["srv2cli.bytes"]
      end
   end    
end 


print('[\n')

-- Create link (flows)

local num = 0
for key, value in pairs(links) do
   link = links[key]
   process = 1

   -- Condition

   -- if ((flows_stats[key]["server_process"] == nil) or 
   --   (flows_stats[key]["client_process"] == nil)) then 
   --   process = 0
   -- end


   -- Get information
   if(process == 1) then
      if (num > 0) then print(',\n') end

      print('{'..
	       '\"client\":\"'           .. link["client_id"]        .. '\",' ..
	       '\"client_system_id\":\"' .. link["client_system_id"] .. '\",' ..
	       '\"client_name\":\"'      .. link["client_name"]      .. '\",' ..
	       '\"client_type\":\"'      .. link["client_type"]      .. '\",' ..
	       '\"client_icon\":\"'      .. get_icon_url(link["client_name"]) .. '\",' ..
	       '\"server\":\"'           .. link["server_id"]        .. '\",' ..
	       '\"server_system_id\":\"' .. link["server_system_id"] .. '\",' ..
	       '\"server_name\":\"'      .. link["server_name"]      .. '\",' ..
	       '\"server_type\":\"'      .. link["server_type"]      .. '\",' ..
	       '\"server_icon\":\"'      .. get_icon_url(link["server_name"]) .. '\",' ..
	       '\"bytes\":'              .. link["bytes"]            .. ','   ..
	       '\"cli2srv_bytes\":'      .. link["cli2srv.bytes"]    .. ','   ..
	       '\"srv2cli_bytes\":'      .. link["srv2cli.bytes"]    ..
	       '}')
      num = num + 1
   end

end

print('\n]')
