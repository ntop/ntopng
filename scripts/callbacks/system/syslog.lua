--
-- (C) 2019-20 - ntop.org
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

   local configsets = user_scripts.getConfigsets()
   syslog_conf = user_scripts.getTargetConfig(configsets, "syslog", getInterfaceName(ifid))
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
          local conf = user_scripts.getTargetHookConfig(syslog_conf, script)

          if conf.enabled then
            syslog_module.teardown(conf.script_conf)
          end
      end
   end
end

-- #################################################################
