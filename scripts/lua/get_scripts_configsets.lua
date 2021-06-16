--
-- (C) 2019-21 - ntop.org
--

-- This is deprecated as there is a single configset now

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local checks = require("checks")
local rest_utils = require "rest_utils"
local auth = require "auth"

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local subdir = _GET["check_subdir"]

sendHTTPContentTypeHeader('application/json')

if(subdir == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'check_subdir' parameter")
  return
end

local script_type = checks.script_types[subdir]
local configset = checks.getConfigset()
local rv = {}

-- Only return the essential information

rv[#rv + 1] = {
  id = configset.id,
  name = configset.name,
  pools = {},
}

print(json.encode(rv))
