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

if not haveAdminPrivileges() then
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

if not modules["federation"] then
  rest_utils.answer(rest_utils.consts.err.configuration_file_mismatch)
  return
end

local items = {}

local federation_import_export = federation_import_export:create()
items[#items+1] = {
   name = "federation",
   conf = modules["federation"],
   instance = federation_import_export 
}

import_export_rest_utils.import(items)
