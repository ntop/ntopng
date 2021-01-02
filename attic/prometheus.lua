--
-- (C) 2019-21 - ntop.org
--

-- https://prometheus.io/ timeseries driver

local driver = {}

local prometheus_queue = "ntopng.prometheus_export_queue"
local max_prometheus_queueLen = 100000

-- ###########################

--! @brief Driver constructor.
--! @param options global options.
--! @return the newly created driver.
function driver:new(options)
  local obj = {
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-- ##############################################

--! @brief Append a new data point to the timeseries.
--! @param schema the schema object.
--! @param timestamp the data point timestamp.
--! @param tags map tag_name->tag_value. It contains exactly the tags defined in the schema.
--! @param metrics map metric_name->metric_value. It contains exactly the metrics defined in the schema.
--! @return the true on success, false otherwise.
function driver:append(schema, timestamp, tags, metrics)
   local debug = false
   
   if(debug) then
      print("----- Schema --------------")
      tprint(schema.name)
      print("------ Timestamp -------------")
      tprint(timestamp)
      print("----- Tags --------------")
      tprint(tags)
      print("----- Metrics --------------")
      tprint(metrics)
      print("-------------------")
   end

   local tags_str = ''
   for k, v in pairs(tags or {}) do
      --[[
	 All <label values> must be wrapped between " "
      --]]
      tags_str = tags_str..string.format('%s="%s",', k, v)
   end

   for k, v in pairs(metrics or {}) do
      --[[
	 https://prometheus.io/docs/concepts/data_model/

	 Samples form the actual time series data. Each sample consists of:

	 - a float64 value
	 - a millisecond-precision timestamp

	 In case you get prometheus errors, you can use the handy tool promtool
	 to check for metrics format. The tool is distributed together with
	 prometheus. For example:

	 curl http://localhost:3000/metrics | ./promtool check metrics
      --]]
      local metric_str = string.format('%s {%s metric="%s"} %f %d', schema.name, tags_str, k, v, timestamp * 1000)

      -- writing onto Prometheus
      ntop.lpushCache(prometheus_queue, metric_str)
      ntop.ltrimCache(prometheus_queue, 0, max_prometheus_queueLen)
   end
end

-- ##############################################

--! @brief Query timeseries data.
--! @param schema the schema object.
--! @param tstart lower time bound for the query.
--! @param tend upper time bound for the query.
--! @param tags a list of filter tags. It contains exactly the tags defined in the schema.
--! @param options query options.
--! @return a (possibly empty) query result on success, nil on failure.
function driver:query(schema, tstart, tend, tags, options)
end

--! @brief Calculate a sum on the timeseries metrics.
--! @param schema the schema object.
--! @param tstart lower time bound for the query.
--! @param tend upper time bound for the query.
--! @param tags a list of filter tags. It contains exactly the tags defined in the schema.
--! @param options query options.
--! @return a table containing metric->metric_total mappings on success, nil on failure.
function driver:queryTotal(schema_name, tstart, tend, tags, options)
end

--! @brief List all available timeseries for the specified schema, tags and time.
--! @param schema the schema object.
--! @param tags_filter a list of filter tags.
--! @param wildcard_tags the remaining tags of the schema which are considered wildcard.
--! @param start_time time filter. Only timeseries updated after start_time will be returned.
--! @return a (possibly empty) list of tags values for the matching timeseries on success, nil for non-existing series.
function driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
end

--! @brief Get top k items information.
--! @param schema the schema object.
--! @param tags a list of filter tags.
--! @param tstart lower time bound for the query.
--! @param tend upper time bound for the query.
--! @param options query options.
--! @param top_tags the remaining tags of the schema, on which top k calculation is taking place.
--! @return a (possibly empty) topk result on success, nil on error.
function driver:topk(schema, tags, tstart, tend, options, top_tags)
end

--! @brief Informs the driver that it's time to export data.
--! @note This is called periodically by ntopng and should not be called manually.
function driver:export()
   -- print("prometheus.lua driver:export() called\n")
end

--! @brief Get the most recent timestamp available for queries.
--! @param ifid can be used to possibly provide a more accurate answer.
--! @note a conservative way to implement this is to return the current time.
--! @return most recent timestamp available.
function driver:getLatestTimestamp(ifid)
  return os.time()
end

--! @brief Delete timeseries data
--! @param schema_prefix a prefix for the schemas.
--! @param tags a list of filter tags. When a given scheam tag is not specified, it will be considered wildcard.
--! @return true if operation was successful, false otherwise.
--! @note E.g. "iface" schema_prefix matches any schema starting with "iface:". Empty prefix is allowed and matches all the schemas.
function driver:delete(schema_prefix, tags)
  return(true)
end

--! @brief Delete old data.
--! @param ifid: the interface ID to process
--! @return true if operation was successful, false otherwise.
function driver:deleteOldData(ifid)
  return(true)
end

--! @brief This is called when some driver configuration changes.
--! @param ts_utils: a reference to the ts_utils module
--! @return true if operation was successful, false otherwise.
function driver:setup(ts_utils)
   return true
end

-- ##############################################

return driver
