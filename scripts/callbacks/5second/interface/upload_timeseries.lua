--
-- (C) 2013-26 - ntop.org
--
-- This script is used to timeseries-related periodic activities
-- for example to send data to a remote timeseries collector
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local callback_utils = require "callback_utils"
-- Export/flush timeseries data
local max_duration = 5 -- seconds
callback_utils.uploadTSdata(max_duration)
