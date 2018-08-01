--
-- (C) 2017-18 - ntop.org
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

if ntop.isnEdge() then
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path
end

require "lua_utils"
local json = require "dkjson"
local host_pools_utils = require "host_pools_utils"
local users_utils = require("users_utils")
local shaper_utils

if(ntop.isPro()) then
   shaper_utils = require "shaper_utils"
end

local http_bridge_conf_utils = {}

-- set to a non-empty value to enable HTTP configuration, e.g.,
-- http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL = "localhost:8000"
http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL = ""

function http_bridge_conf_utils.configureBridge()
   if not isEmptyString(http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL) then
      -- CLEANUP
      local users_list = ntop.getUsers()
      for key, value in pairs(users_list) do
	 if value["group"] == "captive_portal" then
	    ntop.deleteUser(key)
	 end
      end
      shaper_utils.clearShapers()
      host_pools_utils.clearPools()

      -- BASIC INITIALIZATION
      host_pools_utils.initPools()
      shaper_utils.initShapers()

      -- RETRIEVE BRIDGE CONFIGURATION
      -- EXAMPLE RESPONSE STRUCTURE:
      local rsp = {
	 -- ["users"] = {
	 --    ["maina"] = {
	 --       ["full_name"] = "Maina Fast",
	 --       ["password"] = "ntop0101",
	 --       ["default_policy"] = "pass",
	 --       ["policies"] = {
	 -- 	  [10] = "slow_pass", ["Facebook"] = "slower_pass",  ["YouTube"] = "drop"
	 --       }
	 --    },
	 --    ["simon"] = {
	 --       ["full_name"] = "Simon Speed",
	 --       ["password"] = "ntop0202",
	 --       ["default_policy"] = "drop",
	 --       ["policies"] = {
	 -- 	  ["MyCustomProtocol"]="pass", [20] = "slow_pass", [22] = "slower_pass"
	 --       }
	 --    }
	 -- }
      }
      local rsp = ntop.httpGet(http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL)

      if rsp == nil then
	 host_pools_utils.traceHostPoolEvent(TRACE_ERROR, "Unable to obtain a valid configuration from "..http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL)
	 return
      end

      if rsp["CONTENT"] then rsp = rsp["CONTENT"] end
      if not rsp then rsp = {} end

      if type(rsp) == "string" then
	 rsp = json.decode(rsp)

	 if rsp == nil then
	    print("Unable to decode response as valid JSON")
	 end
      end

      local ndpi_protocols = {}
      for proto_name, proto_id in pairs(interface.getnDPIProtocols()) do
	 -- case-insensitive
	 ndpi_protocols[string.lower(proto_name)] = proto_id
      end

      local nedge_shapers = {}
      for _, shaper in ipairs(shaper_utils.nedge_shapers) do
	 nedge_shapers[string.lower(shaper.name)] = shaper
      end
      
      -- FOR EACH INTERFACE...
      for _, ifname in pairs(interface.getIfNames()) do
	 interface.select(ifname)
	 local ifid = getInterfaceId(ifname)

	 -- SETUP HOST POOLS
	 for username, user_config in pairs(rsp["users"] or {}) do
            if username ~= host_pools_utils.DEFAULT_POOL_NAME then
              users_utils.addUserIfNotExists(ifid, username, user_config["password"] or "", user_config["full_name"] or "")
            end

	    local pool_id = host_pools_utils.usernameToPoolId(username) or host_pools_utils.DEFAULT_POOL_ID
	    host_pools_utils.traceHostPoolEvent(TRACE_NORMAL, ifname..": creating user: "..username.. " pool id: "..pool_id)

	    if not isEmptyString(user_config["default_policy"]) then
	       local default_policy = string.lower(user_config["default_policy"])

	       if nedge_shapers[default_policy] and default_policy ~= "default" then -- default can't be default :)
		  shaper_utils.setPoolShaper(ifid, pool_id, nedge_shapers[default_policy].id)
	       end

	       for proto, policy in pairs(user_config["policies"] or {}) do
		  policy = nedge_shapers[string.lower(policy)]

		  if tonumber(proto) == nil then
		     proto = ndpi_protocols[string.lower(proto)]
		  end

		  if policy and tonumber(proto) ~= nil then
		     if (policy.name == "DEFAULT") and no_quota then
			shaper_utils.deleteProtocol(ifid, pool_id, proto)
		     else
			shaper_utils.setProtocolShapers(ifid, pool_id, proto,
							policy.id, policy.id,
							0 --[[traffic_quota--]], 0--[[time_quota--]])
			-- tprint({proto=proto, name = interface.getnDPIProtoName(tonumber(proto)), pool_id=pool_id, policy_id=policy.id})
		     end
		  end
	       end
	    end
	 end

	 -- must leave it here as well to make sure the C part has updated with the new pools
	 interface.reloadHostPools()

	 -- SETUP ASSOCIATIONS
	 for member, info in pairs(rsp["associations"] or {}) do
	    local pool = info["group"]
	    local connectivity = info["connectivity"]

	    local pool_id = host_pools_utils.usernameToPoolId(pool)

	    if pool == host_pools_utils.DEFAULT_POOL_NAME then
	       host_pools_utils.traceHostPoolEvent(TRACE_ERROR, ifname..": members are associated automatically with default pool "..host_pools_utils.DEFAULT_POOL_NAME.." skipping association with member: "..member)
	    elseif not pool_id then
	       host_pools_utils.traceHostPoolEvent(TRACE_ERROR, ifname..": pool: "..pool.. " not existing. Unable to set association with: "..member)
	    else
	       if connectivity == "pass" then
		  if host_pools_utils.addPoolMember(ifid, pool_id, member) == true then
		     host_pools_utils.traceHostPoolEvent(TRACE_NORMAL, ifname..": member  "..member.. " successfully associated to pool: "..pool)
		  else
		     host_pools_utils.traceHostPoolEvent(TRACE_ERROR, ifname..": Unable to associate member "..member.. " to pool: "..pool)
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
