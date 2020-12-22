--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local lists_utils = require "lists_utils"

-- ########################################################

lists_utils.downloadLists()

-- Run hourly scripts
ntop.checkSystemScriptsHour()
