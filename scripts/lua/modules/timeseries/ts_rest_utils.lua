
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local ts_rest_utils = {}
   
function ts_rest_utils.get_timeseries(http_context)
   local graph_common = require "graph_common"
   local graph_utils = require "graph_utils"
   local ts_utils = require("ts_utils")
   local ts_common = require("ts_common")

   local ts_schema = http_context.ts_schema
   local tstart    = http_context.epoch_begin
   local tend      = http_context.epoch_end
   local compare_backward = http_context.ts_compare
   local tags      = http_context.ts_query
   local extended_times  = http_context.extended
   local ts_aggregation  = http_context.ts_aggregation
   local no_fill = tonumber(http_context.no_fill)

   tstart = tonumber(tstart) or (os.time() - 3600)
   tend = tonumber(tend) or os.time()
   tags = tsQueryToTags(tags)
   if http_context.tskey then
      -- This can contain a MAC address for local broadcast domain hosts
      local tskey = http_context.tskey

      -- Setting host_ip (check that the provided IP matches the provided
      -- mac address as safety check and to avoid security issues)
      if tags.host then
	 local host = hostkey2hostinfo(tags.host)
	 if not isEmptyString(host["host"]) then
	    local host_info = interface.getHostInfo(host["host"], host["vlan"])
	    -- local mac_info = split(tskey, "_")
	    -- if (host_info) and (host_info.mac == mac_info[1]) then
	    --    tags.host_ip = tags.host;
	    if(host_info ~= nil) then
	       local mac_info = split(tskey, "_")

	       if(host_info.name ~= nil) then
		  -- Add the symbolic host name (if present)
		  tags.label = host_info.name
	       end

	       if(host_info.mac == mac_info[1]) then
		  tags.host_ip = tags.host;
	       end
	    end
	 end
      end

      tags.host = tskey
   end

   local options = {
      max_num_points = tonumber(http_context.limit) or 60,
      initial_point = toboolean(http_context.initial_point),
      with_series = true,
      target_aggregation = ts_aggregation or "raw",
   }

   if(no_fill == 1) then
      options.fill_value = 0/0 -- NaN
   end

   if tags.ifid then
      interface.select(tags.ifid)
   end

   if((ts_schema == "top:flow_check:duration")
      or (ts_schema == "top:elem_check:duration")
      or (ts_schema == "custom:flow_check:total_stats")
      or (ts_schema == "custom:elem_check:total_stats")) then
      -- NOTE: Temporary fix for top checks page
      tags.check = nil
   end

   local function performQuery(tstart, tend, keep_total, additional_options)
      local res
      additional_options = additional_options or {}
      local options = table.merge(options, additional_options)

      if starts(ts_schema, "top:") then
	 local ts_schema = split(ts_schema, "top:")[2]

	 res = ts_utils.queryTopk(ts_schema, tags, tstart, tend, options)
      else
	 res = ts_utils.query(ts_schema, tags, tstart, tend, options)

	 if(not keep_total) and (res) and (res.additional_series) then
	    -- no need for total serie in normal queries
	    res.additional_series.total = nil
	 end
      end

      return res
   end

   local res

   if(ntop.getPref("ntopng.prefs.ndpi_flows_rrd_creation") == "1") then
      if(ts_schema == "host:ndpi") then
	 ts_schema = "custom:host_ndpi_and_flows"
      elseif(ts_schema == "iface:ndpi") then
	 ts_schema = "custom:iface_ndpi_and_flows"
      end
   end

   if starts(ts_schema, "custom:") and graph_utils.performCustomQuery then
      res = graph_utils.performCustomQuery(ts_schema, tags, tstart, tend, options)
      compare_backward = nil
   else
      res = performQuery(tstart, tend) or {}

      -- if Mac address ts is requested, check if the serialize by mac is enabled and if no data is found, use the host timeseries. 
      if (table.len(res) == 0) or (res.statistics) and (res.statistics.total == 0) then
	 local serialize_by_mac = ntop.getPref(string.format("ntopng.prefs.ifid_" .. tags.ifid .. ".serialize_local_broadcast_hosts_as_macs")) == "1"
	 local tmp = split(ts_schema, ":")
	 
	 if (serialize_by_mac) and (tags.mac) then
	    ts_schema = "host:" .. tmp[2]
	    tags.host = tags.mac .. "_v4"
	    res = performQuery(tstart, tend)
	 end
      end
   end

   if res == nil then
      res = {}

      if(ts_utils.getLastError() ~= nil) then
	 res["tsLastError"] = ts_utils.getLastError()
	 res["error"] = ts_utils.getLastErrorMessage()
	 rest_utils.answer(rest_utils.consts.err.internal_error, res)
      else
	 rest_utils.answer(rest_utils.consts.success.ok, res)
      end

      return
   end

   -- Add metadata
   res.schema = ts_schema
   res.query = tags
   res.max_points = options.max_num_points

   if not isEmptyString(compare_backward) and compare_backward ~= "1Y" and (res.step ~= nil) then
      local backward_sec = graph_common.getZoomDuration(compare_backward)
      local tstart_cmp = res.start - backward_sec
      local tend_cmp = tstart_cmp + res.step * (res.count - 1)

      -- Try to use the same aggregation as the original query
      local res_cmp = performQuery(tstart_cmp, tend_cmp, true, {target_aggregation=res.source_aggregation}) or {}
      local total_cmp_serie = nil

      if res_cmp and res_cmp.additional_series and res_cmp.additional_series.total and (res_cmp.step) and res_cmp.step >= res.step then
	 total_cmp_serie = res_cmp.additional_series.total

	 if res_cmp.step > res.step then
	    -- The steps may not still correspond if the past query overlaps a retention policy
	    -- bound (it will have less points, but with an higher step), upscale to solve this
	    total_cmp_serie = ts_common.upsampleSerie(total_cmp_serie, res.count)
	 end
      end

      if total_cmp_serie then
	 res.additional_series = res.additional_series or {}
	 res.additional_series[compare_backward.. " " ..i18n("details.ago")] = total_cmp_serie
      end
   end

   -- TODO make a script parameter?
   local extend_labels = true

   if extend_labels and graph_utils.extendLabels then
      graph_utils.extendLabels(res)
   end

   -- Add layout information
   local layout = graph_utils.get_timeseries_layout(ts_schema)
   local filtered_serie = {}

   for _, serie in pairs(res.series or {}) do

      if not serie.type then
	 if layout[serie.label] then
	    serie.type = layout[serie.label]
	 end
      end

      local ts_tot_value = 0
      for _, ts_value in pairs(serie.data or {}) do
	 ts_tot_value = ts_tot_value + tonumber(ts_value or 0)
      end

      if ts_tot_value > 0 then
	 filtered_serie[#filtered_serie + 1] = serie
      end
   end

   res.series = filtered_serie

   if extended_times then
      if res.series and res.step then
	 for k, serie in pairs(res.series) do
	    serie.data = ts_common.serieWithTimestamp(serie.data, tstart, res.step)
	 end
      end
      if res.additional_series and res.step then
	 for k, serie in pairs(res.additional_series) do
	    res.additional_series[k] = ts_common.serieWithTimestamp(serie, tstart, res.step)
	 end
      end
   end
   
   return res
end -- end get_timeseries

return ts_rest_utils
