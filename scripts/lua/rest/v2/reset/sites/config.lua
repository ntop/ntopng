--
-- (C) 2026 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local sites_import_export = require "sites_import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"

--
-- Reset Sites configuration
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/reset/sites/config.lua
--
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local instances = {}
instances["sites"] = sites_import_export:create()
import_export_rest_utils.reset(instances)
