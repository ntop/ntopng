--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

--
-- Notification connections (endpoints: SMTP server, bot token, webhook URL...) with their
-- params and the number of recipients using them. Builtin ones are excluded.
-- Admin only: params include credentials.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/notification/endpoints.lua"
--

-- lua_utils (~14 ms) is loaded anyway: endpoints.get_types() loads the channel modules
-- (notifications/endpoints/*.lua), which require it
require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local endpoints = require "endpoints"
local recipients = require "recipients"

-- Recipients per endpoint, from a single read of all the recipients
local num_recipients = {}
for _, r in ipairs(recipients.get_all_recipients(true --[[ exclude builtin ]])) do
   local id = tostring(r.endpoint_id)
   num_recipients[id] = (num_recipients[id] or 0) + 1
end

local res = {}
for _, ec in ipairs(endpoints.get_configs(true --[[ exclude builtin ]])) do
   local params = {}
   for k, v in pairs(ec.endpoint_conf or {}) do
      if k ~= "endpoint_conf_name" then params[k] = v end
   end

   res[#res + 1] = {
      endpoint_id = tonumber(ec.endpoint_id) or ec.endpoint_id,
      endpoint_key = ec.endpoint_key,
      endpoint_conf_name = ec.endpoint_conf_name,
      params = params,
      num_recipients = num_recipients[tostring(ec.endpoint_id)] or 0,
   }
end

rest_utils.answer(rest_utils.consts.success.ok, res)
