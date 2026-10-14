--
-- (C) 2014-26 - ntop.org
--

-- Returns the Search Preferences with their current value, so the global search
-- can show and toggle them in place

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local rest_utils = require "rest_utils"
local auth = require "auth"

local SECTION_ID = "gui"

local prefs_menu_schema = require "prefs_menu_schema"
local flags = prefs_menu_schema.get_flags()
local sections = prefs_menu_schema.get_sections(flags)

local entries = {}

for _, section in ipairs(sections) do
   if section.id == SECTION_ID and not section.hidden then
      for _, entry in ipairs(section.entries or {}) do
         if not entry.hidden and entry.key:find("^toggle_search_") then
            local value = ntop.getPref(entry.redis_key)

            -- Fall back to the schema default (same as find_utils.lua)
            if isEmptyString(value) then
               value = entry.default
            end

            -- One or more reasons the preference cannot be changed
            local locked = entry.locked or section.locked
            if type(locked) == "table" then
               locked = table.concat(locked, " ")
            end

            entries[#entries + 1] = {
               key = entry.key,
               title = entry.title,
               description = entry.description,
               enabled = (value == "1"),
               locked = locked,
            }
         end
      end
      break
   end
end

rest_utils.answer(rest_utils.consts.success.ok, {
   section = SECTION_ID,
   editable = auth.has_capability(auth.capabilities.preferences),
   entries = entries,
})
