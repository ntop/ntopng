--
-- (C) 2013-19 - ntop.org
--

local system_probes = {}
local system_probes_dir = dirs.installdir .. "/scripts/lua/modules/system_probes"

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local os_utils = require("os_utils")
local ts_utils = require("ts_utils")

local default_schema_options = {
  step = 60,
}

-- ##############################################

function system_probes.getSystemProbes()
  local probes = pairsByKeys(ntop.readdir(system_probes_dir))

  return function()
    local get_next = true

    while get_next do
      local probe_script = probes()
      get_next = false

      if probe_script ~= nil then
        local name = string.sub(probe_script, 1, string.len(probe_script)-4)
        local _module = loadfile(os_utils.fixPath(system_probes_dir .. "/" .. probe_script))()

        if _module.isActive() then
          return name, _module
        else
          get_next = true
        end
      end

      return nil
    end
  end
end

-- ##############################################

function system_probes.runMinuteTasks(when)
  local old_new_schema_fn = ts_utils.newSchema

  ts_utils.newSchema = function(name, label, options)
    return old_new_schema_fn(name, table.merge(default_schema_options, options))
  end

  for _, probe in system_probes.getSystemProbes() do
    if(probe.runMinuteTasks ~= nil) then
      if(probe.loadSchemas ~= nil) then
        -- Possibly load the schemas first
        probe.loadSchemas(ts_utils)
      end

      probe.runMinuteTasks(when)
    end
  end

  -- Restore original function
  ts_utils.newSchema = old_new_schema_fn
end

-- ##############################################

function system_probes.getAdditionalTimeseries()
  local old_new_schema_fn = ts_utils.newSchema
  local additional_ts = {}
  local needs_label = false
  local current_probe_label = nil

  ts_utils.newSchema = function(name, options)
    local schema = old_new_schema_fn(name, table.merge(default_schema_options, options))

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

  for probe_name, probe in system_probes.getSystemProbes() do
    if(probe.loadSchemas ~= nil) then
      needs_label = true
      current_probe_label = probe_name

      probe.loadSchemas(ts_utils)
    end
  end

  -- Restore original function
  ts_utils.newSchema = old_new_schema_fn

  return(additional_ts)
end

-- ##############################################

return system_probes
