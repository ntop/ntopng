--
-- (C) 2019-20 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path

require "lua_utils"

local snmp_import_export = require "snmp_import_export"
local plugins_utils = require("plugins_utils")
local am_import_export = plugins_utils.loadModule("active_monitoring", "am_import_export")
local notifications_import_export = require "notifications_import_export"
local scripts_import_export = require "scripts_import_export"
local pool_import_export = require "pool_import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local import_export_rest_utils = require "import_export_rest_utils"

--
-- Import all configurations
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not haveAdminPrivileges() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local modules = import_export_rest_utils.unpack(_POST["JSON"])

if not modules or 
   not modules["snmp"] or 
   not modules["active_monitoring"] or 
   not modules["notifications"] or 
   not modules["scripts"] or 
   not modules["pool"] then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local items = {}

local snmp_ie = snmp_import_export:create()
items[#items+1] = { name = "snmp",
  conf = modules["snmp"],
  instance = snmp_ie
}

local am_ie = am_import_export:create()
items[#items+1] = { name = "active_monitoring", 
  conf = modules["active_monitoring"],
  instance = am_ie
}

local notifications_ie = notifications_import_export:create()
items[#items+1] = { name = "notifications", 
  conf = modules["notifications"],     
  instance = notifications_ie
}

local scripts_ie = scripts_import_export:create()
items[#items+1] = { name = "scripts", 
  conf = modules["scripts"],           
  instance = scripts_ie
}

local pool_ie = pool_import_export:create()
items[#items+1] = { name = "pool", 
  conf = modules["pool"],              
  instance = pool_ie
}

import_export_rest_utils.import(items)

