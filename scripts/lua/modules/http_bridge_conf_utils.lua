--
-- (C) 2017-22 - ntop.org
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
local host_pools_nedge = require "host_pools_nedge"
local users_utils = require("users_utils")
local shaper_utils

if(ntop.isPro()) then
   shaper_utils = require "shaper_utils"
end

local http_bridge_conf_utils = {}

-- set to a non-empty value to enable HTTP configuration, e.g.,
--http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL = "localhost:8000"
http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL = ""

function http_bridge_conf_utils.configureBridge()
   if not isEmptyString(http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL) then
      -- CLEANUP
      shaper_utils.clearShapers()
      -- empty pool members but don't delete pools
      host_pools_nedge.emptyPools()

      -- BASIC INITIALIZATION
      host_pools_nedge.initPools()
      shaper_utils.initShapers()

      -- RETRIEVE BRIDGE CONFIGURATION
      -- EXAMPLE RESPONSE STRUCTURE:
      local rsp = {
	 -- ["users"] = {
         --    ["Not Assigned"] = {
	 --       ["default_policy"] = "drop",
         --       ["policies"] = {
	 -- 	     ["ConnectivityCheck"] = "pass"
	 --       }
	 --    },
	 --    ["guest"] = {
	 --       ["full_name"] = "Guest Users",
	 --       ["password"] = "ntop0101",
	 --       ["default_policy"] = "pass",
	 --       ["policies"] = {
	 -- 	     [10] = "slow_pass", ["Facebook"] = "slower_pass",  ["YouTube"] = "drop"
	 --       }
	 --    },
	 --    ["iot"] = {
	 --       ["full_name"] = "IoT Devices",
	 --       ["password"] = "ntop0202",
	 --       ["default_policy"] = "drop",
	 --       ["policies"] = {
	 -- 	     ["MyCustomProtocol"]="pass", [20] = "slow_pass", [22] = "slower_pass"
	 --       }
	 --    }
	 -- }
      }
      local rsp = ntop.httpGet(http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL)

      if rsp == nil then
	 host_pools_nedge.traceHostPoolEvent(TRACE_ERROR, "Unable to obtain a valid configuration from "..http_bridge_conf_utils.HTTP_BRIDGE_CONFIGURATION_URL)
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

      -- Read supported protocols
      local ndpi_protocols = {}
      for proto_name, proto_id in pairs(interface.getnDPIProtocols()) do
	 -- case-insensitive
	 ndpi_protocols[string.lower(proto_name)] = proto_id
      end

      -- Read supported categories
      local ndpi_categories = {}
      for cat_name, cat_id in pairs(interface.getnDPICategories()) do
	 ndpi_categories[string.lower(cat_name)] = cat_id
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
            if username ~= host_pools_nedge.DEFAULT_POOL_NAME then
              users_utils.addUserIfNotExists(ifid, username, user_config["password"] or "", user_config["full_name"] or "")
            end

	    local pool_id = host_pools_nedge.usernameToPoolId(username) or host_pools_nedge.DEFAULT_POOL_ID

	    host_pools_nedge.traceHostPoolEvent(TRACE_NORMAL, ifname..": creating user: "..username.. " pool id: "..pool_id)

	    if not isEmptyString(user_config["routing_policy"]) then
               local routing_policy_id = host_pools_nedge.routingPolicyNameToId(user_config["routing_policy"])
               host_pools_nedge.setRoutingPolicyId(pool_id, routing_policy_id)
	    end

	    if not isEmptyString(user_config["default_policy"]) then
	       local default_policy = string.lower(user_config["default_policy"])

	       if nedge_shapers[default_policy] and default_policy ~= "default" then -- default can't be default :)
		  host_pools_nedge.traceHostPoolEvent(TRACE_NORMAL, ifname..": setting default policy '"..default_policy.."' for user: "..username.. " pool id: "..pool_id)
		  shaper_utils.setPoolShaper(ifid, pool_id, nedge_shapers[default_policy].id)
	       end

	       for proto, policy in pairs(user_config["policies"] or {}) do
		  local proto_name = proto
		  local proto_id_or_category = proto

		  policy = nedge_shapers[string.lower(policy)]

		  if tonumber(proto_id_or_category) == nil then
		     -- proto_id_or_category is not a proto id, check for proto name or category
		     local lowercase_name = string.lower(proto)

		     if ndpi_protocols[lowercase_name] then
			proto_id_or_category = ndpi_protocols[lowercase_name]
			proto_name = string.format("Protocol %s/%d", proto, ndpi_protocols[lowercase_name])
		     elseif ndpi_categories[lowercase_name] then
                        proto_id_or_category = "cat_"..ndpi_categories[lowercase_name]
			proto_name = string.format("Category %s/%d", proto, ndpi_categories[lowercase_name])
		     else
			host_pools_nedge.traceHostPoolEvent(TRACE_ERROR, ifname..": unable to find protocol '"..proto.."' among known protocols for user: "..username.. " pool id: "..pool_id)
                        proto_id_or_category = nil
		     end
		  end

		  if policy and proto_id_or_category then
		     if (policy.name == "DEFAULT") and no_quota then
			shaper_utils.deleteProtocol(ifid, pool_id, proto_id_or_category)
		     else
			shaper_utils.setProtocolShapers(ifid, pool_id, proto_id_or_category,
							policy.id, policy.id,
							0 --[[traffic_quota--]], 0--[[time_quota--]])
			host_pools_nedge.traceHostPoolEvent(TRACE_NORMAL, ifname..": setting '"..proto_name.."' policy '"..policy.name.."' for user: "..username.. " pool id: "..pool_id)
		     end
		  end
	       end
	    end
	 end

	 -- must leave it here as well to make sure the C part has updated with the new pools
	 ntop.reloadHostPools()

	 -- SETUP ASSOCIATIONS
	 for member, info in pairs(rsp["associations"] or {}) do
	    local pool = info["group"]
	    local connectivity = info["connectivity"]

	    local pool_id = host_pools_nedge.usernameToPoolId(pool)

	    if pool == host_pools_nedge.DEFAULT_POOL_NAME then
	       host_pools_nedge.traceHostPoolEvent(TRACE_ERROR, ifname..": members are associated automatically with default pool "..host_pools_nedge.DEFAULT_POOL_NAME.." skipping association with member: "..member)
	    elseif not pool_id then
	       host_pools_nedge.traceHostPoolEvent(TRACE_ERROR, ifname..": pool: "..pool.. " not existing. Unable to set association with: "..member)
	    else
	       if connectivity == "pass" then
		  if host_pools_nedge.addPoolMember(pool_id, member) == true then
		     host_pools_nedge.traceHostPoolEvent(TRACE_NORMAL, ifname..": member  "..member.. " successfully associated to pool: "..pool)
		  else
		     host_pools_nedge.traceHostPoolEvent(TRACE_ERROR, ifname..": Unable to associate member "..member.. " to pool: "..pool)
		  end
	       end
	    end
	 end
      end

      ntop.reloadHostPools()
   end

end

return http_bridge_conf_utils

-- ######################################################################################
-- ######################################################################################
-- ######################################################################################
