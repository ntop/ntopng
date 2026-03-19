--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json       = require "dkjson"
local rest_utils = require "rest_utils"
local checks     = require "checks"
local auth       = require "auth"

--
-- Save configuration for a single check.
--
-- POST body fields:
--   check_subdir  string  — e.g. "host", "flow"
--   script_key    string  — check key name
--   JSON          string  — JSON-encoded hooks config object
--                           { hookName: { enabled: bool, script_conf: {...} } }
--

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local subdir      = _POST["check_subdir"]
local script_key  = _POST["script_key"]
local config_json = _POST["JSON"]

tprint(_POST)
if not subdir or not script_key or not config_json then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local new_config = json.decode(config_json)
if not new_config or table.empty(new_config) then
   rest_utils.answer(rest_utils.consts.err.bad_format)
   return
end

local ok, err = checks.updateScriptConfig(script_key, subdir, new_config)

if ok then
   rest_utils.answer(rest_utils.consts.success.ok)
else
   rest_utils.answer(rest_utils.consts.err.internal_error, { error = err })
end
