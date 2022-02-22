--
-- (C) 2019-22 - ntop.org
--

-- Includes
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

local os_utils = require("os_utils")
local file_utils = require("file_utils")
local template_utils = require("template_utils")
local lua_path_utils = require("lua_path_utils")
require "lua_trace"

-- ##############################################

--[[
  IMPORTANT NOTE. scripts include:
    - alert_definitions: 'old' alerts definition, developed in Lua (like Interface and Network alerts)
    - check_definitions: 'new' alerts definition, developed in C++
    - locales: languages
    - ts_schemas: timeseries schemas
    - web_gui: html templates of some scripts (not all of them)
    - menu_items: navigation menu used in the web gui
    - alert_endpoints: endpoints/recipients list
    - http_lint: clear the data received by the web gui to avoid Scripts Injection Attacks
    - templates: containing web gui html templates
    - modules: lua modules, containing functions, variables, ecc.
    - callbacks: periodic callbacks executed, like checks, timeseries, ecc.
    - httpdocs: client side files (JS, HTML, CSS).
]]

local script_manager = {}

-- ##############################################

local cached_runtime_dir = nil

-- @brief Return the path of the scripts
function script_manager.getRuntimePath()
  if(not cached_runtime_dir) then
    cached_runtime_dir = ntop.getCurrentScriptsDir()
  end

  return(cached_runtime_dir)
end

-- ##############################################

-- Local variables
local runtime_path = script_manager.getRuntimePath()
local MENU_ITEMS_PATH = "menu_items"
local RUNTIME_PATHS = {
  -- Definitions
  alert_definitions = os_utils.fixPath(runtime_path .. "/alert_definitions"),
  check_definitions = os_utils.fixPath(runtime_path .. "/check_definitions"),

  -- Locales
  locales = os_utils.fixPath(runtime_path .. "/locales"),

  -- Timeseries
  ts_schemas = os_utils.fixPath(runtime_path .. "/ts_schemas"),

  -- Web Gui
  web_gui = os_utils.fixPath(runtime_path) .. "/scripts",
  menu_items = os_utils.fixPath(runtime_path.."/"..MENU_ITEMS_PATH),

  -- Alert endpoints
  alert_endpoints = os_utils.fixPath(runtime_path) .. "/alert_endpoints",

  -- HTTP lint
  http_lint = os_utils.fixPath(runtime_path) .. "/http_lint",

  -- TODO: rename scripts_data
  -- Scripts Data Directories
  scripts_data = os_utils.fixPath(runtime_path) .. "/scripts_data",

  -- Templates
  templates = os_utils.fixPath(runtime_path) .. "/templates",
  
  -- Lua Modules
  modules = os_utils.fixPath(runtime_path) .. "/modules",
  
  -- Client Side Files
  httpdocs = os_utils.fixPath(runtime_path) .. "/httpdocs",

  -- Callbacks
  interface_scripts = os_utils.fixPath(runtime_path .. "/callbacks/interface/interface"),
  host_scripts = os_utils.fixPath(runtime_path .. "/callbacks/interface/host"),
  network_scripts = os_utils.fixPath(runtime_path .. "/callbacks/interface/network"),
  flow_scripts = os_utils.fixPath(runtime_path .. "/callbacks/interface/flow"),
  syslog = os_utils.fixPath(runtime_path .. "/callbacks/system/syslog"),
  snmp_scripts = os_utils.fixPath(runtime_path .. "/callbacks/system/snmp_device"),
  system_scripts = os_utils.fixPath(runtime_path .. "/callbacks/system/system"),
}

-- ##############################################

-- @brief Loads the ntopng scripts into a single directory.
function script_manager.loadScripts()
  for _, path in pairs(RUNTIME_PATHS) do
    ntop.mkdir(path)
  end

  -- Make sure to invalidate the (possibly) already required alert_consts which depends on alert definitions.
  -- By invalidating the module, we make sure all the newly loaded alert definitions will be picked up by any
  -- subsequent `require "alert_consts"`
  package.loaded["alert_consts"] = nil

  -- Remove the list of system scripts enabled, re-added from the checks.lua file
  deleteCachePattern("ntonpng.cache.checks.available_system_modules.*")

  -- Reload checks with their configurations
  local checks = require "checks"
  checks.initDefaultConfig()
  checks.loadUnloadUserScripts(true --[[ load --]])

  return(true)
end

-- ##############################################

