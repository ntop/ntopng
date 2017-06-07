--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "grafana_utils"



if isCORSpreflight() then
   processCORSpreflight()
else
   interface.select(ifname)


   local corsr = {}
   corsr["Access-Control-Allow-Origin"] = _SERVER["Origin"]
   sendHTTPHeader('application/json', nil, corsr)

   -- tprint("SEARCH")
   -- tprint(_GRAFANA)

   local target = _GRAFANA["payload"]["target"]
   if target == nil then
      target = ""
   end

   local res = {}

   if isEmptyString(target) or string.starts("interface_", target) or string.starts(target, "interface_") then
      local ifnames = interface.getIfNames()
      for _, n in pairs(ifnames) do
	 local tb  = "interface_"..n.."_bytes"
	 local tp  = "interface_"..n.."_packets"
	 local tbt = "interface_"..n.."_bytestotal"
	 local tpt = "interface_"..n.."_packetstotal"

	 for _, t in pairs({tb, tp, tbt, tpt}) do
	    if isEmptyString(target) or string.starts(t, target) or string.starts(target, t) then
	       res[#res +1] = t
	    end
	 end

      end
   end

   print(json.encode(res, nil))
end
