--
-- (C) 2013-24 - ntop.org
--
-- This script is used to timeseries-related periodic activities
-- for example to send data to a remote timeseries collector
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local callback_utils = require "callback_utils"
callback_utils.uploadTSdata()
-- This is not only for InfluxDB but for RRD too
