--
-- (C) 2014-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"
require "lua_utils"


function useAggregatedFlows()
   if aggr_pref == nil then
      aggr_pref = ntop.getPrefs()["is_flow_aggregation_enabled"]
   end
   return aggr_pref == true
   --return false
end
