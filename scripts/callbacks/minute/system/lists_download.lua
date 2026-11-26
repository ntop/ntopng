--
-- (C) 2026 - ntop.org
--

--
-- This script downloads the category lists, when requested.
-- It runs apart from housekeeping.lua as the downloads can take tens of seconds.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"

if scripts_triggers.checkDownloadLists() then
   local lists_utils = require "lists_utils"

   -- Below the 55 sec slow threshold of the minute activity, also counting the
   -- last list download (up to 10 sec): the remaining lists resume the next minute
   lists_utils.checkDownloadLists(40 --[[ timeout ]])
end