-- @brief Loads the timeseries schemas.
function script_manager.loadSchemas(granularity)
   lua_path_utils.package_path_prepend(RUNTIME_PATHS.ts_schemas)

   for ts_name in pairs(ntop.readdir(RUNTIME_PATHS.ts_schemas)) do
      local ts_dir = os_utils.fixPath(RUNTIME_PATHS.ts_schemas .. "/" .. ts_name)
      local files_to_load = {}

      if(granularity ~= nil) then
        -- Only load schemas for the specified granularity
        local ts_granularity_file = granularity..".lua"
        local ts_granularity_path = os_utils.fixPath(ts_dir.."/"..ts_granularity_file)

        if ntop.exists(ts_granularity_path) then
          files_to_load = { ts_granularity_file }
        end
      else
	      -- Load all granularities
	      files_to_load = ntop.readdir(ts_dir)
      end

      for _, fname in pairs(files_to_load) do
        if fname:ends(".lua") then
            local fgran = string.sub(fname, 1, string.len(fname) - 4)
            -- Ts schemas are required using the dot notation in the
            -- require string name. Dots are used to navigate the base directory, RUNTIME_PATHS.ts_schemas,
            -- which has been prepended to the path.
            -- Examples:
            --   require(active_monitoring.hour)
            --   require(active_monitoring.5mins)
            --   require(active_monitoring.min)
            --   require(score.min)
            --   require(influxdb_monitor.5mins)
            local req_name = string.format("%s.%s", ts_name, fgran)
            require(req_name)
        end
      end
   end
end

-- ##############################################

-- @brief Return the menu entries
function script_manager.getMenuEntries()
  local menu = {}
  local entries_data = {}

  lua_path_utils.package_path_prepend(script_manager.getRuntimePath())

  for fname in pairs(ntop.readdir(RUNTIME_PATHS.menu_items)) do
    local req_name = string.format("%s.%s", MENU_ITEMS_PATH, fname)
    local menu_entry = require(req_name)

    if(menu_entry and ((not menu_entry.is_shown) or menu_entry.is_shown())) then
      -- Don't add any getHttpPrefix to the url here, it's the caller that
      -- can potentially add it
      menu_entry.url = "/scripts/" .. menu_entry.script
      menu[fname] = menu_entry

      if menu_entry.menu_entry then
        entries_data[menu_entry.menu_entry.key] = menu_entry.menu_entry
      end
    end
  end

  return menu, entries_data
end

-- ##############################################

-- @brief Return monitor pages URL (e.g. /lua/monitor/redis_monitor.lua)
function script_manager.getMonitorUrl(script)
  return(ntop.getHttpPrefix() .. "/lua/monitor/" .. script)
end

-- ##############################################

-- @brief Checks if the system timeseries are enabled
function script_manager.systemTimeseriesEnabled()
   return areSystemTimeseriesEnabled()
end

-- ##############################################

-- @brief Retrieve the runtime templates directory of the script
-- @param script_name the script name
-- @return the runtime directory path
function script_manager.getScriptTemplatesDir(script_name)
  local path = dirs.installdir .. "/httpdocs/templates/pages/" .. (script_name or '')
  return os_utils.fixPath(path)
end

-- ##############################################

-- @brief Return the list of available endpoint/recipients,
--        named even 'notification'
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

-- @brief Sorter used to sort endpoints by priority
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

-- @brief Get the available alert endpoints
-- @return a sorted table, in order of priority, for the alert endpoints
function script_manager.getLoadedAlertEndpoints()
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

-- @brief Extends the http_lint using all the lint available
function script_manager.extendLintParams(http_lint, params)
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

-- @brief Render an html template located into the templates directory
function script_manager.renderNotificationTemplate(script_name, template_file, context)
  -- Locate the template file into the script directory, e.g. httpdocs/templates/pages/notifications/webhook_endpoint.template
  local full_path = script_manager.getScriptTemplatesDir("notifications/" .. script_name .. "/" .. template_file)

  -- If no template is found attempt to locate the template under the modules
  if not ntop.exists(full_path) then
     full_path = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/check_templates/"..template_file)
  end

  return template_utils.gen(full_path, context, true --[[ using full path ]])
end

-- ##############################################

-- @brief Load an alert template
function script_manager.loadTemplate(script_name, template_file)
  -- Checking the standard templates path, '/httpdocs/templates/pages/'
  local script_template_path = script_manager.getScriptTemplatesDir(script_name)
  local template_path = os_utils.fixPath(script_template_path.."/"..template_file..".lua")
  local req = nil

   -- Templates not found
  if ntop.exists(template_path) then
    -- Do the necessary require
    lua_path_utils.package_path_prepend(RUNTIME_PATHS.templates)

    local req_name = string.format("%s.%s", script_name, template_file)
    req = require(req_name)
  end

  return req
end

-- ##############################################

return(script_manager)
