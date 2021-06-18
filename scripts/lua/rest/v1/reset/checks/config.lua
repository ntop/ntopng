--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local checks_import_export = require "checks_import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"
local auth = require "auth"

--
-- Reset Checks configuration
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v1/reset/scripts/config.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local instances = {}
instances["scripts"] = checks_import_export:create()
import_export_rest_utils.reset(instances)

