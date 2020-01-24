--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")

-- Script state
local f = nil

local script = {
  -- Script category
  category = user_scripts.script_categories.system, 

  -- This module is disabled by default
  default_enabled = false,

  -- The default configuration of this script
  default_value = {
    log_mode = "console", -- console | file
    log_file = "/tmp/flows_log",
  },

  -- See below
  hooks = {},

  -- Allow user script configuration from the GUI
  gui = {
    -- Localization strings, from the "locales" directory of the plugin
    i18n_title = "alerts_dashboard.flow_logger",
    i18n_description = "alerts_dashboard.flow_logger_descr",

    -- TODO: draw config gui
  }
}

-- #################################################################

function script.teardown()
  if(f ~= nil) then
    -- Close the log file
    f:close()
    f = nil
  end
end

-- #################################################################

-- Defines an hook which is executed every time a procotol of a flow is detected
function script.hooks.protocolDetected(now, conf)
  local line = string.format("%s %s\n", os.date("%d/%b/%Y %X"), shortFlowLabel(flow.getInfo()))

  if(conf.log_mode == "file") then
    if(f == nil) then
      local err

      f, err = io.open(conf.log_file, "a")

      if(f == nil) then
	traceError(TRACE_ERROR, TRACE_CONSOLE, err)
      end
    end

    if(f ~= nil) then
      f:write(line)
    end
  else
    print(line)
  end
end

-- #################################################################

return script
