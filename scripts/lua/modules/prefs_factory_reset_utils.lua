--
-- (C) 2014-22 - ntop.org
--

local prefs_factory_reset_utils = {}

-- ###########################################

-- Key used to request the factory reset of runtime preferences
-- Factory reset is performed in in boot.lua
local prefs_factory_reset_request_key = "ntopng.cache.prefs_factory_reset_request"

-- ###########################################

-- @brief Request a factory reset (performed during the next startup)
function prefs_factory_reset_utils.request_prefs_factory_reset()
   ntop.setCache(prefs_factory_reset_request_key, "1")
end

-- ###########################################

-- @brief Clears a pending factory reset request. Should be called when
--        the factory reset has been performed successfully
function prefs_factory_reset_utils.clear_prefs_factory_reset_request()
   -- Delete as factory reset is going to be performed by the caller
   ntop.delCache(prefs_factory_reset_request_key)
end

-- ###########################################

-- @brief Checks whether a factory reset has been requested
function prefs_factory_reset_utils.is_prefs_factory_reset_requested()
   local dump_requested = ntop.getCache(prefs_factory_reset_request_key)

   if dump_requested == "1" then
      return true
   end

   return false
end

-- ###########################################

return prefs_factory_reset_utils
