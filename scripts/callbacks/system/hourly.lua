--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local remote_assistance = require "remote_assistance"
local lists_utils = require "lists_utils"

-- ########################################################

remote_assistance.checkExpiration()
lists_utils.downloadLists()

-- Run hourly scripts
ntop.checkSystemScriptsHour()
