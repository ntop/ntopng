--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"
local json = require ("dkjson")
local alerts_api = require("alerts_api")
local check_modules = require("check_modules")
local alert_consts = require("alert_consts")

local syslog_module = {}

-- #################################################################

-- The function below ia called once (#pragma once)
function syslog_module.setup()
   return true
end

-- #################################################################

-- The function below is called for each received alert
function syslog_module.handleEvent(message)
   -- Example: printing the Suricata alert
   -- local alert = json.decode(message)
   -- if alert ~= nil then
   --    tprint(alert)
   -- end
end 

-- #################################################################

-- The function below ia called once (#pragma once)
function syslog_module.teardown()
   return true
end

-- #################################################################

return syslog_module
