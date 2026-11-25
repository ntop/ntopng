--
-- (C) 2026 - ntop.org
--
-- Seeding of the preference defaults into Redis.
--
local prefs_defaults = {}

-- ! @brief Write the declared default of every preference that is missing from Redis.
-- ! @return the number of preferences seeded.
function prefs_defaults.seedMissing()
   local prefs_menu_schema = require "prefs_menu_schema"
   local sections = prefs_menu_schema.get_sections(prefs_menu_schema.get_flags())
   local seeded = 0

   for _, section in ipairs(sections or {}) do
      for _, entry in ipairs(section.entries or {}) do
         local default = (entry.default ~= nil) and tostring(entry.default) or ""
         local skip = isEmptyString(default) or entry.dynamic_default or
                      entry.user_pref or (entry.redis_key == nil)

         if not skip and isEmptyString(ntop.getPref(entry.redis_key)) then
            ntop.setPref(entry.redis_key, default)
            seeded = seeded + 1
         end
      end
   end

   return seeded
end

return prefs_defaults
