--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local callback_utils = require "callback_utils"

sendHTTPHeader('application/json')
interface.select(ifname)

local response = {}
local host_key = _GET["host"] or ""
local host_info = url2hostinfo(_GET)

local MAX_HOSTS = 512

local pref_prefix = "ntopng.prefs."

local bytes_sent = "bytes.sent"
local bytes_rcvd = "bytes.rcvd"

-- Extra info, enabled by the preferences (Settings->Preferences->Geo Map),
-- that are going to add more info to the host detailed view into the Geo Map
local extra_info = {
	score  						= { pref = ntop.getPref(pref_prefix .. "is_geo_map_score_enabled") },
	asname					   = { pref = ntop.getPref(pref_prefix .. "is_geo_map_asname_enabled") },
	active_alerted_flows 	= { pref = ntop.getPref(pref_prefix .. "is_geo_map_alerted_flows_enabled") },
	num_blacklisted_flows	= { pref = ntop.getPref(pref_prefix .. "is_geo_map_blacklisted_flows_enabled"), values = { "tot_as_server", "tot_as_client" } },
	name 							= { pref = ntop.getPref(pref_prefix .. "is_geo_map_host_name_enabled") },
	total_flows 				= { pref = ntop.getPref(pref_prefix .. "is_geo_map_num_flows_enabled"), values = { "as_client", "as_server" } },
}

-- Adding bytes here because they have the '.' inside the name and cannot added therefore above
extra_info[bytes_sent] = { pref = ntop.getPref(pref_prefix .. "is_geo_map_rxtx_data_enabled") }
extra_info[bytes_rcvd] = { pref = ntop.getPref(pref_prefix .. "is_geo_map_rxtx_data_enabled") }

-- ############################################################

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

local function add_extra_info(host_values, host_info)
	for k, v in pairs(extra_info) do
		-- Checking the setting
		if v["pref"] == "1" then
			if not v["values"] then
			-- Only a value, that's the key
				host_info[k] = host_values[k]
			else
			-- Multiple values (e.g. client and server)
				if host_values[k] then
					host_info[k] = 0

					-- Adding all the values into the host_info used by the geo map
					for _, value_subname in pairs(v["values"]) do
						host_info[k] = host_info[k] + host_values[k][value_subname]
					end
				end
			end
		end
	end

	return host_info
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
	 ip = hostinfo2hostkey(value, prefix)
      }

      host = add_extra_info(value, host)

      if not isEmptyString(value[prefix..".city"]) then
	 host["city"] = value[prefix..".city"]
      end

      return(host)
   end

   return(nil)
end

-- ##############

local function show_hosts(hosts_count, host_key)
   local hosts = {}
   local num_hosts = 0

   if((host_key == nil) or (host_key == "")) then
      callback_utils.foreachHost(
	 tostring(interface.getId()),
	 function(address, value)	 	
	    if value["latitude"] ~= 0 or value["longitude"] ~= 0 then
	       -- set up the host informations
	       local host = {
		  lat = value["latitude"],
		  lng = value["longitude"],
		  isRoot = false,
		  html = getFlag(value["country"]),
		  ip = address
	       }

	       if not isEmptyString(value["city"]) then
		  host["city"] = value["city"]
	       end

        	 host = add_extra_info(value, host)

	       table.insert(hosts, host)
	       num_hosts = num_hosts + 1

	       if num_hosts >= MAX_HOSTS then
		  -- Stop the iteration
		  return false
	       end
	    end

	    -- Still room, continue the iteration
	    return true
	 end
      )

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
