--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


require "lua_utils"

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

local recipient_list = recipients.get_all_recipients(false --[[ do NOT exclude builtin recipients --]] ,
						 true --[[ include usage statistics --]])
recipient_list = recipients.format_checks_list(recipient_list)

print(json.encode(recipient_list))
