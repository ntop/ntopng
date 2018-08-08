--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "grafana_utils"
local ts_utils = require("ts_utils")

interface.select(ifname)
local ifnames = interface.getIfNames()

if isCORSpreflight() then
   processCORSpreflight()
else
   local corsr = {}
   corsr["Access-Control-Allow-Origin"] = _SERVER["Origin"]
   sendHTTPHeader('application/json', nil, corsr)

   local epoch_begin = toEpoch(_POST["payload"]["range"]["from"])
   local epoch_end   = toEpoch(_POST["payload"]["range"]["to"])

   -- override max_num_points in singlerrd2json
   global_max_num_points = _POST["payload"]["maxDataPoints"]
   if global_max_num_points > 600 then
      global_max_num_points = 600
   end

   local res = {}

   for _, t in pairs(_POST["payload"]["targets"]) do
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
      local is_allcategories = string.ends(t["target"], "_allcategories_bps")

      local ifname = string.gsub(t["target"], "^(.-)_", "") -- lazy match to remove up to the first underscore
      ifname = string.gsub(ifname, "_(.-)$", "") -- lazy match to remove up to the last underscore

      local schema = nil
      local is_topk = false

      if is_traffic then
         if is_host then schema = "host:traffic" else schema = "iface:traffic" end
      elseif is_packets then schema = "iface:packets"
      elseif is_allprotos then
         if is_host then schema = "host:ndpi" else schema = "iface:ndpi" end
         is_topk = true
      elseif is_allcategories then
         if is_host then schema = "host:ndpi_categories" else schema = "iface:ndpi_categories" end
         is_topk = true
      else goto continue end

      local datapoints = {}

      local options = {
         max_num_points = global_max_num_points
      }

      local rr
      local tags = {ifid=getInterfaceId(ifname), host=addr}

      if is_topk then
         rr = ts_utils.queryTopk(schema, tags, epoch_begin, epoch_end, options)
      else
         rr = ts_utils.query(schema, tags, epoch_begin, epoch_end, options)
      end

      if not rr then
         goto continue
      end

      local totalval = nil
      if rr.statistics then
         totalval = rr.statistics.total
      end

      local label = ifname
      if is_host then label = addr..", "..label end
      label = "["..label.."]"

      if is_allprotos then
	 toSeries(rr, res, label)
      elseif string.ends(t["target"], "traffic_total_bytes") or string.ends(t["target"], "traffic_total_packets") then
         if totalval then
	 res[#res + 1] = {target="Total", datapoints={{totalval, 0 --[[ it's an integral, an instant is not meaningful here --]]}}}
         end
      else
	 toSeries(rr, res, label)
      end



      -- tprint({target=target, is_traffic=is_traffic, is_packets=is_packets, entity_name=entity_name})
      ::continue::
   end

   --tprint(_POST["payload"])

   -- tprint("QUERY")
   -- tprint(_POST)

   print(json.encode(res, nil))
end
