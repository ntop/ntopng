--
-- (C) 2019-20 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local info = ntop.getInfo() 

local scripts_import_export = require "scripts_import_export"
local json = require ("dkjson")
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"
local rest_utils = require("rest_utils")

--
-- Read user scripts configuration
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v1/get/scripts/config.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local download = _GET["download"] 

if not haveAdminPrivileges() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local scripts_import_export = scripts_import_export:create()
local res = scripts_import_export:export()

if isEmptyString(download) then
   rest_utils.answer(rest_utils.consts.success.ok, res)
else
   sendHTTPContentTypeHeader('application/json', 'attachment; filename="scripts_configuration.json"')
   print(json.encode(res, nil))
end
