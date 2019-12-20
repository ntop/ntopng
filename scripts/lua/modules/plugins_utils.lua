--
-- (C) 2019 - ntop.org
--

local plugins_utils = {}

local os_utils = require("os_utils")
local persistence = require("persistence")
require "lua_trace"

local dirs = ntop.getDirs()

-- enable debug tracing
local do_trace = false

plugins_utils.COMMUNITY_SOURCE_DIR = os_utils.fixPath(dirs.scriptdir .. "/plugins")
plugins_utils.PRO_SOURCE_DIR = os_utils.fixPath(dirs.installdir .. "/pro/scripts/pro_plugins")
plugins_utils.ENTERPRISE_SOURCE_DIR = os_utils.fixPath(dirs.installdir .. "/pro/scripts/enterprise_plugins")

-- NOTE: keep in sync with the HTTPServer runtime_dir
plugins_utils.PLUGINS_RUNTIME_PATH = os_utils.fixPath(dirs.workingdir .. "/plugins")

plugins_utils.PLUGINS_RUNTIME_METADATA = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/plugins_metadata.lua")

local RUNTIME_PATHS = {}
local METADATA = nil

-- ##############################################

-- @brief Lists the all available plugins
-- @returns a sorted table with plugins as values.
-- @notes Plugins must be loaded based according to the sort order to honor dependencies
function plugins_utils.listPlugins()
  local plugins = {}
  local rv = {}
  local source_dirs = {{"community", plugins_utils.COMMUNITY_SOURCE_DIR}}
  local plugins_with_deps = {}

  if ntop.isPro() then
    source_dirs[#source_dirs + 1] = {"pro", plugins_utils.PRO_SOURCE_DIR}

    if ntop.isEnterprise() then
      source_dirs[#source_dirs + 1] = {"enterprise", plugins_utils.ENTERPRISE_SOURCE_DIR}
    end
  end

  for _, source_conf in ipairs(source_dirs) do
    local edition = source_conf[1]
    local source_dir = source_conf[2]

    for plugin_name in pairs(ntop.readdir(source_dir)) do
      local plugin_dir = os_utils.fixPath(source_dir .. "/" .. plugin_name)
      local plugin_info = os_utils.fixPath(plugin_dir .. "/plugin.lua")

      if ntop.exists(plugin_info) then
        local metadata = dofile(plugin_info)
        local mandatory_fields = {"title", "description", "author", "version"}

        if(metadata == nil) then
          traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load plugin.lua in '%s'", plugin_name))
          goto continue
        end

        for _, field in pairs(mandatory_fields) do
          if(metadata[field] == nil) then
            traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing mandatory field '%s' in plugin.lua of '%s'", field, plugin_name))
            goto continue
          end
        end

        if(metadata.disabled) then
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
          rv[#rv + 1] = metadata
        end
      else
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing plugin.lua in '%s'", plugin_name))
      end

      ::continue::
    end
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
  RUNTIME_PATHS = {
    -- Definitions
    alert_definitions = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/alert_definitions"),
    status_definitions = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/status_definitions"),
    pro_alert_definitions = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/alert_definitions/pro"),
    pro_status_definitions = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/status_definitions/pro"),

    -- Locales
    locales = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/locales"),

    -- Timeseries
    ts_schemas = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/ts_schemas"),

    -- Web Gui
    web_gui = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH) .. "/scripts",
    menu_items = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH) .. "/menu_items",

    -- Alert endpoints
    alert_endpoints = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH) .. "/alert_endpoints",

    -- HTTP lint
    http_lint = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH) .. "/http_lint",

    -- User scripts
    interface_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/interface"),
    host_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/host"),
    network_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/network"),
    flow_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/flow"),
    syslog = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/system/syslog"),
    snmp_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/system/snmp_device"),
    system_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/system/system"),
  }
end

-- ##############################################

