--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Send a test message to a recipient before (or without) saving it. The connection is an
-- existing one (endpoint_id) or a not yet saved one (endpoint_conf_type + its params).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "endpoint_id":"2","email_recipient":"ops@example.com"}'
--   "http://localhost:3000/lua/rest/v2/exec/notification/test_recipient.lua"
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
local recipients_rest_utils = require "recipients_rest_utils"

local endpoint_id = _POST["endpoint_id"]
local ec

if isEmptyString(endpoint_id) then
   local endpoint_key = _POST["endpoint_conf_type"]
   if not endpoint_key or not endpoints.get_types(true --[[ exclude builtin ]])[endpoint_key] then
      rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "endpoint_not_existing" })
      return
   end

   local ok, status = endpoints.check_config_params(endpoint_key, _POST)
   if not ok then
      rest_utils.answer(rest_utils.consts.err.invalid_args, status.error)
      return
   end

   ec = { endpoint_key = endpoint_key, endpoint_conf_name = endpoint_key, endpoint_conf = status.safe_params }
else
   ec = endpoints.get_endpoint_config(endpoint_id)
   if ec.status ~= "OK" or ec.endpoint_conf.builtin then
      rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "endpoint_config_not_existing" })
      return
   end
end

local err = recipients_rest_utils.check_channel_params(ec.endpoint_key, _POST)
if err then
   rest_utils.answer(rest_utils.consts.err.invalid_args, err)
   return
end

local res = recipients.test_recipient_conf(ec, _POST)
if res.status ~= "OK" then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res.error or { type = "internal_error" })
   return
end

rest_utils.answer(rest_utils.consts.success.ok)
