--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
local rest_utils = require "rest_utils"

--
-- Get local stats distribution for an interface
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/interface/localstats.lua?ifid=1&iflocalstat_mode=distribution"
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/interface/localstats.lua?ifid=1"
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
end

interface.select(ifid)
local ifstats = interface.getStats()

if (ifstats.iface_role_traffic ~= nil) then
   if(ifstats.iface_role_traffic.peering > 0) then
      res[#res + 1] = { label = i18n("prefs.snmp_interface_role_list.peering"), value = ifstats.iface_role_traffic.peering }
   end

   if(ifstats.iface_role_traffic.transit > 0) then
      res[#res + 1] = { label = i18n("prefs.snmp_interface_role_list.transit"), value = ifstats.iface_role_traffic.transit }
   end

   if(ifstats.iface_role_traffic.ix > 0) then
      res[#res + 1] = { label = i18n("prefs.snmp_interface_role_list.ix"), value = ifstats.iface_role_traffic.ix }
   end
--[[
   -- Removed as requested in ticket https://github.com/ntop/ntopng/issues/10783
   
   if(ifstats.iface_role_traffic.other > 0) then
      res[#res + 1] = { label = i18n("prefs.snmp_interface_role_list.other"), value = ifstats.iface_role_traffic.other }
   end
   
]]
end

rest_utils.answer(rc, res)
