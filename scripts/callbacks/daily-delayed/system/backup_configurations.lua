--
-- (C) 2013-24 - ntop.org
--

--
-- This scripts create daily backup of the ntopng configuration
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path

local backup_config = require("backup_config")

backup_config.exec_backup()