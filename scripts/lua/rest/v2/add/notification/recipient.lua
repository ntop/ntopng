--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Add a notification recipient. The connection is either an existing one (endpoint_id) or
-- a new one created in the same call (endpoint_conf_type + its params): when the recipient
-- can not be added, the new connection is removed again.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "recipient_name":"Ops","endpoint_conf_type":"slack","slack_sender_username":"ntopng",
--   "slack_webhook":"https://hooks.slack.com/...","recipient_minimum_severity":"5"}'
--   "http://localhost:3000/lua/rest/v2/add/notification/recipient.lua"
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

local function answer_error(err)
   rest_utils.answer(rest_utils.consts.err.invalid_args, err or { type = "internal_error" })
end

local recipient_name = _POST["recipient_name"]
if isEmptyString(recipient_name) then
   answer_error({ type = "missing_mandatory_param", missing_param = "recipient_name" })
   return
end

if recipients.get_recipient_by_name(recipient_name) then
   answer_error({ type = "endpoint_recipient_already_existing" })
   return
end

local endpoint_id = _POST["endpoint_id"]
local endpoint_key
local new_endpoint = isEmptyString(endpoint_id)

if new_endpoint then
   endpoint_key = _POST["endpoint_conf_type"]
else
   local ec = endpoints.get_endpoint_config(endpoint_id)
   if ec.status ~= "OK" or ec.endpoint_conf.builtin then
      answer_error({ type = "endpoint_config_not_existing" })
      return
   end
   endpoint_key = ec.endpoint_key
end

if not endpoint_key or not endpoints.get_types(true --[[ exclude builtin ]])[endpoint_key] then
   answer_error({ type = "endpoint_not_existing" })
   return
end

local err = recipients_rest_utils.check_channel_params(endpoint_key, _POST)
if err then
   answer_error(err)
   return
end

if new_endpoint then
   -- Connection named after the recipient; suffix on clash with an existing connection
   local conf_name = _POST["endpoint_conf_name"]
   if isEmptyString(conf_name) then conf_name = recipient_name end

   local res
   for i = 1, 10 do
      res = endpoints.add_config(endpoint_key, (i == 1) and conf_name or string.format("%s (%d)", conf_name, i), _POST)
      if res.status == "OK" or not res.error or res.error.type ~= "endpoint_config_already_existing" then
         break
      end
   end

   if res.status ~= "OK" then
      answer_error(res.error)
      return
   end

   endpoint_id = res.endpoint_id
end

local filters = recipients_rest_utils.parse_recipient_filters(_POST)
local res = recipients.add_recipient(endpoint_id, recipient_name, filters.categories, filters.entities,
   filters.minimum_severity, filters.host_pools, filters.am_hosts, filters.tags, _POST)

if res.status ~= "OK" then
   if new_endpoint then
      endpoints.delete_config(endpoint_id)
   end
   answer_error(res.error)
   return
end

rest_utils.answer(rest_utils.consts.success.ok, { recipient_id = res.recipient_id, endpoint_id = tonumber(endpoint_id) })
