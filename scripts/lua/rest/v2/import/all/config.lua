--
-- (C) 2019-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local all_import_export = require "all_import_export"
local nedge_import_export = ntop.isnEdge and ntop.isnEdge() and require "nedge_import_export" or nil
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"

--
-- Import all configurations
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local modules = import_export_rest_utils.unpack(import_export_rest_utils.get_json_conf())

if not modules or not modules["all"] then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local items = {}

local all_ie = all_import_export:create()
items[#items+1] = {
  name = "all",
  conf = modules["all"],
  instance = all_ie
}

if nedge_import_export and modules["system_config"] then
  items[#items+1] = {
    name = "system_config",
    conf = modules["system_config"],
    instance = nedge_import_export:create()
  }
end

import_export_rest_utils.import(items)

