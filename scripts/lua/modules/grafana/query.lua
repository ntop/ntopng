--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "grafana_utils"

interface.select(ifname)
local ifnames = interface.getIfNames()

if isCORSpreflight() then
   processCORSpreflight()
else
   local corsr = {}
   corsr["Access-Control-Allow-Origin"] = _SERVER["Origin"]
   sendHTTPHeader('application/json', nil, corsr)

   local epoch_begin = toEpoch(_GRAFANA["payload"]["range"]["from"])
   local epoch_end   = toEpoch(_GRAFANA["payload"]["range"]["to"])

   -- override max_num_points in singlerrd2json
   global_max_num_points = _GRAFANA["payload"]["maxDataPoints"]

   local res = {}
   for _, t in pairs(_GRAFANA["payload"]["targets"]) do
      local is_interface = string.starts(t["target"], "interface_")
      local is_bytes = string.ends(t["target"], "_bytes") or string.ends(t["target"], "_bytestotal")
      local is_packets = string.ends(t["target"], "_packets") or string.ends(t["target"], "_packetstotal")

      local target = string.gsub(t["target"], "^(.-)_", "") -- lazy match to remove up to the first underscore
      target = string.gsub(target, "_(.-)$", "") -- lazy match to remove up to the last underscore

      local rrdfile = ""
      if is_bytes then rrdfile = "bytes.rrd"
      elseif is_packets then rrdfile = "packets.rrd" end

      local datapoints = {}

      if is_interface then
	 local rr = rrd2json(getInterfaceId(target), nil, rrdfile, epoch_begin, epoch_end)

	 if string.ends(t["target"], "total") then
	    local totalval = rr["totalval"]
	    datapoints = {{totalval, 0 --[[ it's an integral, an instant is not meaningful here --]]}}
	 else
	    rr = json.decode(rr["json"])
	    -- rr[1] contains the timeseries of the first (and only) rrd
	    for _, point in ipairs(rr[1]["values"]) do
	       local instant = point[1]
	       local val     = point[2]
	       datapoints[#datapoints + 1] = {val, instant*1000}
	    end
	 end
      end


      res[#res + 1] = {target=t["target"], datapoints = datapoints}
      -- tprint({target=target, is_bytes=is_bytes, is_packets=is_packets, entity_name=entity_name})
   end

   --tprint(_GRAFANA["payload"])

   -- tprint("QUERY")
   -- tprint(_GRAFANA)
   
   print(json.encode(res, nil))
end
