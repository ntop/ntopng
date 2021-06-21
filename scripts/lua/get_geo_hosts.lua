--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')
interface.select(ifname)

local response = {}
local host_key = _GET["host"] or ""
local host_info = url2hostinfo(_GET)

local MAX_HOSTS = 512

local function is_localizable(host)
   return host and host["ip"] and not host["privatehost"] and not host["is_multicast"] and not host["is_broadcast"] and not isBroadMulticast(host["ip"])
end

local function get_max_bytes_from_peers(peers)
   local max = 0
   for key, value in pairs(peers) do
      if (value["bytes"] > max) then
	 max = value["bytes"]
      end
   end

   return max
end

-- ############################################################

local function handlePeer(prefix, host_key, value)
   if((value[prefix..".latitude"] ~= 0) or (value[prefix..".longitude"] ~= 0)) then
      -- set up the host informations
      local host = {
	 lat = value[prefix..".latitude"],
	 lng = value[prefix..".longitude"],
	 -- isDrawable = not(value[prefix..".private"]),
	 isRoot = (value[prefix..".ip"] == host_key),
	 html = getFlag(value[prefix..".country"]),
	 name = hostinfo2hostkey(value, prefix)
      }

      if not isEmptyString(value[prefix..".city"]) then
	 host["city"] = value[prefix..".city"]
      end

      return(host)
   end

   return(nil)
end


local function handleHost(address, value)
   if((value["latitude"] ~= 0) or (value["longitude"] ~= 0)) then
      -- set up the host informations
      local host = {
	 lat = value["latitude"],
	 lng = value["longitude"],
	 isRoot = false,
	 html = getFlag(value["country"]),
	 name = address
      }

      if not isEmptyString(value["city"]) then
	 host["city"] = value["city"]
      end

      return(host)
   end

   return(nil)
end

-- ##############

local function show_hosts(hosts_count, host_key)
   local hosts = {}
   if((host_key == nil) or (host_key == "")) then
      local what = interface.getPublicHostsInfo(true, "column_traffic", MAX_HOSTS)

      for key,value in pairs(what.hosts) do
	 local h = handleHost(key, value)

	 if(h ~= nil) then table.insert(hosts, h) end
      end
   else
      local what = getTopFlowPeers(hostinfo2hostkey(host_info), MAX_HOSTS - hosts_count, nil, {detailsLevel="max"})
      local keys = {}

      for key, value in pairs(what) do
	 if(keys[value["cli.ip"]] == nil) then
	    local h = handlePeer("cli", host_key, value)

	    keys[value["cli.ip"]] = true
	    if(h ~= nil) then table.insert(hosts, h) end
	 end

	 if(keys[value["srv.ip"]] == nil) then
	    local h = handlePeer("srv", host_key, value)

	    keys[value["srv.ip"]] = true
	    if(h ~= nil) then table.insert(hosts, h) end
	 end
      end
   end

   return(hosts)
end


print(json.encode(show_hosts(table.len(response["hosts"]), host_key)))
