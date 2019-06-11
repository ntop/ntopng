--
-- (C) 2013-19 - ntop.org
--

local system_scripts = {}

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local os_utils = require("os_utils")
local ts_utils = require("ts_utils_core")

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

  if(periodicity == nil) then
    return(false)
  end

  ts_utils.newSchema = function(name, label, options)
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
  local needs_label = false
  local current_probe_label = nil
  local default_schema_options = nil

  ts_utils.newSchema = function(name, options)
    local schema = ts_utils.getSchema(name)
    if(schema == nil) then
      schema = old_new_schema_fn(name, table.merge(default_schema_options, options))
    end

    if(options.label == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing schema label in schema '%s'", name))
      return nil
    end

    if needs_label then
      needs_label = false

      additional_ts[#additional_ts + 1] = {
        separator = 1,
        label = current_probe_label,
      }
    end

    additional_ts[#additional_ts + 1] = {
      schema = name,
      label = options.label,
    }

    return schema
  end

  for task, periodicity in system_scripts.getTasks() do
    default_schema_options = { step = periodicity, is_system_schema = true }

    for probe_name, probe in system_scripts.getSystemProbes(task) do
      -- nil filter shows all the schemas
      -- "system" filter shows all the schemas without has_own_page
      -- other filter shows all the schemas with that name
      if((probe.loadSchemas ~= nil) and
          (((module_filter == "system") and (probe.has_own_page ~= true)) or
            (probe_name == module_filter) or
            (module_filter == nil))) then
        needs_label = true
        current_probe_label = probe.name or probe_name

        probe.loadSchemas(ts_utils)
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
    (getNumAlerts("historical", getTabParameters(opts, "historical")) > 0) or
    (getNumAlerts("engaged", getTabParameters(opts, "engaged")) > 0))

  interface.select(old_iface)
  return(rv)
end

-- ##############################################

return system_scripts
