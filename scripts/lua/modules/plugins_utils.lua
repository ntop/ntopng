--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


local plugins_utils = {}
local os_utils = require("os_utils")
local persistence = require("persistence")
local file_utils = require("file_utils")
local template_utils = require("template_utils")
local lua_path_utils = require("lua_path_utils")
local ntop_utils = require "ntop_utils"
require "lua_trace"

local dirs = ntop.getDirs()

-- enable debug tracing
local do_trace = false

-- How deep the recursive plugins search should go into subdirectories
local MAX_RECURSION = 2

local PLUGIN_RELATIVE_PATHS = {
  menu_items = "menu_items",
}
local RUNTIME_PATHS = {}
local METADATA = nil

-- ##############################################

-- The runtime path can change when the user reloads the plugins.
-- We need to cache this into the same vm to ensure that all thea
-- scripts into this vm use the same directory.
local cached_runtime_dir = nil

function plugins_utils.getRuntimePath()
  if(not cached_runtime_dir) then
    cached_runtime_dir = ntop.getCurrentPluginsDir()
  end

  return(cached_runtime_dir)
end

-- ##############################################

local function init_runtime_paths()
  local runtime_path = plugins_utils.getRuntimePath()

  RUNTIME_PATHS = {
    -- Definitions
    alert_definitions = os_utils.fixPath(runtime_path .. "/alert_definitions"),
    check_definitions = os_utils.fixPath(runtime_path .. "/check_definitions"),

    -- Locales
    locales = os_utils.fixPath(runtime_path .. "/locales"),

    -- Timeseries
    ts_schemas = os_utils.fixPath(runtime_path .. "/ts_schemas"),

    -- Web Gui
    web_gui = os_utils.fixPath(runtime_path) .. "/scripts",
    menu_items = os_utils.fixPath(runtime_path.."/"..PLUGIN_RELATIVE_PATHS.menu_items),

    -- Alert endpoints
    alert_endpoints = os_utils.fixPath(runtime_path) .. "/alert_endpoints",

    -- HTTP lint
    http_lint = os_utils.fixPath(runtime_path) .. "/http_lint",

    -- Plugins Data Directories
    plugins_data = os_utils.fixPath(runtime_path) .. "/plugins_data",

    -- Other
    templates = os_utils.fixPath(runtime_path) .. "/templates",
    modules = os_utils.fixPath(runtime_path) .. "/modules",
    httpdocs = os_utils.fixPath(runtime_path) .. "/httpdocs",

    -- Checks
    interface_scripts = os_utils.fixPath(runtime_path .. "/callbacks/interface/interface"),
    host_scripts = os_utils.fixPath(runtime_path .. "/callbacks/interface/host"),
    network_scripts = os_utils.fixPath(runtime_path .. "/callbacks/interface/network"),
    flow_scripts = os_utils.fixPath(runtime_path .. "/callbacks/interface/flow"),
    syslog = os_utils.fixPath(runtime_path .. "/callbacks/system/syslog"),
    snmp_scripts = os_utils.fixPath(runtime_path .. "/callbacks/system/snmp_device"),
    system_scripts = os_utils.fixPath(runtime_path .. "/callbacks/system/system"),
  }
end

-- ##############################################

--@brief Load a plugin file and possibly executes an onLoad method
--@return The loaded plugin file
local function load_plugin_file(full_path)
   local res = dofile(full_path)

   return res
end

-- ##############################################

-- NOTE: cannot save the definitions to a single file via the persistance
-- module because they may contain functions (e.g. in the i18n_description)
local function load_definitions(defs_dir, runtime_path)
   for fname in pairs(ntop.readdir(defs_dir) or {}) do
      if fname:ends(".lua") then
	 local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
	 local full_path = os_utils.fixPath(defs_dir .. "/" .. fname)
	 local def_script = load_plugin_file(full_path)
	 -- Verify the definitions
	 if(type(def_script) ~= "table") then
	    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Error loading definition from %s", full_path))
	    return(false)
	 end

	 local ntopng_alert_definition = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/alert_definitions/"..fname)
	 if ntop.exists(ntopng_alert_definition) then
	    -- Prevent plugin alert definitions from overwriting alert definitions under modules
	    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Cannot copy plugin alert definition from %s (alert already defined in %s)", full_path, ntopng_alert_definition))
	 else
	    -- tprint({"copying", fname, defs_dir, runtime_path})
	    file_utils.copy_file(fname, defs_dir, runtime_path)
	 end
      end
   end

   return(true)
end

-- ##############################################

local function load_plugin_definitions(plugin)
  -- Reset all the possibly existing (and loaded) definitions
  -- as new alert definitions are being loaded
  local alert_consts = require "alert_consts"
  alert_consts.resetDefinitions()

  -- Now that existing alert definitions are clean, new alert definitions
  -- can safely be loaded
  local alert_definitions = RUNTIME_PATHS.alert_definitions

  return load_definitions(os_utils.fixPath(plugin.path .. "/alert_definitions"), alert_definitions)
