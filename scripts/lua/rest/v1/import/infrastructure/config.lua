--
-- (C) 2020 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
local infrastructure_import_export = require("infrastructure_import_export")
local json = require "dkjson"
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"
local auth = require "auth"

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

if not ntop.isEnterpriseL() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local modules = import_export_rest_utils.unpack(_POST["JSON"])

if not modules then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

if not modules["infrastructure"] then
  rest_utils.answer(rest_utils.consts.err.configuration_file_mismatch)
  return
end

local items = {}

local infrastructure_import_export = infrastructure_import_export:create()
items[#items+1] = {
   name = "infrastructure",
   conf = modules["infrastructure"],
   instance = infrastructure_import_export 
}

import_export_rest_utils.import(items)
