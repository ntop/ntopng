--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local os_utils = require "os_utils"

local SYSLOG_MODULES_BASEDIR = dirs.installdir .. "/scripts/callbacks/syslog"

local syslog_modules = {}

-- #################################################################

-- The function below ia called once (#pragma once)
function setup()
   local syslog_modules_dir = os_utils.fixPath(SYSLOG_MODULES_BASEDIR)
   package.path = syslog_modules_dir .. "/?.lua;" .. package.path

   for fname in pairs(ntop.readdir(syslog_modules_dir)) do
      if not ends(fname, ".lua") then
         goto next_module
      end

      local mod_name = string.sub(fname, 1, string.len(fname) - 4)
      local syslog_module = require(mod_name)

      traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Loading syslog module '%s'", mod_name))

      if syslog_module == nil then
         traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Loading '%s' failed", syslog_modules_dir.."/"..fname))
      end

      if syslog_modules[mod_name] then
         traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Skipping duplicate module '%s'", mod_name))
         goto next_module
      end

      -- If a setup function is available, call it
      if syslog_module.setup ~= nil then
         local setup_ok = syslog_module.setup()

         if not setup_ok then
            traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' as setup() failed", mod_name))
            goto next_module
         end
      end

      syslog_modules[mod_name] = syslog_module

      ::next_module::
   end
end

-- #################################################################

-- The function below is called for each received alert
function handleEvent(name, message)
   if syslog_modules[name] ~= nil and
      syslog_modules[name].handleEvent ~= nil then
      syslog_modules[name].handleEvent(message)
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
