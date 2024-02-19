--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "profiling"
profiling.get_current_memory("disk_monitor.lua")

local storage_utils = require("storage_utils")
profiling.get_current_memory("disk_monitor.lua")

-- ##############################################

storage_utils.storageInfo(true --[[ refresh cache ]], 120 --[[ Allow a couple of minutes --]])
 