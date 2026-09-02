--
-- (C) 26- - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;"         .. package.path
require "check_redis_prefs"

if ntop.isPro and ntop.isPro() and isnAnalystAvailable()
   and ntop.isEnterpriseL and ntop.isEnterpriseL()
   and ntop.isClickHouseEnabled and ntop.isClickHouseEnabled() then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;"     .. package.path
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/llm/?.lua;" .. package.path

   require("ai_policy_dispatch").run("daily")
end