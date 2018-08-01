require "lua_utils"
local clean_shutdown_key = "ntopng.clean_shutdown"

local recovery_utils = {}

function recovery_utils.mark_clean_shutdown()
   -- set a key to tell we are terminated normally
   ntop.setCache(clean_shutdown_key, "1")
end

function recovery_utils.unmark_clean_shutdown()
   -- delete the 'normal termination' key
   -- that will be inserted back during shutdown
   ntop.delCache(clean_shutdown_key)
end

function recovery_utils.check_clean_shutdown()
   -- let's check if we are restarting from an anomalous termination
   -- e.g., from a crash
   if ntop.getCache(clean_shutdown_key) == "1" then
      -- clean
      return true
   end

   -- anomalous
   return false
end

return recovery_utils
