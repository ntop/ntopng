--
-- (C) 2013-19 - ntop.org
--

local system_scripts = {}

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local os_utils = require("os_utils")
local ts_utils = require("ts_utils_core")
require "alert_utils"

local system_scripts_dir = dirs.installdir .. "/scripts/callbacks/system"
local task_to_periodicity = {
  ["second"] = 1,
  ["minute"] = 60,
  ["5min"]   = 300,
  ["hourly"] = 3600,
  ["daily"]  = 86400,
}

-- ##############################################

function system_scripts.getSystemProbes(task)
  local base_dir = system_scripts_dir .. "/" .. task
  local probes = pairsByKeys(ntop.readdir(base_dir)) or {}

  return function()
    local get_next = true

    while get_next do
      local probe_script = probes()
      get_next = false

      if(probe_script == nil) then
        return nil
      end

      if not(string.ends(probe_script, ".lua")) then
        get_next = true
        goto continue
      end

      local name = string.sub(probe_script, 1, string.len(probe_script)-4)
      local path = os_utils.fixPath(base_dir .. "/" .. probe_script)
      local _module = loadfile(path)()

      if _module == nil then
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load module '%s'", path))
        get_next = true
      elseif (_module.isEnabled == nil) or _module.isEnabled() then
        return name, _module
      else
        get_next = true
      end

      ::continue::
    end
  end
end

-- ##############################################

function system_scripts.getSystemProbe(probe_name)
  for task in system_scripts.getTasks() do
    for name, probe in system_scripts.getSystemProbes(task) do
      if name == probe_name then
        return(probe)
      end
    end
  end

  -- Not Found
  return(nil)
end

-- ##############################################

local tasks_cached = nil

function system_scripts.getTasks()
  if(tasks_cached == nil) then
    tasks_cached = ntop.readdir(system_scripts_dir)
  end

  local tasks = pairsByKeys(tasks_cached)

  return function()
    local get_next = true

    while get_next do
      local task = tasks()
      get_next = false

      if task then
        local periodicity = task_to_periodicity[task]

        if(periodicity ~= nil) then
          return task, periodicity
        else
          get_next = true
        end
      else
        return nil
      end
    end
  end
end

-- ##############################################

function system_scripts.runTask(task, when)
  local old_new_schema_fn = ts_utils.newSchema
  local periodicity = task_to_periodicity[task]
  local default_schema_options = { step = periodicity, is_system_schema = true }

  if(task ~= "second") then
    -- Do not include this in the second script as it has a performance
    -- impact of about 100ms
    require("lua_utils")
  end

  if(periodicity == nil) then
    return(false)
  end

  ts_utils.newSchema = function(name, options)
    local schema = ts_utils.getSchema(name)
    if(schema == nil) then
      return old_new_schema_fn(name, table.merge(default_schema_options, options))
    else
      return(schema)
    end
  end

  for _, probe in system_scripts.getSystemProbes(task) do
    interface.select(getSystemInterfaceId())

    if(probe.runTask ~= nil) then
      if(probe.loadSchemas ~= nil) then
        -- Possibly load the schemas first
        probe.loadSchemas(ts_utils)
      end

      probe.runTask(when, ts_utils)
    end
  end

  -- Restore original function
  ts_utils.newSchema = old_new_schema_fn
  interface.select(getSystemInterfaceId())
  return(true)
end

-- ##############################################

function system_scripts.getAdditionalTimeseries(module_filter)
  local old_new_schema_fn = ts_utils.newSchema
  local additional_ts = {}
  local default_schema_options = nil

  ts_utils.newSchema = function(name, options)
    local schema = ts_utils.getSchema(name)
    if(schema == nil) then
      schema = old_new_schema_fn(name, table.merge(default_schema_options, options))
    end

    return schema
  end

  for task, periodicity in system_scripts.getTasks() do
    default_schema_options = { step = periodicity, is_system_schema = true }

    for probe_name, probe in system_scripts.getSystemProbes(task) do
      -- nil filter shows all the schemas
      -- "system" filter shows all the schemas without page_script
      -- other filter shows all the schemas with that name
      if((probe.loadSchemas ~= nil) and
          (((module_filter == "system") and (probe.page_script == nil)) or
            (probe_name == module_filter) or
            (module_filter == nil))) then
        probe.loadSchemas(ts_utils)

        if(probe.getTimeseriesMenu ~= nil) then
          local menu = probe.getTimeseriesMenu(ts_utils) or {}

          table.insert(menu, 1, {
            separator = 1,
            label = probe.name or probe_name,
          })

          additional_ts = table.merge(additional_ts, menu)
        end
      end
    end
  end

  -- Restore original function
  ts_utils.newSchema = old_new_schema_fn

  return(additional_ts)
end

-- ##############################################

function system_scripts.hasAlerts(options)
  local opts = table.merge(options, {ifid = getSystemInterfaceId()})
  local old_iface = iface
  local rv
  interface.select(getSystemInterfaceId())

  rv = (areAlertsEnabled() and
    (hasAlerts("historical", getTabParameters(opts, "historical")) or
     hasAlerts("engaged", getTabParameters(opts, "engaged"))))

  interface.select(old_iface)
  return(rv)
end

-- ##############################################

function system_scripts.getPageScriptPath(probe)
  return(ntop.getHttpPrefix() .. "/lua/system/" .. probe.page_script)
end

-- ##############################################

local function menu_entry_compare(a, b)
  if(a.page_order == nil) then return(false) end
  if(b.page_order == nil) then return(true) end
  return(a.page_order > b.page_order)
end

function system_scripts.getSystemMenuEntries()
  local rv = {}

  for task, periodicity in system_scripts.getTasks() do
    for probe_name, probe in system_scripts.getSystemProbes(task) do
      if(probe.page_script ~= nil) and ((probe.isEnabled == nil) or (probe.isEnabled())) then
        rv[#rv + 1] = probe
      end
    end
  end

  table.sort(rv, menu_entry_compare)

  for idx, probe in pairs(rv) do
    rv[idx] = {
      label = probe.name,
      url = system_scripts.getPageScriptPath(probe),
    }
  end

  return(rv)
end

-- ##############################################

return system_scripts
