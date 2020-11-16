--
-- (C) 2020 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
local federation_import_export = require("federation_import_export")
local json = require "dkjson"
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"
local auth = require "auth"

--
-- Reset Federation Dashboard configuration
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v1/reset/federation/config.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not haveAdminPrivileges() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

if not ntop.isEnterpriseL() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local instances = {}
instances["federation"] = federation_import_export:create()
import_export_rest_utils.reset(instances)

