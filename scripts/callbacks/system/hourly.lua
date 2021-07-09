--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local lists_utils = require "lists_utils"

-- ########################################################

-- If ntopng is in offline mode, retry checking connectivity
if ntop.isOffline() then
   local connectivity_utils = require "connectivity_utils"
   local online = connectivity_utils.checkConnectivity()
   if online then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "Connectivity restored, ntopng will now run in online mode")
      ntop.setOnline()
   end
end

lists_utils.downloadLists()

-- Run hourly scripts
ntop.checkSystemScriptsHour()
