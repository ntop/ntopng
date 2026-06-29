--
-- (C) 2014-26 - ntop.org
--
-- GET /lua/rest/v2/get/ntopng/prefs_schema.lua
--
-- Returns the full typed preference schema plus current Redis values.


local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local rest_utils       = require "rest_utils"
local auth             = require "auth"

-- Auth guard
if not auth.has_capability(auth.capabilities.preferences) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- Build flags + sections
local prefs_menu_schema = require "prefs_menu_schema"
local flags             = prefs_menu_schema.get_flags()
local sections          = prefs_menu_schema.get_sections(flags)

-- Inject current Redis values + filter hidden sections
local session_user = _SESSION and _SESSION["user"] or ""

local visible_sections = {}

for _, section in ipairs(sections) do
   -- Skip fully hidden sections
   if not section.hidden then
      local visible_entries = {}

      for _, entry in ipairs(section.entries or {}) do
         if not entry.hidden then
            -- Resolve user-scoped redis keys (theme, date format)
            local redis_key = entry.redis_key
            if redis_key and entry.user_pref then
               redis_key = redis_key:gsub("__SESSION_USER__", session_user)
               entry.redis_key = redis_key
            end

            -- Read current value from Redis (same as old prefs.lua prefsToggleButton /
            -- prefsInputFieldPrefs which call ntop.getPref directly).
            local value = ""
            if redis_key then
               value = ntop.getPref(redis_key) or ""
            end

            -- Fall back to schema default when empty (schema default must match C++ default)
            if value == "" and entry.default ~= nil then
               value = tostring(entry.default)
            end

            -- Convert stored units to display units (e.g. seconds → days)
            if entry.display_multiplier and value ~= "" then
               local num = tonumber(value)
               if num then
                  value = tostring(math.floor(num / entry.display_multiplier))
               end
            end

            -- Password fields: return the real value; the Vue renders type="password"
            -- which auto-hides it in the browser. No masking needed.

            entry.value = value
            visible_entries[#visible_entries + 1] = entry
         end
      end

      section.entries = visible_entries
      visible_sections[#visible_sections + 1] = section
   end
end

rest_utils.answer(rest_utils.consts.success.ok, { subpages = visible_sections })