local function copy_file(fname, src_path, dst_path)
  local src
  local dst

  if(fname == nil) then
    src = src_path
    dst = dst_path
  else
    src = os_utils.fixPath(src_path .. "/" .. fname)
    dst = os_utils.fixPath(dst_path .. "/" .. fname)
  end

  local infile, err = io.open(src, "r")

  if(do_trace) then
    io.write(string.format("\tLoad [%s]\n", fname))
  end

  if(ntop.exists(dst)) then
    -- NOTE: overwriting is not allowed as it means that a file was already provided by
    -- another plugin
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Trying to overwrite existing file %s", dst))
    return(false)
  end

  if(infile == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not open file %s for read: %s", src, err or ""))
    return(false)
  end

  local instr = infile:read("*a")
  infile:close()

  local outfile, err = io.open(dst, "w")
  if(outfile == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not open file %s for write", dst, err or ""))
    return(false)
  end

  outfile:write(instr)
  outfile:close()

  ntop.setDefaultFilePermissions(dst)

  return(true)
end

local function recursive_copy(src_path, dst_path, path_map)
  for fname in pairs(ntop.readdir(src_path)) do
    if not copy_file(fname, src_path, dst_path) then
      return(false)
    end

    if path_map then
      path_map[os_utils.fixPath(dst_path .. "/" .. fname)] = os_utils.fixPath(src_path .. "/" .. fname)
    end
  end

  return(true)
end

-- ##############################################

-- NOTE: cannot save the definitions to a single file via the persistance
-- module because they may contain functions (e.g. in the i18n_description)
local function load_definitions(defs_dir, runtime_path, validator)
  for fname in pairs(ntop.readdir(defs_dir) or {}) do
    if string.ends(fname, ".lua") then
      local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
      local full_path = os_utils.fixPath(defs_dir .. "/" .. fname)
      local def_script = dofile(full_path)

      -- Verify the definitions
      if(type(def_script) ~= "table") then
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Error loading definition from %s", full_path))
        return(false)
      end

      if(validator and not validator(def_script, mod_fname, full_path)) then
        return(false)
      end

      copy_file(fname, defs_dir, runtime_path)
    end
  end

  return(true)
end

local function load_plugin_definitions(plugin, alert_definitions, status_definitions)
  local alert_consts = require("alert_consts")
  local flow_consts = require("flow_consts")
  local alert_definitions
  local status_definitions

  if(plugin.edition == "community") then
    alert_definitions = RUNTIME_PATHS.alert_definitions
    status_definitions = RUNTIME_PATHS.status_definitions
  else
    -- It's necessary to split pro plugins to avoid errors on demo mode end
    -- while loading pro scripts
    alert_definitions = RUNTIME_PATHS.pro_alert_definitions
    status_definitions = RUNTIME_PATHS.pro_status_definitions
  end

  return(load_definitions(os_utils.fixPath(plugin.path .. "/alert_definitions"), alert_definitions, alert_consts.loadDefinition)
    and load_definitions(os_utils.fixPath(plugin.path .. "/status_definitions"), status_definitions, flow_consts.loadDefinition))
end

-- ##############################################

local function load_plugin_ts_schemas(plugin)
  local src_path = os_utils.fixPath(plugin.path .. "/ts_schemas")
  local ts_path = os_utils.fixPath(RUNTIME_PATHS.ts_schemas .. "/" .. plugin.key)

  if ntop.exists(src_path) then
    ntop.mkdir(ts_path)

    return(
      recursive_copy(src_path, ts_path)
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
    if(not copy_file(nil, lint_path,
        os_utils.fixPath(RUNTIME_PATHS.http_lint .. "/" .. plugin.key .. ".lua"))) then
      return(false)
    end
  end

  return(true)
end

-- ##############################################

local function load_plugin_user_scripts(paths_to_plugin, plugin)
  local scripts_path = os_utils.fixPath(plugin.path .. "/user_scripts")
  local paths_map = {}

  local rv = (
    recursive_copy(os_utils.fixPath(scripts_path .. "/interface"), RUNTIME_PATHS.interface_scripts, paths_map) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/host"), RUNTIME_PATHS.host_scripts, paths_map) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/network"), RUNTIME_PATHS.network_scripts, paths_map) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/flow"), RUNTIME_PATHS.flow_scripts, paths_map) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/syslog"), RUNTIME_PATHS.syslog, paths_map) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/snmp_device"), RUNTIME_PATHS.snmp_scripts, paths_map) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/system"), RUNTIME_PATHS.system_scripts, paths_map)
  )

  for runtime_path, source_path in pairs(paths_map) do
    -- Ensure that the script does not have errors
    local res = dofile(runtime_path)

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

