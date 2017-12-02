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
   if global_max_num_points > 600 then
      global_max_num_points = 600 -- ensures 100% match between ntopng and grafana charts
   end

   local res = {}

   for _, t in pairs(_GRAFANA["payload"]["targets"]) do
      if t["target"] == nil then t["target"] = "" end

      local is_host = string.starts(t["target"] or '', "host_")

      local addr
      if is_host then
	 addr = string.match(t["target"], "_(.-)_") -- host address is between the first two underscores
	 t["target"] = string.gsub(t["target"], "host_(.-)_", "")
      end

      local is_traffic     = string.ends(t["target"], "_traffic_bps") or string.ends(t["target"], "_traffic_total_bytes")
      local is_packets   = string.ends(t["target"], "_traffic_pps") or string.ends(t["target"], "_traffic_total_packets")
      local is_allprotos = string.ends(t["target"], "_allprotocols_bps")

      local ifname = string.gsub(t["target"], "^(.-)_", "") -- lazy match to remove up to the first underscore
      ifname = string.gsub(ifname, "_(.-)$", "") -- lazy match to remove up to the last underscore

      local rrdfile = ""
      if is_traffic then rrdfile = "bytes.rrd"
      elseif is_packets then rrdfile = "packets.rrd"
      elseif is_allprotos then rrdfile ="all" end

      local datapoints = {}

      local rr = rrd2json(getInterfaceId(ifname), addr, rrdfile, epoch_begin, epoch_end)

      local totalval = rr["totalval"]
      rr = json.decode(rr["json"])

      local label = ifname
      if is_host then label = addr..", "..label end
      label = "["..label.."]"

      if is_allprotos then
	 toSeries(rr, res, label)
      elseif string.ends(t["target"], "traffic_total_bytes") or string.ends(t["target"], "traffic_total_packets") then
	 res[#res + 1] = {target="Total", datapoints={{totalval, 0 --[[ it's an integral, an instant is not meaningful here --]]}}}
      else
	 toSeries(rr, res, label)
      end



      -- tprint({target=target, is_traffic=is_traffic, is_packets=is_packets, entity_name=entity_name})
   end

   --tprint(_GRAFANA["payload"])

   -- tprint("QUERY")
   -- tprint(_GRAFANA)
   
   print(json.encode(res, nil))
end
