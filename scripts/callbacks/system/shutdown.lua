--
-- (C) 2013-18 - ntop.org
--

--
-- This script is executed when ntopng shuts down when
-- network interfaces are setup
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local prefs_dump_utils = require "prefs_dump_utils"

prefs_dump_utils.savePrefsToDisk()
