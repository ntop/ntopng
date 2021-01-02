--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local recipients = require "recipients"

recipients.cleanup()
rest_utils.answer(rest_utils.consts.success.ok)
