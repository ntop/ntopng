--
-- (C) 2019 - ntop.org
--
-- The functions below are called with a LuaC "flow" context set.
-- See alerts_api.load_flow_check_modules documentation for information
-- on adding custom scripts.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local alerts_api = require("alerts_api")

if ntop.isPro() then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

local do_trace = false
local check_modules = {}

-- #################################################################

-- The function below ia called once (#pragma once)
function setup()
  if(do_trace) then print("flow.lua:setup() called\n") end

  check_modules = alerts_api.load_flow_check_modules()

  for _, _module in pairs(check_modules) do
    if _module.setup then
      _module.setup()
    end
  end
end

-- #################################################################

function protocolDetected()
  local info = flow.getInfo()

  if(do_trace) then print("protocolDetected(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules) do
    if _module.protocolDetected then
      _module.protocolDetected(info)
    end
  end
end

-- #################################################################

function statusChanged()
  local info = flow.getInfo()

  if(do_trace) then print("statusChanged(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules) do
    if _module.statusChanged then
      _module.statusChanged(info)
    end
  end
end
