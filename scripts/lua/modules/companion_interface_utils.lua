--
-- (C) 2014-20 - ntop.org
--

local dirs = ntop.getDirs()
require "lua_utils"

local companion_interface_prefix = "ntopng.prefs.companion_interface."
local companion_interface_key = string.format("%s%s", companion_interface_prefix, "ifid_%d.companion")
local companion_of_key = string.format("%s%s", companion_interface_prefix, "ifid_%d.companion_of")

local companion_interface_utils = {}

function companion_interface_utils.getCurrentCompanion(ifid)
   local k = string.format(companion_interface_key, ifid)
   local comp = ntop.getPref(k) or ""

   if comp == "" then
      return comp
   end

   -- must check if the companion interface is valid
   local ifaces = interface.getIfNames()

   for ifid, ifname in pairs(ifaces) do
      if comp == ifid then
	 return comp
      end
   end

   return ""
end

function companion_interface_utils.getCurrentCompanionOf(ifid)
   local k = string.format(companion_of_key, ifid)
   local of_ifaces = ntop.getMembersCache(k) or {}
   return of_ifaces
end

function companion_interface_utils.setCompanion(ifid, companion_ifid)
   local k = string.format(companion_interface_key, ifid)
   local cur_companion = companion_interface_utils.getCurrentCompanion(ifid)

   if cur_companion ~= companion_ifid then
      if companion_ifid == "" then
	 ntop.delCache(k)
	 ntop.delMembersCache(string.format(companion_of_key, cur_companion), tostring(ifid))
	 interface.reloadCompanions(tonumber(cur_companion))
      else
	 ntop.setCache(k, companion_ifid)
	 ntop.setMembersCache(string.format(companion_of_key, companion_ifid), tostring(ifid))
	 interface.reloadCompanions(tonumber(companion_ifid))
      end
   end
end

function companion_interface_utils.getAvailableCompanions()
   local cur_ifid = interface.getId()
   local ifaces = interface.getIfNames()

   local res = { {ifid = "", ifname = "None"} }
   for ifid, ifname in pairsByKeys(ifaces) do
      interface.select(ifid)

      if not interface.isPacketInterface() and cur_ifid ~= tonumber(ifid) then
	 res[#res + 1] = {ifid = ifid, ifname = ifname}
      end
   end

   interface.select(tostring(cur_ifid))
   return res
end

function companion_interface_utils.initCompanions()
   local ifaces = interface.getIfNames()

   for ifid, ifname in pairs(ifaces) do
      interface.reloadCompanions(tonumber(ifid))
   end
end

return companion_interface_utils

