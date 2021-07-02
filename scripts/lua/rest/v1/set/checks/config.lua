--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local info = ntop.getInfo() 

local checks_import_export = require "checks_import_export"
local json = require ("dkjson")
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"
local rest_utils = require("rest_utils")
local tracker = require("tracker")

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

if(_POST["JSON"] == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local data = json.decode(_POST["JSON"])

local checks_import_export = checks_import_export:create()
local res = checks_import_export:import(data)

if res.err then
  rest_utils.answer(res.err)
  return
end

-- ################################################

-- TRACKER HOOK
tracker.log('set_scripts_config', {})

rest_utils.answer(rest_utils.consts.success.ok)