local function load_plugin_alert_endpoints(endpoints_prefs_entries, plugin)
  local endpoints_path = os_utils.fixPath(plugin.path .. "/alert_endpoints")

  for fname in pairs(ntop.readdir(endpoints_path)) do
    if(fname == "prefs_entries.lua") then
      local prefs_entries = dofile(os_utils.fixPath(endpoints_path .. "/" .. fname))

      if(prefs_entries) then
        if(prefs_entries.entries == nil) then
          traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing field 'entries' in %s (prefs_entries.lua)", plugin.key))
          return(false)
        end
        if(prefs_entries.endpoint_key == nil) then
          traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing field 'endpoint_key' in %s (prefs_entries.lua)", plugin.key))
          return(false)
        end
        if(endpoints_prefs_entries[prefs_entries.endpoint_key] ~= nil) then
          traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Endpoint key '%s' already defined, error in %s (prefs_entries.lua)", prefs_entries.endpoint_key, plugin.key))
          return(false)
        end

        endpoints_prefs_entries[prefs_entries.endpoint_key] = prefs_entries
      end
    else
      if not copy_file(fname, endpoints_path, RUNTIME_PATHS.alert_endpoints) then
        return(false)
      end
    end
  end

  return(true)
end

-- ##############################################

local function load_plugin_web_gui(plugin)
  local gui_dir = os_utils.fixPath(plugin.path .. "/web_gui")

  for fname in pairs(ntop.readdir(gui_dir)) do
    if(fname == "menu.lua") then
      local full_path = os_utils.fixPath(gui_dir .. "/" .. fname)
      local menu_entry = dofile(full_path)

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

          if(not copy_file(nil, full_path,
              os_utils.fixPath(RUNTIME_PATHS.menu_items .. "/" .. plugin.key .. ".lua"))) then
            return(false)
          end
        end
      end
    else
      if not copy_file(fname, gui_dir, RUNTIME_PATHS.web_gui) then
        return(false)
      end
    end
  end

  return(true)
end

-- ##############################################

