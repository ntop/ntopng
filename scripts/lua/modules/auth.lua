--
-- (C) 2013-21 - ntop.org
--

---------------------------------------------------------------------------------------
-- Implement user capabilities a-la linux.					     --
--										     --
-- For the purpose of performing permission checks, traditional UNIX		     --
-- implementations distinguish two categories of processes: privileged		     --
-- processes (whose effective user ID is 0, referred to as superuser or		     --
-- root), and unprivileged processes (whose effective UID is nonzero).		     --
-- Privileged processes bypass all kernel permission checks, while		     --
-- unprivileged processes are subject to full permission checking based		     --
-- on the process's credentials (usually: effective UID, effective GID,		     --
-- and supplementary group list).						     --
--										     --
-- Here, we have privileged users (admins) which can perform every operation	     --
-- and unprivileged users (non admins) which can only perform a subset of operations --
---------------------------------------------------------------------------------------

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local auth = {}

-- #######################

-- List of available capabilities
-- NOTE: Keep ids in sync with ntop_typedefs.h UserCapabilities
auth.capabilities = {
   pools             = {id = 0, label = i18n("capabilities.pools")},
   notifications     = {id = 1, label = i18n("capabilities.notifications")},
   snmp              = {id = 2, label = i18n("capabilities.snmp")},
   active_monitoring = {id = 3, label = i18n("capabilities.active_monitoring")},
   preferences       = {id = 4, label = i18n("capabilities.preferences")},
   developer         = {id = 5, label = i18n("capabilities.developer")},
   checks            = {id = 6, label = i18n("capabilities.checks")},
   flowdevices       = {id = 7, label = i18n("capabilities.flowdevices")},
   alerts            = {id = 8, label = i18n("capabilities.alerts")},
   historical_flows  = {id = 9, label = i18n("capabilities.historical_flows")},
}

-- #######################

-- @brief Checks whether the currently logged user has the specified `capability`
-- @param `capability` One of `auth.capabilities`
-- @return True if the user has `capability` or false otherwise
function auth.has_capability(capability)
   if isAdministrator() then
      -- Privileged users bypass all permission checks
      return true
   end

   if not _SESSION or not _SESSION["capabilities"] then
      -- Should not occur. A Session with capabilities is always present
      return false
   end

   if not capability or not capability.id then
      -- No id is present, `capability` is invalid
      return false
   end

   return ntop.bitmapIsSet(_SESSION["capabilities"], capability.id)
end

-- #######################

return auth
