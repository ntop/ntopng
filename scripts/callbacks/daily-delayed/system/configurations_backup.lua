--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path

require("lua_utils")
local backup_config = require("backup_config")
tprint(backup_config)

backup_config.save_backup()