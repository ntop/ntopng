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

-- TODO: use more appropriate runtime path
plugins_utils.PLUGINS_RUNTIME_PATH = os_utils.fixPath(dirs.workingdir .. "/plugins")
plugins_utils.PLUGINS_GUI_RUNTIME_PATH = os_utils.fixPath(dirs.scriptdir .. "/lua/plugins")

local RUNTIME_PATHS = {}

-- ##############################################

function plugins_utils.listPlugins()
  local plugins = {}
  local source_dirs = {plugins_utils.COMMUNITY_SOURCE_DIR}
  local plugins_with_deps = {}

  if ntop.isPro() then
    source_dirs[#source_dirs + 1] = plugins_utils.PRO_SOURCE_DIR

    if ntop.isEnterprise() then
      source_dirs[#source_dirs + 1] = plugins_utils.ENTERPRISE_SOURCE_DIR
    end
  end

  for _, source_dir in ipairs(source_dirs) do
    for plugin_name in pairs(ntop.readdir(source_dir)) do
      local plugin_dir = os_utils.fixPath(source_dir .. "/" .. plugin_name)
      local plugin_info = os_utils.fixPath(plugin_dir .. "/plugin.lua")

      if ntop.exists(plugin_info) then
        -- Using loadfile instead of require is needed since the plugin.lua
        -- name is the same across the plusings
        local metadata = assert(loadfile(plugin_info))()

        -- Augument information
        metadata.path = plugin_dir
        metadata.key = plugin_name

        -- TODO check plugin dependencies
        if not table.empty(metadata.dependencies) then
          plugins_with_deps[plugin_name] = metadata
        else
          plugins[plugin_name] = metadata
        end
      else
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing plugin.lua in '%s'", plugin_name))
      end
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
    end
  end

  return(plugins)
end

-- ##############################################

local function init_runtime_paths()
  RUNTIME_PATHS = {
    -- Definitions
    alert_definitions = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/alert_definitions"),
    status_definitions = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/status_definitions"),

    -- Locales
    locales = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/locales"),

    -- Timeseries
    ts_schemas = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/ts_schemas"),

    -- Web Gui
    web_gui = os_utils.fixPath(plugins_utils.PLUGINS_GUI_RUNTIME_PATH),

    -- User scripts
    interface_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/interface"),
    host_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/host"),
    network_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/network"),
    flow_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/flow"),
    syslog = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/syslog"),
    snmp_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/system/snmp_device"),
    system_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/system/system"),
  }
end

-- ##############################################

local function copy_file(fname, src_path, dst_path)
  local src = os_utils.fixPath(src_path .. "/" .. fname)
  local dst = os_utils.fixPath(dst_path .. "/" .. fname)
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

  return(true)
end

local function recursive_copy(src_path, dst_path)
  for fname in pairs(ntop.readdir(src_path)) do
    if not copy_file(fname, src_path, dst_path) then
      return(false)
    end
  end

  return(true)
end

-- ##############################################

local function load_plugin_definitions(plugin)
  return(
    recursive_copy(os_utils.fixPath(plugin.path .. "/alert_definitions"), RUNTIME_PATHS.alert_definitions) and
    recursive_copy(os_utils.fixPath(plugin.path .. "/status_definitions"), RUNTIME_PATHS.status_definitions)
  )
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

local function load_plugin_user_scripts(plugin)
  local scripts_path = os_utils.fixPath(plugin.path .. "/user_scripts")

  return(
    recursive_copy(os_utils.fixPath(scripts_path .. "/interface"), RUNTIME_PATHS.interface_scripts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/host"), RUNTIME_PATHS.host_scripts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/network"), RUNTIME_PATHS.network_scripts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/flow"), RUNTIME_PATHS.flow_scripts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/syslog"), RUNTIME_PATHS.syslog) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/snmp_device"), RUNTIME_PATHS.snmp_scripts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/system"), RUNTIME_PATHS.system_scripts)
  )
end

-- ##############################################

local function load_plugin_web_gui(menu_entries, plugin)
  local gui_dir = os_utils.fixPath(plugin.path .. "/web_gui")

  for fname in pairs(ntop.readdir(gui_dir)) do
    if(fname == "menu.lua") then
      local menu_entry = assert(loadfile(os_utils.fixPath(gui_dir .. "/" .. fname)))()

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
            traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing menu entry script path '%s' does not exists in %s", script_path, plugin.key))
            return(false)
          end

          menu_entry.url = plugins_utils.getUrl(menu_entry.script)
        end
      end

      menu_entries[plugin.key] = menu_entry
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
  local locales = {}
  local menu_entries = {}
  local en_locale = locales_utils.readDefaultLocale()

  -- Clean previous structure
  ntop.rmdir(plugins_utils.PLUGINS_RUNTIME_PATH)
  ntop.rmdir(plugins_utils.PLUGINS_GUI_RUNTIME_PATH)

  -- Initialize directories
  init_runtime_paths()

  for _, path in pairs(RUNTIME_PATHS) do
    ntop.mkdir(path)
  end

  for _, plugin in pairs(plugins) do
    if do_trace then
      io.write(string.format("Loading plugin %s\n", plugin.key))
    end

    if load_plugin_definitions(plugin) and
        load_plugin_i18n(locales, en_locale, plugin) and
        load_plugin_ts_schemas(plugin) and
        load_plugin_web_gui(menu_entries, plugin) and
        load_plugin_user_scripts(plugin) then
      -- Ok
    else
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Errors occurred while processing plugin %s", plugin.key))
    end
  end

  -- Save the locales
  for fname, plugins_locales in pairs(locales) do
    local locale_path = os_utils.fixPath(RUNTIME_PATHS.locales .. "/" .. fname)

    persistence.store(locale_path, plugins_locales)
  end

  -- Save the menu entries
  if not table.empty(menu_entries) then
    local menu_path = os_utils.fixPath(RUNTIME_PATHS.web_gui .. "/menu.lua")

    persistence.store(menu_path, menu_entries)
  end
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
          assert(loadfile(fpath))()
        end
      end
      
    end
  end

  schemas_loaded[granularity or "all"] = true
end

-- ##############################################

function plugins_utils.getMenuEntries()
  init_runtime_paths()

  local menu_path = os_utils.fixPath(RUNTIME_PATHS.web_gui .. "/menu.lua")

  if ntop.exists(menu_path) then
    local menu = assert(loadfile(menu_path))()
    return(menu)
  end

  return(nil)
end

-- ##############################################

function plugins_utils.getUrl(script)
  return(ntop.getHttpPrefix() .. "/lua/plugins/" .. script)
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

return(plugins_utils)
