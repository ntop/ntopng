--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Edit a notification recipient (name, filters, recipient params). The builtin alert DB
-- recipient can be edited too (filters only: its name is fixed).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"csrf":"...",
--   "recipient_id":"1","recipient_name":"Ops","recipient_minimum_severity":"5"}'
--   "http://localhost:3000/lua/rest/v2/edit/notification/recipient.lua"
--

-- lua_utils (~14 ms) is loaded anyway: endpoints.get_types() loads the channel modules
-- (notifications/endpoints/*.lua), which require it
require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local recipients = require "recipients"
local recipients_rest_utils = require "recipients_rest_utils"

local recipient_id = tonumber(_POST["recipient_id"])
local recipient = recipient_id and recipients.get_recipient(recipient_id)

if not recipient then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "endpoint_recipient_not_existing" })
   return
end

local recipient_name = _POST["recipient_name"]
if recipient.endpoint_conf and recipient.endpoint_conf.builtin then
   -- recipients.get_builtin_recipients() looks the builtin recipient up by name
   recipient_name = recipient.recipient_name
elseif isEmptyString(recipient_name) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "missing_mandatory_param", missing_param = "recipient_name" })
   return
else
   local same = recipients.get_recipient_by_name(recipient_name)
   if same and same.recipient_id ~= recipient_id then
      rest_utils.answer(rest_utils.consts.err.invalid_args, { type = "endpoint_recipient_already_existing" })
      return
   end
end

local err = recipients_rest_utils.check_channel_params(recipient.endpoint_key, _POST)
if err then
   rest_utils.answer(rest_utils.consts.err.invalid_args, err)
   return
end

local filters = recipients_rest_utils.parse_recipient_filters(_POST)
local res = recipients.edit_recipient(recipient_id, recipient_name, filters.categories, filters.entities,
   filters.minimum_severity, filters.host_pools, filters.am_hosts, filters.tags, _POST)

if res.status ~= "OK" then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res.error or { type = "internal_error" })
   return
end

rest_utils.answer(rest_utils.consts.success.ok, { recipient_id = recipient_id })
