--
-- (C) 2017 - ntop.org
--

-- ######################################################################################
-- ################### HTTP HOST POOLS CONFIGURATION ####################################
-- ######################################################################################

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"
local json = require "dkjson"
local host_pools_utils = require "host_pools_utils"
local shaper_utils

if(ntop.isPro()) then
   shaper_utils = require "shaper_utils"
end

local http_bridge_conf_utils = {}

-- set to a non-empty value to enable HTTP configuration, e.g.,
-- http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL = "localhost:8000"
http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL = "" --localhost:8000"

function http_bridge_conf_utils.configureBridge()
   if not isEmptyString(http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL) then

      -- CLEANUP
      shaper_utils.clearShapers()
      host_pools_utils.clearPools()

      -- BASIC INITIALIZATION
      host_pools_utils.initPools()
      shaper_utils.initShapers()

      -- RETRIEVE BRIDGE CONFIGURATION
      -- EXAMPLE RESPONSE STRUCTURE:
      --[[
	 local rsp = {
	 ["shaping_profiles"] = {
	 ["drop_all"] = {["bw"] = 0}, ["pass_all"] = {["bw"] = -1},
	 ["10Mbps"] = {["bw"] = 10000}, ["20Mbps"] = {["bw"] = 20000}},
	 ["groups"] = {
	 ["maina"] = {["shaping_profiles"] = {["default"]="pass_all", [10] = "10Mbps", ["Facebook"] = "dropAll"}},
	 ["simon"] = {["shaping_profiles"] = {["default"]="drop_all", [20] = "20Mbps", [22] = "10Mbps"}}}
	 }
      --]]
      local rsp = ntop.httpGet(http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL)

      if rsp == nil then
	 print("Unable to obtain a valid configuration from "..conf_url)
      end

      rsp = rsp["CONTENT"] or {}
      rsp = json.decode(rsp, 1)

      if rsp == nil then
	 print("Unable to decode response as valid JSON")
      end

      local bridge_conf = rsp

      -- PREPARE SHAPERS
      local shapers = {}
      local shaper_id = 2 -- 0 and 1 are reserved for the drop-all end pass-all shapers
      if bridge_conf ~= nil and bridge_conf["shaping_profiles"] ~= nil then
	 for shaper_name, shaper in pairs(bridge_conf["shaping_profiles"]) do
            local this_id = shaper_id
	    if shaper["bw"] == -1 then
	      this_id = 0 -- NO LIMIT
	    elseif shaper["bw"] == 0 then
	      this_id = 1 -- DROP ALL
	    else
              shaper_id = shaper_id + 1
	    end
	    shapers[shaper_name] = {bw = shaper["bw"], id = this_id}

	 end
      end

      -- PREPARE HOST POOLS
      local host_pools = {}
      local host_pool_id = host_pools_utils.FIRST_AVAILABLE_POOL_ID
      if bridge_conf ~= nil and bridge_conf["groups"] ~= nil then
	 for pool_name, pool in pairs(bridge_conf["groups"]) do
	    host_pools[pool_name] = pool
	    host_pools[pool_name]["id"] = host_pool_id
	    host_pool_id = host_pool_id + 1
	 end
      end

      -- FOR EACH INTERFACE...
      for _, ifname in pairs(interface.getIfNames()) do
	 interface.select(ifname)
	 local ifid = getInterfaceId(ifname)

	 -- SETUP HOST POOLS
	 for pool_name, pool in pairs(host_pools) do
	    print(ifname..": creating pool "..pool_name)

	    host_pools_utils.createPool(ifid, tostring(pool["id"]), pool_name,
					false --[[children_safe--]], false --[[enforce_quotas_per_pool_member--]])
	    if(interface.isBridgeInterface(ifid) == true) then
	       -- create default shapers
	       shaper_utils.initDefaultShapers(ifid, pool["id"])
	    end
	 end

	 if(interface.isBridgeInterface(ifid) == true) then
	    -- SETUP SHAPERS
	    for shaper_name, shaper in pairs(shapers) do
	       print(ifname..": creating shaper "..shaper_name)

	       shaper_utils.setShaperMaxRate(ifid, shaper["id"], shaper["bw"])
	    end

	    -- SETUP POLICIES
	    local ndpi_protocols = {}
	    for proto_name, proto_id in pairs(interface.getnDPIProtocols()) do
	       -- case-insensitive
	       ndpi_protocols[string.lower(proto_name)] = proto_id
	    end

	    for _, pool in pairs(host_pools) do
	       for proto, shaper in pairs(pool["shaping_profiles"]) do
		  local proto_shaper = shapers[shaper] or {}
		  print(ifname..": setting shaper "..shaper.." for protocol "..proto)

		  -- if proto is a protocol string, e.g., DNS or Google,
		  -- we want to map it to the corresponding nDPI protocol id
		  if proto ~= "default" and tonumber(proto) == nil then 
		     proto = ndpi_protocols[string.lower(proto)]
		     -- tprint({t = type(proto), v = proto})
		  end

		  if proto == "default" or tonumber(proto) ~= nil then
		     shaper_utils.setProtocolShapers(ifid, pool["id"], proto,
						     proto_shaper["id"] or 0, proto_shaper["id"] or 0,
						     0 --[[traffic_quota--]], 0--[[time_quota--]])
		     -- tprint({proto=proto, shaper_name=shaper, shaper=shapers[shaper]})
		  end
	       end
	    end
	 end
      end

      interface.reloadHostPools()
   end

end

return http_bridge_conf_utils

-- ######################################################################################
-- ######################################################################################
-- ######################################################################################
