--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")

sendHTTPContentTypeHeader('application/json')

local stype = _GET["script_type"] or "traffic_element"
local subdir = _GET["script_subdir"] or "host"

local script_type = user_scripts.script_types[stype]

if(script_type == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad script_type: " .. stype)
  return
end

-- ################################################

interface.select(getSystemInterfaceId())

local scripts = user_scripts.load(getSystemInterfaceId(), script_type, subdir)
local result = {}

for script_name, script in pairs(scripts.modules) do
  if script.gui.i18n_title and script.gui.i18n_description then
    result[#result + 1] = {
      key = script_name,
      title = i18n(script.gui.i18n_title) or script.gui.i18n_title,
      description = i18n(script.gui.i18n_description) or script.gui.i18n_description,
    }
  end
end

-- ################################################

print(json.encode(result))
