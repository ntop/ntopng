--
-- (C) 2013-20 - ntop.org
--
-- This script is used to timeseries-related periodic activities
-- for example to send data to a remote timeseries collector

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local callback_utils = require "callback_utils"
local now = os.time()
local periodicity = 3
local deadline = (now + periodicity)

callback_utils.uploadTSdata(deadline)
