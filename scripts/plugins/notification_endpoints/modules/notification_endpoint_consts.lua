--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local os_utils = require "os_utils"
local plugins_utils = require "plugins_utils"

-- #################################################################

local notification_endpoint_consts = {}

-- #################################################################

local loaded_notification_endpoints

local function load_notification_endpoints()
   if loaded_notification_endpoints then
      return loaded_notification_endpoints
   end

   loaded_notification_endpoints = {}
   local endpoints_path = plugins_utils.getPluginDataDir("notification_endpoints", "endpoints")

   for fname in pairs(ntop.readdir(endpoints_path)) do
      if not string.ends(fname, ".lua") then
	 goto continue
      end

      local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
      local full_path = os_utils.fixPath(endpoints_path .. "/" .. fname)
      local plugin = dofile(full_path)

      if not plugin then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unable to load %s", full_path))
	 goto continue
      end

      if not plugin.key or plugin.key == "" then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing or invalid key for %s", full_path))
	 goto continue
      end

      if loaded_notification_endpoints[plugin.key] then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Duplicate key '%s' found in %s", plugin.key, full_path))
	 goto continue
      end

      if not plugin.conf_params or type(plugin.conf_params) ~= "table" then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing or invalid 'conf_params' in %s", full_path))
	 goto continue
      end

      if plugin.recipient_params and type(plugin.recipient_params) ~= "table" then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Invalid 'recipient_params' in %s", full_path))
	 goto continue
      end

      local mandatory_param_keys = {"param_name", "param_type"}

      for _, conf in ipairs({"conf_params", "recipient_params"}) do
	 for _, conf_param in ipairs(plugin[conf] or {}) do
	    for _, mandatory_param_key in ipairs(mandatory_param_keys) do
	       if not conf_param[mandatory_param_key] then
		  traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing mandatory '%s' in %s param for %s", mandatory_param_key, conf, full_path))
		  goto continue
	       end
	    end
	 end
      end

      loaded_notification_endpoints[plugin.key] = plugin

      ::continue::
   end
end

-- #################################################################

if not loaded_notification_endpoints then
   load_notification_endpoints()
end

notification_endpoint_consts.endpoint_types = loaded_notification_endpoints

-- #################################################################

return notification_endpoint_consts
