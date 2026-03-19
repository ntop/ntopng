--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json        = require "dkjson"
local rest_utils  = require "rest_utils"
local checks      = require "checks"
local auth        = require "auth"

--
-- Enable or disable a batch of checks in a single request.
--
-- POST body fields:
--   check_subdir  string   — subdir the checks belong to (e.g. "host", "flow")
--   script_keys   string   — JSON-encoded array of check key names
--   enabled       string   — "true" to enable, "false" to disable
--
-- Example:
--   curl -u admin:admin -X POST http://localhost:3000/lua/rest/v2/toggle/checks/batch.lua \
--     -d 'check_subdir=host' \
--     -d 'script_keys=["check_a","check_b"]' \
--     -d 'enabled=false'
--

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local subdir      = _POST["check_subdir"]
local keys_raw    = _POST["script_keys"]
local enabled_str = _POST["enabled"]

if subdir == nil or keys_raw == nil or enabled_str == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local script_type = checks.getScriptType(subdir)
if script_type == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- script_keys is a comma-separated list of key names (e.g. "key1,key2")
local script_keys = {}
for k in keys_raw:gmatch("[^,]+") do
   script_keys[#script_keys + 1] = k
end
if #script_keys == 0 then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local enable = (enabled_str == "true")

local results  = {}
local any_fail = false

for _, key in ipairs(script_keys) do
   tprint("Key: " .. tostring(key) .. " Subdir: " .. tostring(subdir) .. " Enable: " ..tostring(enable))
   local ok, err = checks.toggleScript(key, subdir, enable)
   results[#results + 1] = {
      key     = key,
      success = ok,
      error   = ok and nil or err,
   }
   if not ok then any_fail = true end
end

rest_utils.answer(rest_utils.consts.success.ok, { results = results, any_fail = any_fail })
