--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils  = require "rest_utils"
local checks      = require "checks"
local alert_consts = require "alert_consts"

--
-- Returns ntopng directory paths for the Directories page.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/directories.lua
--

local res = {
   working_dir  = dirs.workingdir,
   script_dir   = dirs.scriptdir,

   -- Callback directories (arrays of paths)
   flow_checks_dirs      = checks.getSubdirectoryPath(checks.script_types.flow, "flow"),
   host_checks_dirs      = checks.getSubdirectoryPath(checks.script_types.traffic_element, "host"),
   network_checks_dirs   = checks.getSubdirectoryPath(checks.script_types.traffic_element, "network"),
   interface_checks_dirs = checks.getSubdirectoryPath(checks.script_types.traffic_element, "interface"),

   -- Alert definition directories
   alert_defs_dirs = alert_consts.getDefinititionDirs(),
}

rest_utils.answer(rest_utils.consts.success.ok, res)
