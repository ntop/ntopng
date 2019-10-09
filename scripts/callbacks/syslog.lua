--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local user_scripts = require("user_scripts")

local syslog_modules = nil

-- #################################################################

-- The function below ia called once (#pragma once)
function setup()
   syslog_modules = user_scripts.load(user_scripts.script_types.syslog, getSystemInterfaceId(), ".")
end

-- #################################################################

-- The function below is called for each received alert
function handleEvent(name, message)
   local event_handler = syslog_modules.hooks["handleEvent"][name]

   if(event_handler ~= nil) then
      event_handler(message)
   end
end 

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown()
   for mod_name, syslog_module in pairs(syslog_modules) do
      if syslog_module.teardown ~= nil then
          syslog_module.teardown()
      end
   end
end

-- #################################################################
