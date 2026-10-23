--
-- (C) 2013-26 - ntop.org
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

local clock_start = os.clock()

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "locales_utils"

local auth = {}

-- #######################

-- Label translated on first access: calling i18n here would load the whole
-- locale (~15-40 ms) on every require of auth, also in scripts never using it
local function capability(id, label_i18n)
   return setmetatable({ id = id }, {
      __index = function(cap, key)
         if key == "label" then
            local label = i18n(label_i18n)
            rawset(cap, "label", label)
            return label
         end
      end
   })
end

-- List of available capabilities
-- NOTE: Keep ids in sync with ntop_typedefs.h UserCapabilities
auth.capabilities = {
   pools             = capability(0, "capabilities.pools"),
   notifications     = capability(1, "capabilities.notifications"),
   snmp              = capability(2, "capabilities.snmp"),
   active_monitoring = capability(3, "capabilities.active_monitoring"),
   preferences       = capability(4, "capabilities.preferences"),
   developer         = capability(5, "capabilities.developer"),
   checks            = capability(6, "capabilities.checks"),
   flowdevices       = capability(7, "capabilities.flowdevices"),
   alerts            = capability(8, "capabilities.alerts"),
   historical_flows  = capability(9, "capabilities.historical_flows"),
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

-- @brief Returns the list of allowed networks or nil if all networks are allowed
function auth.allowed_networks()
   if isAdministrator()
      or isEmptyString(_SESSION["allowed_nets"])
      or _SESSION["allowed_nets"] == '0.0.0.0/0,::/0' -- See CONST_DEFAULT_ALL_NETS
   then
      return nil
   end

   return _SESSION["allowed_nets"]
end

-- #######################

-- @brief Returns a table of allowed host pool IDs (integers), or nil if all pools are allowed
function auth.allowed_host_pools()
   if isAdministrator() then
      return nil
   end

   local pools = ntop.getAllowedHostPools()
   if not pools or table.len(pools) == 0 then
      return nil
   end

   return pools
end

-- #######################

-- @brief Checks whether the currently logged user is allowed to access host pool `pool_id`
function auth.is_allowed_host_pool(pool_id)
   local allowed_pools = auth.allowed_host_pools()

   if not allowed_pools then
      -- No restriction is configured for this user, every pool is allowed
      return true
   end

   pool_id = tonumber(pool_id)

   if not pool_id then
      return false
   end

   return allowed_pools[pool_id] == true
end

-- #######################

if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

return auth
