--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local checks = require("checks")

local syslog_modules = nil
local syslog_conf = nil

-- #################################################################

-- The function below ia called once (#pragma once)
function setup()
   local ifid = interface.getId()
   syslog_modules = checks.load(ifid, checks.script_types.syslog, "syslog")

   local configset = checks.getConfigset()
   -- Configuration is global, system-wide
   syslog_conf = checks.getConfig(configset, "syslog")
end

-- #################################################################

-- The function below is called for each received alert
function handleEvent(name, message, host, priority)
   local event_handler = syslog_modules.hooks["handleEvent"][name]

   if(event_handler ~= nil) then
      event_handler(syslog_conf, message, host, priority)
   end
end 

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown()
   local all_modules = syslog_modules.modules

   for mod_name, syslog_module in pairs(syslog_modules) do
      local script = all_modules[mod_name]

      if syslog_module.teardown ~= nil then
          local conf = checks.getTargetHookConfig(syslog_conf, script)

          if conf.enabled then
            syslog_module.teardown(conf.script_conf)
          end
      end
   end
end

-- #################################################################