end

-- ##############################################

-- @brief Loads the ntopng plugins into a single directory tree.
-- @notes This should be called at startup. It clears and populates the
-- shadow_dir first, then swaps it with the current_dir. This prevents
-- other threads to see intermediate states and half-populated directories.
function plugins_utils.loadPlugins()
  local path_map = {}

  -- Init runtime Path
  init_runtime_paths()

  for _, path in pairs(RUNTIME_PATHS) do
    ntop.mkdir(path)
  end

  -- Make sure to invalidate the (possibly) already required alert_consts which depends on alert definitions.
  -- By invalidating the module, we make sure all the newly loaded alert definitions will be picked up by any
  -- subsequent `require "alert_consts"`
  package.loaded["alert_consts"] = nil

  -- Remove the list of system scripts enabled, re-added from the checks.lua file
  -- deleteCachePattern("ntonpng.cache.checks.available_system_modules.*")

  -- Reload checks with their configurations
  local checks = require "checks"
  checks.initDefaultConfig()
  checks.loadUnloadUserScripts(true --[[ load --]])

  return(true)
end

-- ##############################################

function plugins_utils.loadSchemas(granularity)
   init_runtime_paths()
   lua_path_utils.package_path_prepend(RUNTIME_PATHS.ts_schemas)

   for plugin_name in pairs(ntop.readdir(RUNTIME_PATHS.ts_schemas)) do
      local ts_dir = os_utils.fixPath(RUNTIME_PATHS.ts_schemas .. "/" .. plugin_name)
      local files_to_load = {}

      if(granularity ~= nil) then
	 -- Only load schemas for the specified granularity
	 local fgran = granularity..".lua"
	 local fgran_path = os_utils.fixPath(ts_dir.."/"..fgran)

	 if ntop.exists(fgran_path) then
	    files_to_load = {fgran}
	 else
	    -- Schema doesn't exist for `plugin_name` at the requested granularity.
	    -- This is normal, it's not mandatory for a plugin to define schemas or to
	    -- define a schema for any granularity
	 end
      else
	 -- load all
	 files_to_load = ntop.readdir(ts_dir)
      end

      for _, fname in pairs(files_to_load) do
	 if fname:ends(".lua") then
	    local fgran = string.sub(fname, 1, string.len(fname) - 4)
	    -- Plugin ts schemas are require-d using the dot-notation in the
	    -- require string name. Dots are used to navigate the base directory, RUNTIME_PATHS.ts_schemas,
	    -- which has been prepended to the path.
	    -- Examples:
	    --   require(active_monitoring.hour)
	    --   require(active_monitoring.5mins)
	    --   require(active_monitoring.min)
	    --   require(score.min)
	    --   require(influxdb_monitor.5mins)
	    local req_name = string.format("%s.%s", plugin_name, fgran)
	    require(req_name)
	 end
      end
   end
end

-- ##############################################

function plugins_utils.getMenuEntries()
  init_runtime_paths()
  local menu = {}
  local entries_data = {}

  lua_path_utils.package_path_prepend(plugins_utils.getRuntimePath())

  for fname in pairs(ntop.readdir(RUNTIME_PATHS.menu_items)) do
    local full_path = os_utils.fixPath(RUNTIME_PATHS.menu_items .. "/" .. fname)
    local plugin_key = string.sub(fname, 1, string.len(fname)-4)

    local req_name = string.format("%s.%s", PLUGIN_RELATIVE_PATHS.menu_items, plugin_key)
    local menu_entry = require(req_name)

    if(menu_entry and ((not menu_entry.is_shown) or menu_entry.is_shown())) then
      -- Don't add any getHttpPrefix to the url here, it's the caller that
      -- can potentially add it
      menu_entry.url = "/plugins/" .. menu_entry.script
      menu[plugin_key] = menu_entry

      if menu_entry.menu_entry then
        entries_data[menu_entry.menu_entry.key] = menu_entry.menu_entry
      end
    end
  end

  return menu, entries_data
end

-- ##############################################

function plugins_utils.getMonitorUrl(script)
  return(ntop.getHttpPrefix() .. "/lua/monitor/" .. script)
end

-- ##############################################

function plugins_utils.timeseriesCreationEnabled()
   return areSystemTimeseriesEnabled()
end

-- ##############################################

-- @brief Retrieve the runtime templates directory of the plugin
-- @param plugin_name the plugin name
-- @return the runtime directory path
function plugins_utils.getPluginTemplatesDir(plugin_name)
  init_runtime_paths()

  local path = dirs.installdir .. "/httpdocs/templates/pages/notifications/" .. (plugin_name or '')

  return os_utils.fixPath(path)
end

-- ##############################################

