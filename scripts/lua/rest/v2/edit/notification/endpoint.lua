--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Edit a notification connection (endpoint): name and params (all of them: missing optional
-- params are cleared). Builtin connections can not be edited.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "endpoint_id":"2","endpoint_conf_name":"Slack","slack_sender_username":"ntopng",
--   "slack_webhook":"https://hooks.slack.com/..."}'
--   "http://localhost:3000/lua/rest/v2/edit/notification/endpoint.lua"
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
local recipients_rest_utils = require "recipients_rest_utils"

local endpoint_id = _POST["endpoint_id"]
local ec = (not isEmptyString(endpoint_id)) and endpoints.get_endpoint_config(endpoint_id)

if not ec or ec.status ~= "OK" or ec.endpoint_conf.builtin then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "endpoint_config_not_existing" })
   return
end

local err = recipients_rest_utils.check_channel_params(ec.endpoint_key, _POST)
if err then
   rest_utils.answer(rest_utils.consts.err.invalid_args, err)
   return
end

local conf_name = _POST["endpoint_conf_name"]
if isEmptyString(conf_name) then conf_name = ec.endpoint_conf_name end

local res = endpoints.edit_config(endpoint_id, conf_name, _POST)
if res.status ~= "OK" then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res.error or { type = "internal_error" })
   return
end

rest_utils.answer(rest_utils.consts.success.ok, { endpoint_id = tonumber(endpoint_id) or endpoint_id })