-- @brief Loads the ntopng plugins into a single directory tree.
-- @notes This should be called at startup
function plugins_utils.loadPlugins()
  local locales_utils = require("locales_utils")
  local plugins = plugins_utils.listPlugins()
  local loaded_plugins = {}
  local locales = {}
  local endpoints_prefs_entries = {}
  local path_map = {}
  local en_locale = locales_utils.readDefaultLocale()

  -- Remove previously loaded plugins
  ntop.rmdir(plugins_utils.PLUGINS_RUNTIME_PATH)

  -- Note: load these only after cleaning the old plugins, to avoid
  -- errors due to ntopng version change (e.g. after adding the --community switch)
  local alert_consts = require("alert_consts")
  local flow_consts = require("flow_consts")

  -- Initialize directories
  init_runtime_paths()

  -- Ensure that the directory is writable
  ntop.mkdir(plugins_utils.PLUGINS_RUNTIME_PATH)
  local test_file = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/test")

  local outfile, err = io.open(test_file, "w")
  if(outfile) then
    outfile:close()
  end

  if(outfile == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Cannot write to the plugins directory: %s. Plugins will not be loaded!",
      err or plugins_utils.PLUGINS_RUNTIME_PATH))
    return(false)
  end

  os.remove(test_file)

  for _, path in pairs(RUNTIME_PATHS) do
    ntop.mkdir(path)
  end

  -- Reset the definitions before loading
  alert_consts.resetDefinitions()
  flow_consts.resetDefinitions()

  -- Load the plugins following the dependecies order
  for _, plugin in ipairs(plugins) do
    -- Ensure that the depencies has been loaded as well
    for _, dep in pairs(plugin.dependencies or {}) do
      if not loaded_plugins[dep] then
        traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Skipping plugin %s due to missing dependency '%s'", plugin.key, dep))
        goto continue
      end
    end

    if do_trace then
      io.write(string.format("Loading plugin %s\n", plugin.key))
    end

    if load_plugin_definitions(plugin) and
        load_plugin_i18n(locales, en_locale, plugin) and
        load_plugin_lint(plugin) and
        load_plugin_ts_schemas(plugin) and
        load_plugin_web_gui(plugin) and
        load_plugin_user_scripts(path_map, plugin) and
        load_plugin_alert_endpoints(endpoints_prefs_entries, plugin) then
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

  -- Save alert endpoint entries
  if not table.empty(endpoints_prefs_entries) then
    local entries_path = os_utils.fixPath(RUNTIME_PATHS.alert_endpoints .. "/prefs_entries.lua")

    persistence.store(entries_path, endpoints_prefs_entries)
    ntop.setDefaultFilePermissions(entries_path)
  end

  -- Save loaded plugins metadata
  -- See load_metadata()
  local plugins_metadata = {
    plugins = loaded_plugins,
    path_map = path_map,
  }
  persistence.store(plugins_utils.PLUGINS_RUNTIME_METADATA, plugins_metadata)
  ntop.setDefaultFilePermissions(plugins_utils.PLUGINS_RUNTIME_METADATA)

  return(true)
end

-- ##############################################

local schemas_loaded = {}

function plugins_utils.loadSchemas(granularity)
  if(schemas_loaded["all"] or (granularity and schemas_loaded[granularity])) then
    -- already loaded
    return
  end

  init_runtime_paths()

  for plugin_name in pairs(ntop.readdir(RUNTIME_PATHS.ts_schemas)) do
    local ts_dir = os_utils.fixPath(RUNTIME_PATHS.ts_schemas .. "/" .. plugin_name)
    local files_to_load = nil

    if(granularity ~= nil) then
      -- Only load schemas for the specified granularity
      files_to_load = {granularity .. ".lua"}
    else
      -- load all
      files_to_load = ntop.readdir(ts_dir)
    end

    for _, fname in pairs(files_to_load) do
      if string.ends(fname, ".lua") then
        local fgran = string.sub(fname, 1, string.len(fname)-4)
        local fpath = os_utils.fixPath(ts_dir .. "/" .. fname)

        -- Check if not already loaded
        if((schemas_loaded[fgran] == nil) and ntop.exists(fpath)) then
          -- load the script
          dofile(fpath)
        end
      end
      
    end
  end

  schemas_loaded[granularity or "all"] = true
end

-- ##############################################

function plugins_utils.getMenuEntries()
  init_runtime_paths()
  local menu = {}

  for fname in pairs(ntop.readdir(RUNTIME_PATHS.menu_items)) do
    local full_path = os_utils.fixPath(RUNTIME_PATHS.menu_items .. "/" .. fname)
    local plugin_key = string.sub(fname, 1, string.len(fname)-4)

    local menu_entry = dofile(full_path)

    if(menu_entry and ((not menu_entry.is_shown) or menu_entry.is_shown())) then
      menu_entry.url = plugins_utils.getUrl(menu_entry.script)
      menu[plugin_key] = menu_entry
    end
  end

  return(menu)
end

-- ##############################################

function plugins_utils.getUrl(script)
  return(ntop.getHttpPrefix() .. "/plugins/" .. script)
