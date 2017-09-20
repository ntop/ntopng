--
-- (C) 2013-17 - ntop.org
--

--
-- This script is executed once at boot
-- * BEFORE * network interfaces are setup
-- * BEFORE * switching to nobody
--
-- ** PLEASE PAY ATTENTION TO WHAT YOU EXECUTE ON THIS FILE **
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

readPrefsFromDisk()


