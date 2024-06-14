--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local callback_utils = require "callback_utils"
local rest_utils = require("rest_utils")

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)


local response = {}
local host_key = _GET["host"] 
local hosts_category = _GET["hosts_category"] or ""

local host_info = url2hostinfo(_GET)

local MAX_HOSTS = 512

local pref_prefix = "ntopng.prefs."

local bytes_sent = "bytes.sent"
local bytes_rcvd = "bytes.rcvd"

-- Extra info, enabled by the preferences (Settings->Preferences->Geo Map),
-- that are going to add more info to the host detailed view into the Geo Map
local extra_info = {
	score  					= { pref = ntop.getPref(pref_prefix .. "is_geo_map_score_enabled") },
	asname					= { pref = ntop.getPref(pref_prefix .. "is_geo_map_asname_enabled") },
	active_alerted_flows 	= { pref = ntop.getPref(pref_prefix .. "is_geo_map_alerted_flows_enabled") },
	num_blacklisted_flows	= { pref = ntop.getPref(pref_prefix .. "is_geo_map_blacklisted_flows_enabled"), values = { "tot_as_server", "tot_as_client" } },
	name 					= { pref = ntop.getPref(pref_prefix .. "is_geo_map_host_name_enabled") },
	total_flows 			= { pref = ntop.getPref(pref_prefix .. "is_geo_map_num_flows_enabled"), values = { "as_client", "as_server" } },
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

local function handlePeer(host_key)
	local host_data = interface.getHostInfo(host_key)

    return host_data
end

-- ##############

-- Function to get hosts data based on hosts category filter -> numerical value as describe in the if below
local function show_hosts(hosts_count, host_key, hosts_category)
    local hosts = {}
    local num_hosts = 0
	local data = {}
	
	-- Get single host data (host_key is the requested IP)
	if (host_key) then
		-- From req create a table
		local host_info = url2hostinfo(_GET)
		local flows = getTopFlowPeers(hostinfo2hostkey(host_info), MAX_HOSTS - hosts_count, nil, { detailsLevel = "max" })
		
		data.hosts = {}

		for key, value in pairs(flows) do
			
			-- create table for client IP
			local h = handlePeer(value["cli.ip"])
			if h ~= nil then
				data.hosts[value["cli.ip"]] = h
			end

			-- create table for server IP
			local h = handlePeer(value["srv.ip"])
			if h ~= nil then
				data.hosts[value["srv.ip"]] = h
			end

		end
		
	-- Active hosts or Alerted hosts
	elseif ((hosts_category == 0) or (hosts_category == 1)) then
        data = interface.getHostsInfo()
	
	-- Local hosts
	elseif hosts_category == 2 then
		data = interface.getLocalHostsInfo()

	-- Remote hosts
	elseif (hosts_category == 3) then
        data = interface.getRemoteHostsInfo()

	-- Invalid category selected
    else
        return hosts 
    end

	if (data ~= nil) and (data["hosts"]) then
		for address, value in pairs(data["hosts"]) do

			if value["latitude"] ~= 0 or value["longitude"] ~= 0 then

				local host = {
					lat = value["latitude"],
					lng = value["longitude"],
					isRoot = false,
					country = value["country"],
					ip = address,
					scoreClient = value["score.as_client"],
					scoreServer = value["score.as_server"],
					numAlerts = value["num_alerts"],
					isAlert = value["num_alerts"] + value["active_alerted_flows"] > 0
				}

				if not isEmptyString(value["city"]) then
					host["city"] = value["city"]
				end

				host = add_extra_info(value, host)

				table.insert(hosts, host)
				num_hosts = num_hosts + 1

				if num_hosts >= MAX_HOSTS then
					return hosts
				end
			end
		end
	
	end

	return hosts
end


local rsp = show_hosts(table.len(response["hosts"]), host_key, tonumber(hosts_category))

rest_utils.answer(rest_utils.consts.success.ok, rsp)
