--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")

local all_import_export = require "all_import_export"
local snmp_import_export = require "snmp_import_export"
local am_import_export = plugins_utils.loadModule("active_monitoring", "am_import_export")
local notifications_import_export = require "notifications_import_export"
local scripts_import_export = require "scripts_import_export"
local pool_import_export = require "pool_import_export"
local infrastructure_import_export = require("infrastructure_import_export")

local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"

--
-- Export all configurations
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v1/export/all/config.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local download = _GET["download"] 

if not haveAdminPrivileges() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local instances = {}
instances["all"] = all_import_export:create()
instances["snmp"] = snmp_import_export:create()
instances["active_monitoring"] = am_import_export:create()
instances["notifications"] = notifications_import_export:create()
instances["scripts"] = scripts_import_export:create()
instances["pool"] = pool_import_export:create()
instances["infrastructure"] = infrastructure_import_export:create()
import_export_rest_utils.export(instances, not isEmptyString(download))

