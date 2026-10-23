--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils   = require "rest_utils"
local auth         = require "auth"
local checks       = require "checks"
local alert_consts = require "alert_consts"

--
-- Returns ntopng directory paths for the Directories page.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/directories.lua
--

-- Developer pages (Developer > Catalog): users with the developer capability
if not auth.has_capability(auth.capabilities.developer) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

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
