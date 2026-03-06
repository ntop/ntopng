--
-- (C) 2019-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local snmp_import_export = require "snmp_import_export"
local am_import_export = require "am_import_export"
local notifications_import_export = require "notifications_import_export"
local checks_import_export = require "checks_import_export"
local pool_import_export = require "pool_import_export"
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"
local auth = require "auth"

--
-- Import Pool configuration
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not auth.has_capability(auth.capabilities.pools) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local raw = _POST["pool_CSV"] or _POST["JSON"]
if not raw or raw == "" then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local items = {}
local pool_ie = pool_import_export:create()

if _POST["pool_CSV"] then
   -- CSV path
   items[#items+1] = {
      name     = "pool",
      conf     = pool_ie:parse_csv(raw),
      instance = pool_ie
   }
elseif _POST["JSON"] then
   -- Standard JSON path: unpack and extract only the "pool" module
   local modules = import_export_rest_utils.unpack(raw)

   if not modules then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   local expected_modules = { "pool" }

   local missing_modules = {}
   for _, m in ipairs(expected_modules) do
      if not modules[m] then
         rest_utils.answer(rest_utils.consts.err.configuration_file_mismatch)
         missing_modules[#missing_modules+1] = m
      end
   end

   if #missing_modules == #expected_modules then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Failure importing configuration, none of the expected modules found: " .. table.concat(expected_modules, ", "))
      return
   end

   if modules["pool"] then
      items[#items+1] = {
         name = "pool", 
         conf = modules["pool"],              
         instance = pool_ie
      }
   end
else
   traceError(TRACE_ERROR, TRACE_CONSOLE,
      "Failure importing pool configuration: unrecognised file format")
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

import_export_rest_utils.import(items)

