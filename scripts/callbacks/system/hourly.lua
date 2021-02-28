--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local lists_utils = require "lists_utils"

-- ########################################################

lists_utils.downloadLists()

-- Run hourly scripts
ntop.checkSystemScriptsHour()
