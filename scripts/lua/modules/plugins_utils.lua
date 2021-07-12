--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


local plugins_utils = {}
local os_utils = require("os_utils")
local persistence = require("persistence")
local file_utils = require("file_utils")
local template_utils = require("template_utils")
local lua_path_utils = require("lua_path_utils")
require "lua_trace"

local dirs = ntop.getDirs()

-- enable debug tracing
local do_trace = false

-- How deep the recursive plugins search should go into subdirectories
local MAX_RECURSION = 2

plugins_utils.COMMUNITY_SOURCE_DIR = os_utils.fixPath(dirs.scriptdir .. "/plugins")
plugins_utils.PRO_SOURCE_DIR = os_utils.fixPath(dirs.installdir .. "/pro/scripts/pro_plugins")
plugins_utils.ENTERPRISE_M_SOURCE_DIR = os_utils.fixPath(dirs.installdir .. "/pro/scripts/enterprise_m_plugins")
plugins_utils.ENTERPRISE_L_SOURCE_DIR = os_utils.fixPath(dirs.installdir .. "/pro/scripts/enterprise_l_plugins")

local PLUGIN_RELATIVE_PATHS = {
   menu_items = "menu_items",
   metadata = "plugins_metadata",
   modules = "modules",
}
local RUNTIME_PATHS = {}
local METADATA = nil

-- ##############################################

-- The runtime path can change when the user reloads the plugins.
-- We need to cache this into the same vm to ensure that all the lua
-- scripts into this vm use the same directory.
local cached_runtime_dir = nil

function plugins_utils.getRuntimePath()
  if(not cached_runtime_dir) then
    cached_runtime_dir = ntop.getCurrentPluginsDir()
  end

  return(cached_runtime_dir)
end

local function getMetadataPath()
  return(os_utils.fixPath(plugins_utils.getRuntimePath() .. "/"..PLUGIN_RELATIVE_PATHS.metadata..".lua"))
end

-- ##############################################

local function clearInternalState()
  RUNTIME_PATHS = {}
  METADATA = nil
  cached_runtime_dir = nil

  -- Tell lua to forget about require-d metadata. This is necessary as plugins may have been swapped betwenn plugins0/ and plugins1/.
  -- However, as PLUGIN_RELATIVE_PATHS.metadata is the same, lua would not reload it unless it's entry in package.loaded is reset.
  package.loaded[PLUGIN_RELATIVE_PATHS.metadata] = nil
end

-- ##############################################

-- @brief Recursively search for plugins starting from `source_dir`
-- @param edition A string indicating the plugin edition. One of `community`, `pro`, `enterprise_m` or `enterprise_l`
-- @param source_dir The path of the directory to start the plugin search from
-- @param max_recursion Maximum number of recursive calls to this function
-- @param plugins A lua table with all the plugins found
-- @param plugins_with_deps A lua table with all the plugins found which have other plugins as dependencies
local function recursivePluginsSearch(edition, source_dir, max_recursion, plugins, plugins_with_deps)
   -- Prepend the current `source_dir` to the Lua path - this is necessary for doing the require
   lua_path_utils.package_path_prepend(source_dir)
   local source_dir_contents = ntop.readdir(source_dir)

   for plugin_name in pairs(source_dir_contents) do
      local plugin_dir = os_utils.fixPath(source_dir .. "/" .. plugin_name)
      local plugin_info = os_utils.fixPath(plugin_dir .. "/manifest.lua")

      if ntop.exists(plugin_info) then
	 -- If there's a manifest, we are in a plugin directory
	 local req_name = string.format("%s.manifest", plugin_name)
	 local metadata = require(req_name)
	 local mandatory_fields = {"title", "description", "author"}

	 if not metadata then
	    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load manifest.lua in '%s'", plugin_name))
	    goto continue
	 end

	 for _, field in pairs(mandatory_fields) do
	    if not metadata[field] then
	       traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing mandatory field '%s' in manifest.lua of '%s'", field, plugin_name))
	       goto continue
	    end
	 end

	 if metadata.disabled then
	    -- The plugin is disabled, skip it
	    goto continue
	 end

	 -- Augument information
	 metadata.path = plugin_dir
	 metadata.key = plugin_name
	 metadata.edition = edition

	 if not table.empty(metadata.dependencies) then
	    plugins_with_deps[plugin_name] = metadata
	 else
	    plugins[plugin_name] = metadata
	 end
      elseif ntop.isdir(plugin_dir) then
	 if max_recursion > 0 then
	    -- Recursively see if this is a directory containing other plugins
	    recursivePluginsSearch(edition, plugin_dir, max_recursion - 1, plugins, plugins_with_deps)
	 else
	    -- Maximum recursion hit. must stop
	    traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Unable to load '%s'. Too many recursion levels.", plugin_dir))
	 end
      end

      ::continue::
   end
