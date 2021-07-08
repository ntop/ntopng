--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local snmp_import_export = require "snmp_import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"
local auth = require "auth"

--
-- Reset SNMP configuration
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/reset/snmp/config.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not auth.has_capability(auth.capabilities.snmp) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local instances = {}
instances["snmp"] = snmp_import_export:create()
import_export_rest_utils.reset(instances)

