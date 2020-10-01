--
-- (C) 2019-20 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local notifications_import_export = require "notifications_import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"

--
-- Import Notification Endpoint and Recipient configuration
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not haveAdminPrivileges() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local modules = import_export_rest_utils.unpack(_POST["JSON"])

if not modules or not modules["notifications"] then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local items = {}
local notifications_import_export = notifications_import_export:create()
items["notifications"] = {
   conf = modules["notifications"],
   instance = notifications_import_export 
}

import_export_rest_utils.import(items)

