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

-- entry.locked / section.locked hold either one reason or a list of them
-- (a preference can miss several prerequisites at once). Normalize to a list,
-- so the client always renders the same shape.
local function lock_reasons(locked)
   if not locked then
      return nil
   end

   return (type(locked) == "table") and locked or { locked }
end

for _, section in ipairs(sections) do
   -- Skip fully hidden sections
   if not section.hidden then
      local visible_entries = {}

      -- entry.hidden means "not available on this build/product" and is decided
      -- here, once. Visibility that depends on another preference is NOT encoded
      -- in entry.hidden: it is driven client-side from to_switch/show_when, so a
      -- dependent field is shipped and merely hidden until its parent is on.
      -- Shipping an entry hidden here would show a field that set/preferences.lua
      -- then refuses to write ("Not found").
      -- entry.locked is the opposite: the preference is shown, with its current
      -- value, but greyed out and carrying the reason it cannot be changed.
      for _, entry in ipairs(section.entries or {}) do
         if not entry.hidden then
            -- A locked section locks everything it holds
            entry.locked = lock_reasons(entry.locked) or lock_reasons(section.locked)

            -- pref-field.vue disables every control type on entry.disabled
            if entry.locked then
               entry.disabled = true
            end

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

      -- A section whose entries are all unavailable on this build has nothing
      -- left to show: drop it instead of rendering an empty page.
      if #visible_entries > 0 then
         -- When nothing inside can be edited the section itself reads as locked,
         -- so the sidebar can grey it out and explain why (e.g. External
         -- Integrations holds only Wazuh, which needs ClickHouse).
         if not section.locked then
            local all_locked, reason = true, nil

            for _, entry in ipairs(visible_entries) do
               if not entry.locked then
                  all_locked = false
                  break
               end
               reason = reason or entry.locked
            end

            if all_locked then
               section.locked = reason
            end
         else
            section.locked = lock_reasons(section.locked)
         end

         section.entries = visible_entries
         visible_sections[#visible_sections + 1] = section
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok, { subpages = visible_sections })
