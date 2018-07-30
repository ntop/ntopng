--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

--[[ EXAMPLE PAYLOAD:

local ret = {associations = {
		["DE:AD:BE:EE:FF:FF"] = {group = "maina", connectivity = "pass"},
		["AB:AB:AB:AB:AB:AB"] = {group = "simon", connectivity = "reject"}}
	    }
return ret
--]]

local assn = _POST["payload"]
assn = json.decode(assn) or {}
tprint(_POST)
local r = {}
for _, ifname in pairs(interface.getIfNames()) do
   interface.select(ifname)

   local ifid = getInterfaceId(ifname)

   local pools_list = {} 
   for _, pool in pairs(host_pools_utils.getPoolsList(ifid) or {}) do
      pools_list[pool["name"]] = pool
   end

   local res = {associations = assn["associations"]}

   for member, info in pairs(assn["associations"] or {}) do
      local pool = info["group"]
      local connectivity = info["connectivity"]

      host_pools_utils.traceHostPoolEvent(TRACE_NORMAL,
					  string.format("API request. [member: %s][pool: %s][connectivity: %s]", member, pool, connectivity))

      if pools_list[pool] == nil then
	 res["associations"][member]["status"] = "ERROR"
	 res["associations"][member]["status_msg"] = "Unable to find a group with the specified name"

	 host_pools_utils.traceHostPoolEvent(TRACE_ERROR,
					     string.format(res["associations"][member]["status_msg"]))
      else
	 local pool_id = pools_list[pool]["id"]
	 if connectivity == "pass" then
	    if host_pools_utils.addPoolMember(ifid, pool_id, member) == true then
	       res["associations"][member]["status"] = "OK"
	    end
	 elseif info["connectivity"] == "reject" then
	    host_pools_utils.deletePoolMember(ifid, pool_id, member)
	    res["associations"][member]["status"] = "OK"
	 else
	    res["associations"][member]["status"] = "ERROR"
	    res["associations"][member]["status_msg"] = "Unknown association: allowed associations are 'pass' and 'reject'"

	    host_pools_utils.traceHostPoolEvent(TRACE_ERROR,
						string.format(res["associations"][member]["status_msg"]))
	 end
      end

   end

   interface.reloadHostPools()
   r[ifname] = res
end

print(json.encode(r))
