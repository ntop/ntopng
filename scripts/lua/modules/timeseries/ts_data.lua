local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import required modules for timeseries processing
require "lua_utils" -- General ntopng utilities
require "check_redis_prefs" -- Redis preferences checking

-- Main module for handling timeseries data operations
local ts_data = {}

-- Private function: Adds host information to timeseries tags
-- This function is called when timeseries data is memory-resident
-- and enriches tags with MAC and IP information when available
local function addHostInfo(tags)
   -- Extract host information from the host key in tags
   local host = hostkey2hostinfo(tags.host)

   -- Check if MAC serialization preference is enabled
   -- This preference determines if local hosts should be serialized as MACs instead of IPs
   local serialize_by_mac = ntop.getPref(string.format("ntopng.prefs.ifid_" .. tags.ifid .. ".serialize_local_broadcast_hosts_as_macs")) ==
                               "1"

   -- If host is not empty and MAC serialization is enabled
   if not isEmptyString(host["host"]) and serialize_by_mac then
      -- Get minimal host information from the interface
      local host_info = interface.getHostMinInfo(host["host"], host["vlan"])
      if (host_info ~= nil) then
         -- If MAC address is available, add it to tags
         if (host_info.mac) and not isEmptyString(host_info.mac) then
            tags.mac = host_info.mac;
         end

         -- Add host IP to tags
         tags.host_ip = host_info.ip
      end
   end

   return tags
end

-- Private function: Executes a timeseries query
-- Handles both normal queries and "top" (ranked) queries
local function performQuery(options)
   local ts_utils = require("ts_utils")

   local res = {}

   -- Check if it's a "top" query (schema starting with "top:")
   if starts(options.schema, "top:") then
      -- Save the original schema
      local top_schema = options.schema

      -- Extract base schema by removing the "top:" prefix
      local schema = split(options.schema, "top:")[2]
      options.schema = schema

      -- Execute "top" query (ranked timeseries)
      res = ts_utils.timeseries_query_top(options)

      -- Restore original schema
      options.schema = top_schema
   else
      -- Execute normal timeseries query
      res = ts_utils.timeseries_query(options)
   end

   return res
end

-- Private function: Compares current data with historical data (backward comparison)
-- Used for comparison features like "compare with one week ago"
local function compareBackward(compare_backward, curr_res, options)
   local graph_common = require "graph_common"
   local ts_common = require("ts_common")

   -- Calculate comparison period duration in seconds
   local backward_sec = graph_common.getZoomDuration(compare_backward)

   -- Calculate time interval for comparison
   local start_cmp = curr_res.metadata.epoch_begin - backward_sec
   local end_cmp = start_cmp + curr_res.metadata.epoch_step * (curr_res.metadata.num_point - 1)

   -- Create a copy of options with modified time interval
   local tmp_options = table.merge(options, {
      target_aggregation = curr_res.metadata.source_aggregation
   })
   tmp_options.keep_total = false
   tmp_options.epoch_begin = start_cmp
   tmp_options.epoch_end = end_cmp

   -- Try to use the same aggregation as the original query
   local res = performQuery(tmp_options) or {}

   if (res) and (res.metadata) and (res.metadata.epoch_step) then
      curr_res.additional_series = {}
      curr_res.additional_series[compare_backward .. "_ago"] = res
   end

   return curr_res
end

