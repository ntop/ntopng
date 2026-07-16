--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


local rest_utils = require "rest_utils"
local endpoints = require("endpoints")
local recipients = require "recipients"
local auth = require "auth"

if not auth.has_capability(auth.capabilities.notifications) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

endpoints.reset_configs()
recipients.cleanup()

rest_utils.answer(rest_utils.consts.success.ok)
