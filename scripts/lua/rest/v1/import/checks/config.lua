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

--
-- Import scripts configuration
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local modules = import_export_rest_utils.unpack(_POST["JSON"])

if not modules then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

if not modules["scripts"] then
  rest_utils.answer(rest_utils.consts.err.configuration_file_mismatch)
  return
end

local items = {}

local scripts_ie = checks_import_export:create()
items[#items+1] = {
   name = "scripts",
   conf = modules["scripts"],
   instance = scripts_ie
}

import_export_rest_utils.import(items)

