--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local all_import_export = require "all_import_export"
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

local modules = import_export_rest_utils.unpack(_POST["JSON"])

if not modules or not modules["all"] then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local items = {}

local all_ie = all_import_export:create()
items[#items+1] = { name = "all",
  conf = modules["all"],
  instance = all_ie
}

import_export_rest_utils.import(items)

