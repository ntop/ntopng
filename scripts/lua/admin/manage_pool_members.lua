--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local host_pools = require "host_pools"
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

---
-- DEPRECATED - keeping this for backward compatibility, will be removed soon
-- This has been replaced by rest/v2/set/pool/members.lua
--

--[[ 
   Request example:
   curl -u admin:admin -H "Content-Type: application/json" -d '{"associations" : {"DE:AD:BE:EE:FF:FF" : {"group" : "staff", "connectivity" : "pass"},"AB:AB:AB:AB:AB:AB" : {"group" : "guest", "connectivity" : "reject"},"192.168.2.221/32@0" : {"group" : "staff", "connectivity" : "pass"}}}' http://192.168.1.1:3000/lua/admin/manage_pool_members.lua 

   Data example:
   local res = {
     associations = {
       ["DE:AD:BE:EE:FF:FF"] = {
         group = "staff", 
         connectivity = "pass"
       },
       ["AB:AB:AB:AB:AB:AB"] = {
         group = "guest", 
         connectivity = "reject"
       },
       ["192.168.2.221/32@0"] = {
         group = "staff", 
         connectivity = "reject"
       }
     }
   }
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

   if member == nil then
      res["associations"][member]["status"] = "ERROR"
      res["associations"][member]["status_msg"] = "Bad member format"
   else
      if pools_list[pool] == nil then
         res["associations"][member]["status"] = "ERROR"
         res["associations"][member]["status_msg"] = "Unable to find a group with the specified name"
      else
         local pool_id = pools_list[pool]["pool_id"]
         if connectivity == "pass" then
	    if s:bind_member(member, pool_id) == true then
	       res["associations"][member]["status"] = "OK"
            else
               res["associations"][member]["status"] = "ERROR"
	       res["associations"][member]["status_msg"] = "Failure adding member, maybe bad member MAC or IP"
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

end

-- Formerly an array with interfaces as keys. Now that pools are global, placeholder "_all_" is used
r["_all_"] = res

print(json.encode(r))
