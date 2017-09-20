--
-- (C) 2013-17 - ntop.org
--

--
-- This script is executed when ntopng shuts down when
-- network interfaces are setup
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

savePrefsToDisk()
