--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Delete a notification connection (endpoint) and all the recipients using it.
-- Builtin connections can not be deleted.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "endpoint_id":"2"}' "http://localhost:3000/lua/rest/v2/delete/notification/endpoint.lua"
--

-- http_lint (validates the params, loads ntop_utils: isAdministrator, isEmptyString). No lua_utils:
-- reading/deleting recipients does not load the channel modules
require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local endpoints = require "endpoints"

local endpoint_id = _POST["endpoint_id"]
local ec = (not isEmptyString(endpoint_id)) and endpoints.get_endpoint_config(endpoint_id)

if not ec or ec.status ~= "OK" or ec.endpoint_conf.builtin then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "endpoint_config_not_existing" })
   return
end

local res = endpoints.delete_config(endpoint_id)
if res.status ~= "OK" then
   rest_utils.answer(rest_utils.consts.err.internal_error)
   return
end

rest_utils.answer(rest_utils.consts.success.ok)
