--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local notification_configs = require "notification_configs"
local recipients = require "recipients"
local recipients_instance = recipients:create()

notification_configs.reset_configs()
recipients_instance:cleanup()

rest_utils.answer(rest_utils.consts.success.ok)