end

-- ##############################################

-- @brief Lists the all available plugins
-- @returns a sorted table with plugins as values.
-- @notes Plugins must be loaded based according to the sort order to honor dependencies
local function listPlugins(community_plugins_only)
   local plugins = {}
   local plugins_with_deps = {}
   local rv = {}
   local source_dirs = {{"community", plugins_utils.COMMUNITY_SOURCE_DIR}}

   if not community_plugins_only and ntop.isPro() then
      source_dirs[#source_dirs + 1] = {"pro", plugins_utils.PRO_SOURCE_DIR}

      if ntop.isEnterpriseM() then
	 source_dirs[#source_dirs + 1] = {"enterprise_m", plugins_utils.ENTERPRISE_M_SOURCE_DIR}
      end

      if ntop.isEnterpriseL() then
	 source_dirs[#source_dirs + 1] = {"enterprise_l", plugins_utils.ENTERPRISE_L_SOURCE_DIR}
      end
   end

   for _, source_conf in ipairs(source_dirs) do
      local edition = source_conf[1]
      local source_dir = source_conf[2]

      recursivePluginsSearch(edition, source_dir, MAX_RECURSION, plugins, plugins_with_deps)
   end

   -- Add plugins without dependencies to the result
   for _, plugin_metadata in pairs(plugins) do
      rv[#rv + 1] = plugin_metadata
   end

   -- Check basic dependencies.
   -- No recursion is supported (e.g. dependency on a plugin which has dependencies itself)
   for plugin_name, metadata in pairs(plugins_with_deps) do
      local satisfied = true

      for _, dep_name in pairs(metadata.dependencies) do
	 if not plugins[dep_name] then
	    satisfied = false

	    if do_trace then
	       io.write(string.format("Skipping plugin '%s' with unmet depedendency ('%s')\n", plugin_name, dep_name))
	    end

	    break
	 end
      end

      if satisfied then
	 plugins[plugin_name] = metadata
	 rv[#rv + 1] = metadata
      end
   end

   return(rv)
end

-- ##############################################

local function init_runtime_paths()
  local runtime_path = plugins_utils.getRuntimePath()

  RUNTIME_PATHS = {
    -- Definitions
    alert_definitions = os_utils.fixPath(runtime_path .. "/alert_definitions"),
    status_definitions = os_utils.fixPath(runtime_path .. "/status_definitions"),
    pro_status_definitions = os_utils.fixPath(runtime_path .. "/status_definitions/pro"),

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

local function load_plugin_alert_definitions(plugin)
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

local function load_plugin_ts_schemas(plugin)
  local src_path = os_utils.fixPath(plugin.path .. "/ts_schemas")
  local ts_path = os_utils.fixPath(RUNTIME_PATHS.ts_schemas .. "/" .. plugin.key)

  if ntop.exists(src_path) then
    ntop.mkdir(ts_path)

    return(
      file_utils.recursive_copy(src_path, ts_path)
    )
  end

  return(true)
end

-- ##############################################

local function load_plugin_i18n(locales, default_locale, plugin)
  local locales_dir = os_utils.fixPath(plugin.path .. "/locales")
  local locales_path = ntop.readdir(locales_dir)

  if table.empty(locales_path) then
    return(true)
  end

  -- Ensure that the plugin localization will not override any existing
  -- key
  if default_locale[plugin.key] then
    traceError(TRACE_WARNING, TRACE_CONSOLE, string.format(
      "Plugin name %s overlaps with an existing i18n key. Please rename the plugin.", plugin.key))
    return(false)
  end

  for fname in pairs(locales_path) do
    if string.ends(fname, ".lua") then
      local full_path = os_utils.fixPath(locales_dir .. "/" .. fname)
      local locale = persistence.load(full_path)

      if locale then
        locales[fname] = locales[fname] or {}
        locales[fname][plugin.key] = locale

        if do_trace then
          io.write("\ti18n: " .. fname .. "\n")
        end
      else
        return(false)
      end
    end
  end

  return(true)
end

-- ##############################################

local function load_plugin_lint(plugin)
  local lint_path = os_utils.fixPath(plugin.path .. "/http_lint.lua")

  if(ntop.exists(lint_path)) then
    if(not file_utils.copy_file(nil, lint_path,
        os_utils.fixPath(RUNTIME_PATHS.http_lint .. "/" .. plugin.key .. ".lua"))) then
      return(false)
    end
  end

  return(true)
end

-- ##############################################

local function load_plugin_checks(paths_to_plugin, plugin)
  local scripts_path = os_utils.fixPath(plugin.path .. "/checks")
  local paths_map = {}
  local extn = ".lua"
  local rv = (
    file_utils.recursive_copy(os_utils.fixPath(scripts_path .. "/interface"), RUNTIME_PATHS.interface_scripts, paths_map, extn) and
    file_utils.recursive_copy(os_utils.fixPath(scripts_path .. "/host"), RUNTIME_PATHS.host_scripts, paths_map, extn) and
    file_utils.recursive_copy(os_utils.fixPath(scripts_path .. "/network"), RUNTIME_PATHS.network_scripts, paths_map, extn) and
    file_utils.recursive_copy(os_utils.fixPath(scripts_path .. "/flow"), RUNTIME_PATHS.flow_scripts, paths_map, extn) and
    file_utils.recursive_copy(os_utils.fixPath(scripts_path .. "/syslog"), RUNTIME_PATHS.syslog, paths_map, extn) and
    file_utils.recursive_copy(os_utils.fixPath(scripts_path .. "/snmp_device"), RUNTIME_PATHS.snmp_scripts, paths_map, extn) and
    file_utils.recursive_copy(os_utils.fixPath(scripts_path .. "/system"), RUNTIME_PATHS.system_scripts, paths_map, extn)
  )

  for runtime_path, source_path in pairs(paths_map) do
    -- Ensure that the script does not have errors
    local res = load_plugin_file(runtime_path)

    if(res == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Skipping bad user script '%s' in plugin '%s'", source_path, plugin.key))
      os.remove(runtime_path)
    else
      paths_to_plugin[runtime_path] = {
        source_path = source_path,
        plugin = plugin,
      }
    end
  end

  return(rv)
end

-- ##############################################

local function load_plugin_alert_endpoints(plugin)
   local endpoints_path = os_utils.fixPath(plugin.path .. "/alert_endpoints")
   local endpoints_template_path = os_utils.fixPath(plugin.path .. "/templates")

   if not ntop.exists(endpoints_path) then
      -- No alert endpoints for this plugin
      return true
   end

   for fname in pairs(ntop.readdir(endpoints_path)) do
      if fname:ends(".lua") then
	 -- Execute the alert endpoint and call its method onLoad, if present
	 local fname_path = os_utils.fixPath(endpoints_path .. "/" .. fname)
	 local endpoint = load_plugin_file(fname_path)

	 if not endpoint then
	    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unable to load endpoint '%s'", fname))
	    return false
	 end

	 -- Check for configuration templates existence
	 if endpoint.endpoint_template and endpoint.endpoint_template.template_name then
	    -- Stop if the template doesn't exist
	    if not ntop.exists(os_utils.fixPath(endpoints_template_path.."/"..endpoint.endpoint_template.template_name)) then
	       traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing conf template '%s' in '%s' for endpoint '%s'",
								    endpoint.endpoint_template.template_name,
								    endpoints_template_path,
								    fname))
	       return false
	    end
	 end

	 -- Check for recipient templates existence
	 if endpoint.recipient_template and endpoint.recipient_template.template_name then
	    -- Return if the recipient template doesn't exist
	    if not ntop.exists(os_utils.fixPath(endpoints_template_path.."/"..endpoint.recipient_template.template_name)) then
	       traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing recipient template '%s' in '%s' for endpoint '%s'",
								    endpoint.recipient_template.template_name,
								    endpoints_template_path,
								    fname))
	       return false
	    end
	 end

	 if not file_utils.copy_file(fname, endpoints_path, RUNTIME_PATHS.alert_endpoints) then
	    return false
	 end


	 if endpoint and endpoint.onLoad then
	    endpoint.onLoad()
	 end
      end
   end

   return true
end

-- ##############################################

local function load_plugin_web_gui(plugin)
  local gui_dir = os_utils.fixPath(plugin.path .. "/web_gui")

  for fname in pairs(ntop.readdir(gui_dir)) do
    if(fname == "menu.lua") then
      local full_path = os_utils.fixPath(gui_dir .. "/" .. fname)
      local menu_entry = load_plugin_file(full_path)

      if(menu_entry) then
        if(menu_entry.label == nil) then
          traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing menu entry 'label' in %s (menu.lua)", plugin.key))
          return(false)
        elseif(menu_entry.script == nil) then
          traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing menu entry 'script' in %s (menu.lua)", plugin.key))
          return(false)
        else
          -- Check that the menu entry exists
          local script_path = os_utils.fixPath(gui_dir .. "/" .. menu_entry.script)

          if(not ntop.exists(script_path)) then
            traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Menu entry script path '%s' does not exists in %s", script_path, plugin.key))
            return(false)
          end

          if(not file_utils.copy_file(nil, full_path,
              os_utils.fixPath(RUNTIME_PATHS.menu_items .. "/" .. plugin.key .. ".lua"))) then
            return(false)
          end
        end
      end
    else
      if not file_utils.copy_file(fname, gui_dir, RUNTIME_PATHS.web_gui) then
        return(false)
      end
    end
  end

  return(true)
end

-- ##############################################

-- A plugin can specify additional directories to load with the "data_dirs"
-- field in its manifest.lua . The plugin can then retrieve the runtime path
-- by using the plugins_utils.getPluginDataDir() api
local function load_plugin_data_dirs(plugin)
  for _, dir in pairs(plugin.data_dirs or {}) do
    local data_dir = os_utils.fixPath(plugin.path .. "/" .. dir)

    if ntop.exists(data_dir) then
      local dest_path = os_utils.fixPath(RUNTIME_PATHS.plugins_data .. "/" .. plugin.key .. "/" .. dir)

      ntop.mkdir(dest_path)

      file_utils.recursive_copy(data_dir, dest_path)
    end
  end

  return(true)
end

-- ##############################################

local function load_plugin_other(plugin)
  local templates_dir = os_utils.fixPath(plugin.path .. "/templates")
  local modules_dir = os_utils.fixPath(plugin.path .. "/modules")
  local httpdocs_dir = os_utils.fixPath(plugin.path .. "/httpdocs")
  local rv = true

  if ntop.exists(templates_dir) then
    local path = plugins_utils.getPluginTemplatesDir(plugin.key)
    ntop.mkdir(path)
    rv = rv and file_utils.recursive_copy(templates_dir, path)
  end

  if ntop.exists(modules_dir) then
    local path = os_utils.fixPath(RUNTIME_PATHS.modules.. "/" ..plugin.key)
    ntop.mkdir(path)
    rv = rv and file_utils.recursive_copy(modules_dir, path)
  end

  if ntop.exists(httpdocs_dir) then
    local path = os_utils.fixPath(RUNTIME_PATHS.httpdocs.. "/" ..plugin.key)
    ntop.mkdir(path)
    rv = rv and file_utils.recursive_copy(httpdocs_dir, path)
  end

  return(rv)
end

-- ##############################################

-- @brief Loads the ntopng plugins into a single directory tree.
-- @notes This should be called at startup. It clears and populates the
-- shadow_dir first, then swaps it with the current_dir. This prevents
-- other threads to see intermediate states and half-populated directories.
function plugins_utils.loadPlugins(community_plugins_only)
  local locales_utils = require("locales_utils")
  local plugins = listPlugins(community_plugins_only)
  local loaded_plugins = {}
  local locales = {}
  local path_map = {}
  local en_locale = locales_utils.readDefaultLocale()
  local current_dir = ntop.getCurrentPluginsDir()
  local shadow_dir = ntop.getShadowPluginsDir()

  -- Clean up the shadow directory
  ntop.rmdir(shadow_dir)

  -- Use the shadow directory as the new base
  clearInternalState()
  cached_runtime_dir = shadow_dir

  init_runtime_paths()

  -- Ensure that the directory is writable
  ntop.mkdir(shadow_dir)
  local test_file = os_utils.fixPath(shadow_dir .. "/test")

  local outfile, err = io.open(test_file, "w")
  if(outfile) then
    outfile:close()
  end

  if(outfile == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Cannot write to the plugins directory: %s. Plugins will not be loaded!",
      err or shadow_dir))

    clearInternalState()

    return(false)
  end

  os.remove(test_file)

  for _, path in pairs(RUNTIME_PATHS) do
    ntop.mkdir(path)
  end

  -- Load plugin alert definitions, i.e., definitions found under <plugin_name>/alert_definitions
  -- alert definitions MUST be loaded before flow status definitions as, flow status definitions,
  -- may depend on alert definitions
  for _, plugin in ipairs(plugins) do
     load_plugin_alert_definitions(plugin)
  end

  -- Make sure to invalidate the (possibly) already required alert_consts which depends on alert definitions.
  -- By invalidating the module, we make sure all the newly loaded alert definitions will be picked up by any
  -- subsequent `require "alert_consts"`
  package.loaded["alert_consts"] = nil

  -- Load the plugins following the dependecies order
  for _, plugin in ipairs(plugins) do
    if community_plugins_only and plugin.edition ~= "community" then
       goto continue
    end

    -- Ensure that the depencies has been loaded as well
    for _, dep in pairs(plugin.dependencies or {}) do
       if not loaded_plugins[dep] then
	  traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Skipping plugin %s due to missing dependency '%s'", plugin.key, dep))
	  goto continue
       end
    end

    if do_trace then
      io.write(string.format("Loading plugin %s [edition: %s]\n", plugin.key, plugin.edition))
    end

    if load_plugin_i18n(locales, en_locale, plugin) and
        load_plugin_lint(plugin) and
        load_plugin_ts_schemas(plugin) and
        load_plugin_web_gui(plugin) and
        load_plugin_data_dirs(plugin) and
        load_plugin_other(plugin) and
        load_plugin_checks(path_map, plugin) and
        load_plugin_alert_endpoints(plugin) then
      loaded_plugins[plugin.key] = plugin
    else
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Errors occurred while processing plugin '%s'", plugin.key))
    end

    ::continue::
  end

  -- Save the locales
  for fname, plugins_locales in pairs(locales) do
    local locale_path = os_utils.fixPath(RUNTIME_PATHS.locales .. "/" .. fname)

    persistence.store(locale_path, plugins_locales)
    ntop.setDefaultFilePermissions(locale_path)
  end

  -- Save loaded plugins metadata
  -- See load_metadata()
  local plugins_metadata = {
    plugins = loaded_plugins,
    path_map = path_map,
  }

  persistence.store(getMetadataPath(), plugins_metadata)
  ntop.setDefaultFilePermissions(getMetadataPath())

  -- Swap the active plugins directory with the shadow
  clearInternalState()
  ntop.swapPluginsDir()
  deleteCachePattern("ntonpng.cache.checks.available_system_modules.*")

  -- Reload the periodic scripts to load the new plugins
  ntop.reloadPeriodicScripts()

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

function plugins_utils.checkReloadPlugins(when)
   local demo_ends_at = ntop.getInfo()["pro.demo_ends_at"]
   local time_delta = demo_ends_at - when
   local plugins_reloaded = false

   -- tprint({time_delta = time_delta, demo_ends_at = demo_ends_at, when = when, is_pro = ntop.isPro()})

   if ntop.getCache('ntopng.cache.force_reload_plugins') == '1' then
      -- Check and possibly reload plugins after a user has changed (e.g., applied or removed) a license
      -- from the web user interface (page about.lua)
      plugins_utils.loadPlugins(not ntop.isPro() --[[ reload only community if license is not pro --]])
      ntop.delCache('ntopng.cache.force_reload_plugins')
      plugins_reloaded = true
   elseif demo_ends_at and demo_ends_at > 0 and time_delta <= 10 and ntop.isPro() and not ntop.hasPluginsReloaded() then
      -- Checks and possibly reload plugins for demo licenses. In case of demo licenses,
      -- if within 10 seconds from the license expirations, a plugin reload is executed only for the community plugins
      plugins_utils.loadPlugins(true --[[ reload only community plugins --]])
      plugins_reloaded = true
   end

   if plugins_reloaded then
      ntop.reloadPlugins()
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

function plugins_utils.getUrl(script)
  return(ntop.getHttpPrefix() .. "/plugins/" .. script)
end

-- ##############################################

function plugins_utils.timeseriesCreationEnabled()
   return areSystemTimeseriesEnabled()
end

-- ##############################################

local function load_metadata()
   if not METADATA then
      local runtime_path = plugins_utils.getRuntimePath()
      lua_path_utils.package_path_prepend(runtime_path)

      -- Do the require via pcall to avoid Lua generating an exception.
      -- Print an error and a stacktrace when the require fails.
      local status
      status, METADATA = pcall(require, PLUGIN_RELATIVE_PATHS.metadata)

      if not status then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load plugins metadata file '%s'", PLUGIN_RELATIVE_PATHS.metadata))
	 tprint(debug.traceback())
      end
  end
end

-- ##############################################

-- @brief Retrieve the original source path of a user script
-- @param script_path the runtime path of the user script
-- @return the user script source path
function plugins_utils.getUserScriptSourcePath(script_path)
  load_metadata()

  if(not METADATA) then
    return(nil)
  end

  local info = METADATA.path_map[script_path]

  if info then
    return(info.source_path)
  end
end

-- ##############################################

-- @brief Retrieve the runtime data directory of the plugin, which is specified in the "data_dirs" directive of the plugin manifest.lua
-- @param plugin_key the plugin name
-- @param subdir an optional subdirectory of the datadir
-- @return the runtime directory path
function plugins_utils.getPluginDataDir(plugin_key, subdir)
  init_runtime_paths()

  local path = RUNTIME_PATHS.plugins_data .. "/" .. plugin_key

  if subdir then
    path = path .. "/" .. subdir
  end

  return os_utils.fixPath(path)
end

-- ##############################################

-- @brief Get the httpdocs directory of the plugin. This can be used to access
-- javascript, css and similar files
function plugins_utils.getHttpdocsDir(plugin_name)
  local dir = ternary(ntop.isPlugins0Dir(), "plugins0_httpdocs", "plugins1_httpdocs")

  -- See url_rewrite_patterns in HTTPserver.cpp
  return(os_utils.fixPath(ntop.getHttpPrefix() .. "/".. dir .."/" .. plugin_name))
end

-- ##############################################

-- @brief Retrieve the runtime templates directory of the plugin
-- @param plugin_name the plugin name
-- @return the runtime directory path
function plugins_utils.getPluginTemplatesDir(plugin_name)
  init_runtime_paths()

  local path = RUNTIME_PATHS.templates .. "/" .. plugin_name

  return os_utils.fixPath(path)
end

-- ##############################################

-- @brief Retrieve the plugin associated with the user script
-- @param script_path the runtime path of the user script
-- @return the associated plugin
function plugins_utils.getUserScriptPlugin(script_path)
  load_metadata()

  if(not METADATA) then
    return(nil)
  end

  local info = METADATA.path_map[script_path]

  if info then
    return(info.plugin)
  end
end

-- ##############################################

-- @brief Retrieve metadata of the loaded plugins
-- @return the loaded plugins metadata
function plugins_utils.getLoadedPlugins()
  load_metadata()

  if(not METADATA) then
    return({})
  end

  return(METADATA.plugins)
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

-- @brief Get the available alert endpoints
-- @return a sorted table, in order of priority, for the alert endpoints
function plugins_utils.getLoadedAlertEndpoints()
   init_runtime_paths()

   local rv = {}

   lua_path_utils.package_path_prepend(RUNTIME_PATHS.alert_endpoints)
   for fname in pairs(ntop.readdir(RUNTIME_PATHS.alert_endpoints) or {}) do
      if fname:ends(".lua") then
	 local full_path = os_utils.fixPath(RUNTIME_PATHS.alert_endpoints .. "/" .. fname)
	 local key = string.sub(fname, 1, string.len(fname) - 4)

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
  local full_path = os_utils.fixPath(plugins_utils.getPluginTemplatesDir(plugin_name) .. "/" .. template_file)

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

-- @brief Deletes the plugins runtime directories. This is usually called
-- in boot.lua to start fresh.
function plugins_utils.cleanup()
  ntop.rmdir(os_utils.fixPath(dirs.workingdir .. "/plugins"))
  ntop.rmdir(ntop.getCurrentPluginsDir())
  ntop.rmdir(ntop.getShadowPluginsDir())
  clearInternalState()
end

-- ##############################################

return(plugins_utils)
