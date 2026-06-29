--
-- (C) 2014-26 - ntop.org
--
-- POST /lua/rest/v2/set/ntopng/preferences.lua
--
-- Persists a single preference field to Redis.
-- Called by page-preferences.vue for each changed field on save.
--
-- POST body (JSON):
--   {
--     "csrf":    "<token>",
--     "section": "<section_id>",
--     "key":     "<entry_key>",
--     "value":   "<new_value>"
--   }
--
-- Special behaviours (server-side only):
--   - Password fields: if value == "********" the write is skipped.
--   - Data retention ordering (clickhouse): aggregated_flows >= raw + 1 is enforced.
--   - Auth at-least-one: rejecting a change that would disable the last auth method.
--
-- This is a NEW endpoint — it does not modify any existing Lua page.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local rest_utils = require "rest_utils"
local auth       = require "auth"
local json       = require "dkjson"

-- Auth guard
if not auth.has_capability(auth.capabilities.preferences) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- Parse POST body
local body = {}
if _POST and _POST["payload"] then
   body = json.decode(_POST["payload"]) or {}
elseif _POST then
   body = _POST
end

local section_id = body["pref_section"] or ""
local entry_key  = body["pref_key"]     or ""
local new_value  = body["pref_value"]

if isEmptyString(section_id) or isEmptyString(entry_key) or new_value == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- Rebuild schema to locate the entry and its redis_key
local prefs_menu_schema = require "prefs_menu_schema"
local flags             = prefs_menu_schema.get_flags()
local all_sections      = prefs_menu_schema.get_sections(flags)

-- Locate the target entry
local target_section = nil
local target_entry   = nil

for _, section in ipairs(all_sections) do
   if section.id == section_id and not section.hidden then
      for _, entry in ipairs(section.entries or {}) do
         if entry.key == entry_key and not entry.hidden then
            target_section = section
            target_entry   = entry
            break
         end
      end
      break
   end
end

if not target_section or not target_entry then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

-- Guard: reject writes to pro/enterprise sections on community builds
if target_section.pro_only then
   local is_pro = flags.is_pro or false
   if not is_pro then
      rest_utils.answer(rest_utils.consts.err.not_granted)
      return
   end
end

-- Guard: auth at-least-one (local/ldap/radius/http/oidc toggles)
local auth_toggle_keys = {
   "ntopng.prefs.local.auth_enabled",
   "ntopng.prefs.ldap.auth_enabled",
   "ntopng.prefs.radius.auth_enabled",
   "ntopng.prefs.http_authenticator.auth_enabled",
   "ntopng.prefs.oidc.enabled",
}

local function is_auth_toggle(redis_key)
   for _, k in ipairs(auth_toggle_keys) do
      if k == redis_key then return true end
   end
   return false
end

if is_auth_toggle(target_entry.redis_key) and new_value == "0" then
   local one_enabled = false
   for _, k in ipairs(auth_toggle_keys) do
      if k ~= target_entry.redis_key then
         if ntop.getPref(k) == "1" then
            one_enabled = true
            break
         end
      end
   end
   if not one_enabled then
      rest_utils.answer(rest_utils.consts.err.bad_content,
         { message = i18n("prefs.at_least_one_auth_required") })
      return
   end
end

-- Guard: data retention ordering (aggregated > raw)
local RAW_KEY  = "ntopng.prefs.flows_and_alerts_data_retention_days"
local AGG_KEY  = "ntopng.prefs.aggregated_flows_data_retention_days"

if target_entry.redis_key == RAW_KEY or target_entry.redis_key == AGG_KEY then
   local raw_val = tonumber(ntop.getPref(RAW_KEY)  or "30") or 30
   local agg_val = tonumber(ntop.getPref(AGG_KEY)  or "365") or 365
   local new_num = tonumber(new_value) or 0

   if target_entry.redis_key == RAW_KEY then
      raw_val = new_num
   else
      agg_val = new_num
   end

   if agg_val <= raw_val then
      -- Auto-correct: bump aggregated to raw+1
      ntop.setPref(AGG_KEY, tostring(raw_val + 1))
   end
end

-- Resolve user-scoped keys
local redis_key = target_entry.redis_key
if target_entry.user_pref then
   local session_user = _SESSION and _SESSION["user"] or ""
   redis_key = redis_key:gsub("__SESSION_USER__", session_user)
end

-- Convert display units back to storage units (e.g. days -> seconds)
if target_entry.display_multiplier then
   local num = tonumber(new_value)
   if num then
      new_value = tostring(math.floor(num * target_entry.display_multiplier))
   end
end

-- Write to Redis
ntop.setPref(redis_key, tostring(new_value))

-- Notify runtime for logging-level changes
if entry_key == "toggle_logging_level" then
   ntop.setLoggingLevel(new_value)
end

rest_utils.answer(rest_utils.consts.success.ok, {})
