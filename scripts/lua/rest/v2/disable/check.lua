--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require "dkjson"
local rest_utils = require "rest_utils"
local checks = require("checks")
local auth = require "auth"

--
-- Disable User Script
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/disable/check.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local subdir = _POST["check_subdir"]
if(subdir == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local script_type = checks.getScriptType(subdir)
if(script_type == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local script_key = _POST["script_key"]
if(script_key == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

-- ################################################

local rc = rest_utils.consts.success.ok
local result = {}

local success, err = checks.toggleScript(script_key, subdir, false) 

result.success = success

if not success then
  result.error = err
end

-- ################################################

rest_utils.answer(rc, result)
