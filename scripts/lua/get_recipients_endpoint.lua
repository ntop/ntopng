--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
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

if not haveAdminPrivileges(true) then
    return
end

local recipients = recipients.get_all_recipients()
print(json.encode(recipients))