end

-- ##############################################

function plugins_utils.hasAlerts(ifid, options)
  -- Requiring alert_utils here to optimize second.lua
  require("alert_utils")

  local opts = table.merge(options, {ifid = ifid})
  local old_iface = iface
  local rv
  interface.select(ifid)

  rv = (areAlertsEnabled() and
    (hasAlerts("historical", getTabParameters(opts, "historical")) or
     hasAlerts("engaged", getTabParameters(opts, "engaged"))))

  interface.select(old_iface)
  return(rv)
end

-- ##############################################

function plugins_utils.timeseriesCreationEnabled()
   local system_probes_timeseries_enabled = true

   if ntop.getPref("ntopng.prefs.system_probes_timeseries") == "0" then
      system_probes_timeseries_enabled = false
   end

   return system_probes_timeseries_enabled
end

-- ##############################################

local function load_metadata()
  if(METADATA == nil) then
    METADATA = dofile(plugins_utils.PLUGINS_RUNTIME_METADATA)
  end
end

-- ##############################################

-- @brief Retrieve the original source path of a user script
-- @param script_path the runtime path of the user script
-- @return the user script source path
function plugins_utils.getUserScriptSourcePath(script_path)
  load_metadata()

  local info = METADATA.path_map[script_path]

  if info then
    return(info.source_path)
  end
end

-- ##############################################

-- @brief Retrieve the plugin associated with the user script
-- @param script_path the runtime path of the user script
-- @return the associated plugin
function plugins_utils.getUserScriptPlugin(script_path)
  load_metadata()

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

  return(METADATA.plugins)
end

-- ##############################################

function plugins_utils.loadAlertEndpoint(endpoint_key)
  local endpoint_path = os_utils.fixPath(RUNTIME_PATHS.alert_endpoints .. "/".. endpoint_key ..".lua")

  if not ntop.exists(endpoint_path) then
    return(nil)
  end

  return(dofile(endpoint_path))
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

-- @brief Get the available alert endpoints
-- @return a sorted table, in order of priority, for the alert endpoints
function plugins_utils.getLoadedAlertEndpoints()
  init_runtime_paths()

  local rv = {}
  local prefs_map = {}
  local prefs_path = os_utils.fixPath(RUNTIME_PATHS.alert_endpoints .. "/prefs_entries.lua")

  if ntop.exists(prefs_path) then
    prefs_map = dofile(prefs_path) or {}
  end

  for fname in pairs(ntop.readdir(RUNTIME_PATHS.alert_endpoints) or {}) do
    if((fname ~= "prefs_entries.lua") and string.ends(fname, ".lua")) then
      local full_path = os_utils.fixPath(RUNTIME_PATHS.alert_endpoints .. "/" .. fname)
      local endpoint = dofile(full_path)

      if(endpoint) then
        if((type(endpoint.isAvailable) ~= "function") or endpoint.isAvailable()) then
          local key = string.sub(fname, 1, string.len(fname) - 4)
          endpoint.full_path = full_path
          endpoint.key = key
          endpoint.prefs_entries = prefs_map[key] and prefs_map[key].entries

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

  for fname in pairs(ntop.readdir(RUNTIME_PATHS.http_lint)) do
    local full_path = os_utils.fixPath(RUNTIME_PATHS.http_lint .. "/" .. fname)
    local lint = dofile(full_path)

    if(lint == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load '%s'", full_path))
      goto continue
    end

    if(lint.getAdditionalParameters == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing mandatory function 'getAdditionalParameters' in '%s'", full_path))
      goto continue
    end

    local rv = lint.getAdditionalParameters(http_lint)

    if(type(rv) ~= "table") then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("function 'getAdditionalParameters' in '%s' returned a non-table value", full_path))
      goto continue
    end

    for k, v in pairs(rv) do
      params[k] = v
    end

    ::continue::
  end
end

-- ##############################################

return(plugins_utils)
