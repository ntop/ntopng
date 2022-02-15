--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


require "lua_utils"

local pools_lua_utils = require "pools_lua_utils"
local recipients = require "recipients"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local auth = require "auth"

-- ################################################

if not auth.has_capability(auth.capabilities.notifications) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

sendHTTPContentTypeHeader('application/json')

local recipients = recipients.get_all_recipients(false --[[ do NOT exclude builtin recipients --]] ,
						 true --[[ include usage statistics --]])


local all_instances = pools_lua_utils.all_pool_instances_factory()

local res = {}
for _, instance in pairs(all_instances) do
   local instance_pools = instance:get_all_pools()

   for _, instance_pool in pairs(instance_pools) do
      instance_pool["key"] = instance.key -- e.g., 'interface', 'host', etc.
      res[#res + 1] = instance_pool
   end
end

for _, value in pairs(recipients) do
   for _, recps in pairs(res) do
      for _, rec_num in pairs(recps.recipients) do
         if (rec_num.recipient_id == value.recipient_id) then
            value["bind_to_pools"] = (value["bind_to_pools"] or 0) + 1
         end
      end 
   end   
end

print(json.encode(recipients))
