--
-- (C) 2019-25 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local alert_consts = require("alert_consts")
local checks = require("checks")
local rest_utils = require "rest_utils"
local auth = require "auth"

-- Return all checks scripts keys, used to identify a check in ntopng
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/scripts/key.lua
--

local rc = rest_utils.consts.success.ok

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end


local subdirs = {}
local result = {}

for _, subdir in pairs(checks.listSubdirs()) do
   subdirs[#subdirs + 1] = subdir.id
end

local config_set = checks.getConfigset()

for _, subdir in ipairs(subdirs) do
   local script_type = checks.getScriptType(subdir)

   if(script_type == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad subdir: " .. subdir)
      return
   end

   -- ################################################

   local scripts = checks.load(getSystemInterfaceId(), script_type, subdir, {return_all = false})

  for script_name, script in pairs(scripts.modules) do
    if script.gui and script.gui.i18n_title and script.gui.i18n_description then
      
      result[#result + 1] = script_name
    end

    ::continue::
  end
end

local scripts_keys = {
    scripts_keys = result
}

rest_utils.answer(rc, scripts_keys)