-- Public function: Processes timeseries request filters
-- Handles special filtering cases for timeseries queries
function ts_data.handle_ts_requests_filters(ts_requests)
   local processed_ts_requests = {}

   for k, v in pairsByKeys(ts_requests, asc) do
      -- Special case: Handle "top:asn:traffic" schema with "customer" filter
      -- This expands customer ASN queries into multiple individual ASN queries
      if v["ts_schema"] == "top:asn:traffic" and v["ts_filter"] and v["ts_filter"] == "customer" then
         local as_utils = require "as_utils"
         local customer_asn = as_utils.getCustomerASNs()

         if table.len(customer_asn) > 0 then
            -- Create separate query for each customer ASN
            for asn, asn_v in pairs(customer_asn) do
               processed_ts_requests[#processed_ts_requests + 1] = {
                  ts_query = v["ts_query"] .. ",asn:" .. asn, -- Append ASN to query
                  ts_schema = "asn:traffic", -- Change to non-top schema
                  tskey = tostring(asn), -- Use ASN as key
                  ts_unify = true -- Unify results
               }
            end
         else
            -- If no customer ASNs found, keep original request
            processed_ts_requests[#processed_ts_requests + 1] = v
         end
      else
         -- For all other cases, keep the request unchanged
         processed_ts_requests[#processed_ts_requests + 1] = v
      end
   end

   return processed_ts_requests
end

-- Main public function: Retrieves timeseries data based on HTTP context
-- This is the primary entry point for timeseries data retrieval
function ts_data.get_timeseries(http_context)
   local graph_utils = require "graph_utils"

   -- Extract parameters from HTTP context
   local ts_schema = http_context.ts_schema
   local compare_backward = http_context.ts_compare
   local extended_times = http_context.extended
   local ts_aggregation = http_context.ts_aggregation

   -- Special handling for iface:ndpi schema resolution
   -- Resolves to correct schema based on available metrics (bytes vs sent/rcvd)
   if ts_schema == "top:iface:ndpi" then
      ts_schema = "top:" .. getIfacenDPITsName()
   end

   -- Build query options from HTTP context
   local options = {
      min_num_points = 2, -- Minimum data points to return
      max_num_points = tonumber(http_context.limit) or 60, -- Maximum data points
      initial_point = toboolean(http_context.initial_point), -- Include initial point
      epoch_begin = tonumber(http_context.epoch_begin) or (os.time() - 3600), -- Start time (default: 1 hour ago)
      epoch_end = tonumber(http_context.epoch_end) or os.time(), -- End time (default: now)
      with_series = true, -- Include series data in response
      target_aggregation = ts_aggregation or "raw", -- Data aggregation level
      keep_nan = true, -- Keep NaN values in results
      keep_total = false, -- Don't include total aggregation
      tags = http_context.tags, -- Query tags/filters
      schema = ts_schema, -- Timeseries schema
      ts_unify = http_context.ts_unify -- Unify multiple series
   }

   -- Select interface if specified in tags
   if options.tags.ifid then
      interface.select(options.tags.ifid)
   end

   -- Special handling for SNMP interface traffic schemas
   -- Maps port tag to if_index for SNMP compatibility
   if (options.schema == 'snmp_if:traffic_min' or options.schema == 'snmp_if:traffic') and options.tags.port then
      options.tags.if_index = options.tags.port
      options.tags.ifid = getSystemInterfaceId()
      options.tags.port = nil
   end

   -- Handle timeseries key (tskey) processing
   if http_context.tskey then
      local tskey = http_context.tskey -- Can contain MAC address for local hosts

      -- Special cases where host tag is not required or should be cleared
      if (options.schema == "top:snmp_if:packets") or (options.schema == "top:snmp_if:traffic") or
         (options.schema == "top:flowdev_port:traffic") then
         tskey = 0 -- Use 0 as placeholder
         options.tags.host = nil -- Clear host tag
      end

      -- Add host info if host tag is present
      if options.tags.host then
         options.tags = addHostInfo(options.tags)
      end
   end

   -- Temporary fix for top checks page schemas
   if ((options.schema == "top:flow_check:duration") or (options.schema == "top:elem_check:duration")) then
      options.tags.check = nil -- Remove check tag
   end

   local res = {}

   -- Handle MAC address serialization preference
   -- If MAC serialization is enabled and MAC tag exists, adjust schema and tags
   local serialize_by_mac = ntop.getPref(string.format("ntopng.prefs.ifid_" .. options.tags.ifid ..
                                                          ".serialize_local_broadcast_hosts_as_macs")) == "1"
   local tmp = split(options.schema, ":")

   if (serialize_by_mac) and (options.tags.mac) then
      local ts_utils = require("ts_utils")
      options.schema = "host:" .. tmp[2] -- Change to host schema
      options.tags.host = options.tags.mac .. "_v4" -- Use MAC as host identifier

      -- InfluxDB-specific handling: remove certain tags
      if ts_utils.getDriverName() == "influxdb" then
         options.tags.host_ip = nil
         options.tags.mac = nil
      end
   end

   -- Execute the timeseries query
   res = performQuery(options) or {}

   -- Handle case where no results are found
   if res == nil then
      local ts_utils = require("ts_utils")
      res = {}

      -- If there was an error, prepare error response
      if ts_utils.getLastError() then
         local rest_utils = require "rest_utils"

         -- Include error information in response
         res["tsLastError"] = ts_utils.getLastError()
         res["error"] = ts_utils.getLastErrorMessage()
         rest_utils.answer(rest_utils.consts.err.internal_error, res)
      end

      -- Return empty result with potential error info
      return res
   end

   -- Ensure metadata table exists
   if not res.metadata then
      res.metadata = {}
   end

   -- Add backward comparison series if requested
   if not isEmptyString(compare_backward) and (res.metadata.epoch_step) then
      res = compareBackward(compare_backward, res, options)
   end

   return res
end -- End of get_timeseries function

return ts_data
