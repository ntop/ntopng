--
-- (C) 2021 - ntop.org
--

local auth_sessions_utils = {}

local dirs = ntop.getDirs()

-- ##############################################

function auth_sessions_utils.midnightCheck()
   local prefs = ntop.getPrefs()
   local terminate = prefs["auth_session_midnight_expiration"]

   if not terminate then
      return
   end

   local session_keys = ntop.getKeysCache("sessions.*")
   for matching_key, _ in pairs(session_keys or {}) do
      ntop.delCache(matching_key)
   end
end

return auth_sessions_utils
