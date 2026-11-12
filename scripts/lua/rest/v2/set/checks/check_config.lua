--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json       = require "dkjson"
local rest_utils = require "rest_utils"
local checks     = require "checks"
local tag_badge_utils = require "tag_badge_utils"
local auth       = require "auth"

--
-- Save configuration for a single check.
--
-- POST body fields:
--   check_subdir  string  — e.g. "host", "flow"
--   script_key    string  — check key name
--   JSON          string  — JSON-encoded hooks config object
--                           { hookName: { enabled: bool, script_conf: {...} } }
--   tag_ids       string  — optional, comma-separated ids of the tags added to the
--                           alerts of the check (empty for none, missing to keep them)
--

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local subdir      = _POST["check_subdir"]
local script_key  = _POST["script_key"]
local config_json = _POST["JSON"]

if not subdir or not script_key or not config_json then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local new_config = json.decode(config_json)
if not new_config or table.empty(new_config) then
   rest_utils.answer(rest_utils.consts.err.bad_format)
   return
end

-- Tags: only existing ones
local tag_ids = nil
local tag_ids_param = _POST["tag_ids"]

if tag_ids_param then
   local existing_tags = {}

   for _, tag in ipairs(tag_badge_utils.getTags(true --[[ no_i18n ]])) do
      existing_tags[tonumber(tag.id)] = true
   end

   tag_ids = {}
   for tag_id in tag_ids_param:gmatch("[^,]+") do
      tag_id = tonumber(tag_id)

      if not existing_tags[tag_id] then
         rest_utils.answer(rest_utils.consts.err.invalid_args)
         return
      end

      tag_ids[#tag_ids + 1] = tag_id
   end
end

local ok, err = checks.updateScriptConfig(script_key, subdir, new_config, tag_ids)

if ok then
   rest_utils.answer(rest_utils.consts.success.ok)
else
   rest_utils.answer(rest_utils.consts.err.internal_error, { error = err })
end
