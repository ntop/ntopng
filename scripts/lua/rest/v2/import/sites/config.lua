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
-- Import Sites configuration
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local modules = import_export_rest_utils.unpack(import_export_rest_utils.get_json_conf())

if not modules then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

if not modules["sites"] then
   rest_utils.answer(rest_utils.consts.err.configuration_file_mismatch)
   return
end

local items = {}

local sites_ie = sites_import_export:create()
items[#items + 1] = {
   name = "sites",
   conf = modules["sites"],
   instance = sites_ie
}

import_export_rest_utils.import(items)
