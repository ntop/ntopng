--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
local notification_recipients = require("notification_recipients")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

if not haveAdminPrivileges(true) then
    return
end

local recipients = notification_recipients.get_recipients()

-- Exclude builtin recipients for now
-- Builtin recipients will be possibly included later and made uneditable from the UI
local res = {}
for _, recipient in pairs(recipients) do
   if not recipient.endpoint_conf.endpoint_conf.builtin then
      res[#res + 1] = recipient
   end
end

print(json.encode(res))