-- Descending sort by priority
local function endpoint_sorter(a, b)
  if((a.prio ~= nil) and (b.prio == nil)) then
    return(true)
  elseif((a.prio == nil) and (b.prio ~= nil)) then
    return(false)
  elseif(a.prio ~= b.prio) then
    return(a.prio > b.prio)
  end

  -- Use the endpoint key to fix a defined sort order
  return(a.key > b.key)
end

-- ##############################################

-- This function is going to get the list of available notifications/endpoint
local function get_available_notification(path, rv)
  -- Get Endpoints files, like discord.lua, slack.lua ecc.
  local base_path = os_utils.fixPath(dirs.installdir .. path)
  lua_path_utils.package_path_prepend(base_path)

  for fname in pairs(ntop.readdir(base_path)) do
     if fname:ends(".lua") then
       local full_path = os_utils.fixPath(base_path .. "/" .. fname)
       local key = string.sub(fname, 1, string.len(fname) - 4)

       -- Check if the endpoint has a valid function to handle the notification
       local endpoint = require(key)
       if(endpoint) then
           if((type(endpoint.isAvailable) ~= "function") or endpoint.isAvailable()) then
             endpoint.full_path = full_path
             endpoint.key = key

             rv[#rv + 1] = endpoint
           end
       else
           traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load alert endpoint '%s'", full_path))
       end
     end
  end

  return rv
end

-- ##############################################

-- @brief Get the available alert endpoints
-- @return a sorted table, in order of priority, for the alert endpoints
function plugins_utils.getLoadedAlertEndpoints()
  init_runtime_paths()
  local rv = {}

  -- Community endpoints
  rv = get_available_notification("/scripts/lua/modules/notifications/endpoints/", rv)
  
  -- Pro, Enterprise M and Enterprise L endpoints
  if ntop.isPro() then
    rv = get_available_notification("/pro/scripts/lua/notifications/endpoints/", rv)
  end

  -- Sort by priority (higher priority first)
  table.sort(rv, endpoint_sorter)

  return(rv)
end

-- ##############################################

function plugins_utils.extendLintParams(http_lint, params)
   init_runtime_paths()

   lua_path_utils.package_path_prepend(RUNTIME_PATHS.http_lint)
   for fname in pairs(ntop.readdir(RUNTIME_PATHS.http_lint)) do
      local key = string.sub(fname, 1, string.len(fname) - 4)
      local lint = require(key)

      if(lint == nil) then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load lint for '%s'", key))
	 goto continue
      end

      if(lint.getAdditionalParameters == nil) then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing mandatory function 'getAdditionalParameters' in '%s'", key))
	 goto continue
      end

      local rv = lint.getAdditionalParameters(http_lint)

      if(type(rv) ~= "table") then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("function 'getAdditionalParameters' in '%s' returned a non-table value", key))
	 goto continue
      end

      for k, v in pairs(rv) do
	 params[k] = v
      end

      ::continue::
   end
end

-- ##############################################

-- @brief Render an html template located into the plugin templates directory
function plugins_utils.renderTemplate(plugin_name, template_file, context)
  init_runtime_paths()

  -- Locate the template file under the plugin directory
  -- e.g. /home/biscosi/ntopng/httpdocs/templates/pages/notifications/webhook_endpoint.template
  local full_path = os_utils.fixPath(plugins_utils.getPluginTemplatesDir() .. "/" .. plugin_name .. "/" .. template_file)

  -- If no template is found...
  if not ntop.exists(full_path) then
     -- Attempt at locating the template class under modules (global to ntopng)
     full_path = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/check_templates/"..template_file)
  end

  return template_utils.gen(full_path, context, true --[[ using full path ]])
end

-- ##############################################

-- @brief Load a plugin Lua template, e.g., those used for plugin checks
function plugins_utils.loadTemplate(plugin_name, template_file)
   -- Attempt at locating the template class under the plugin templates directory
   -- Locate the template directory of the plugin containing this user script
   local plugin_template_path = plugins_utils.getPluginTemplatesDir(plugin_name)

   -- Get the actual template path, using the template name
   local template_path = os_utils.fixPath(plugin_template_path.."/"..template_file..".lua")

   -- If the plugin file exists..
   if ntop.exists(template_path) then
      -- Do the necessary require
      init_runtime_paths()

      lua_path_utils.package_path_prepend(RUNTIME_PATHS.templates)

      local req_name = string.format("%s.%s", plugin_name, template_file)
      local req = require(req_name)

      return req
   end

   -- No template found
   return nil
end

-- ##############################################

-- @brief Load a module located inside a plugin. This is equivalent to the
-- lua "require ..." of the builting ntopng modules
function plugins_utils.loadModule(plugin_name, module_name)
   init_runtime_paths()

   lua_path_utils.package_path_prepend(RUNTIME_PATHS.modules)

   local req_name = string.format("%s.%s", plugin_name, module_name)
   local req = require(req_name)

   return req
end

-- ##############################################

return(plugins_utils)
