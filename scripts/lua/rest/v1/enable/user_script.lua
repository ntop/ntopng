--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require "dkjson"
local rest_utils = require "rest_utils"
local user_scripts = require("user_scripts")
local auth = require "auth"

--
-- Enable User Script
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v1/disable/user_script.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not auth.has_capability(auth.capabilities.user_scripts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local subdir = _POST["script_subdir"]
if(subdir == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local script_type = user_scripts.getScriptType(subdir)
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

local success, err = user_scripts.toggleScript(script_key, subdir, true) 

result.success = success

if not success then
  result.error = err
end

-- ################################################

rest_utils.answer(rc, result)
