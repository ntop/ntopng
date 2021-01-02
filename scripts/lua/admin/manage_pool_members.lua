--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local host_pools = require "host_pools"
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

--[[ EXAMPLE PAYLOAD:

   local ret = {associations = {
   ["DE:AD:BE:EE:FF:FF"] = {group = "maina", connectivity = "pass"},
   ["AB:AB:AB:AB:AB:AB"] = {group = "simon", connectivity = "reject"}}
   }
   return ret
--]]

-- Instantiate host pools
local s = host_pools:create()

local r = {}

local pools_list = {}

-- Table with pool names as keys
for _, pool in pairs(s:get_all_pools()) do
   pools_list[pool["name"]] = pool
end

local res = {associations = _POST["associations"]}

for member, info in pairs(_POST["associations"] or {}) do
   local pool = info["group"]
   local connectivity = info["connectivity"]

   if pools_list[pool] == nil then
      res["associations"][member]["status"] = "ERROR"
      res["associations"][member]["status_msg"] = "Unable to find a group with the specified name"
   else
      local pool_id = pools_list[pool]["pool_id"]
      if connectivity == "pass" then
	 if s:bind_member(member, pool_id) == true then
	    res["associations"][member]["status"] = "OK"
	 end
      elseif info["connectivity"] == "reject" then
	 s:bind_member(member, host_pools.DEFAULT_POOL_ID)
	 res["associations"][member]["status"] = "OK"
      else
	 res["associations"][member]["status"] = "ERROR"
	 res["associations"][member]["status_msg"] = "Unknown association: allowed associations are 'pass' and 'reject'"
      end
   end

end

-- Formerly an array with interfaces as keys. Now that pools are global, placeholder "_all_" is used
r["_all_"] = res


print(json.encode(r))
