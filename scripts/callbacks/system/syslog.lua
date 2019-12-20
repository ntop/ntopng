--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local user_scripts = require("user_scripts")

local syslog_modules = nil
local syslog_conf = nil

-- #################################################################

-- The function below ia called once (#pragma once)
function setup()
   local ifid = interface.getId()
   syslog_modules = user_scripts.load(ifid, user_scripts.script_types.syslog, "syslog")

   local configsets = user_scripts.getConfigsets("syslog")
   syslog_conf = user_scripts.getTargetConfiset(configsets, getInterfaceName(ifid)).config
end

-- #################################################################

-- The function below is called for each received alert
function handleEvent(name, message)
   local event_handler = syslog_modules.hooks["handleEvent"][name]

   -- TODO use syslog_conf

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
