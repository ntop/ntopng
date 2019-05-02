--
-- (C) 2014-19 - ntop.org
--

local dirs = ntop.getDirs()
require "lua_utils"

local companion_interface_key = "ntopng.prefs.companion_interface.ifid_%d.companion"

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

   -- if here the companion interface id set is no longer valid
   -- i.e., ntopng has been started with the previously set companion
   -- interface
   ntop.delCache(k)

   return ""
end

function companion_interface_utils.setCompanion(ifid, companion_ifid)
   local k = string.format(companion_interface_key, ifid)
   local cur_companion = companion_interface_utils.getCurrentCompanion(ifid)

   if cur_companion ~= companion_ifid then
      if companion_ifid == "" then
	 ntop.delCache(k)
      else
	 ntop.setCache(k, companion_ifid)
      end
   end

   -- TODO: reload companion
end

function companion_interface_utils.getAvailableCompanions()
   local cur_ifid = interface.getStats().id
   local ifaces = interface.getIfNames()

   local res = { {ifid = "", ifname = "None"} }
   for ifid, ifname in pairs(ifaces) do
      if cur_ifid ~= tonumber(ifid) then
	 res[#res + 1] = {ifid = ifid, ifname = ifname}
      end
   end

   return res
end

return companion_interface_utils

