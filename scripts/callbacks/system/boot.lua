--
-- (C) 2013-18 - ntop.org
--

--
-- This script is executed once at boot
-- * BEFORE * network interfaces are setup
-- * BEFORE * switching to nobody
--
-- ** PLEASE PAY ATTENTION TO WHAT YOU EXECUTE ON THIS FILE **
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "alert_utils"

local prefs_dump_utils = require "prefs_dump_utils"
prefs_dump_utils.readPrefsFromDisk()

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require("boot")
end

