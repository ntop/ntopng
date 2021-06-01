--
-- (C) 2021 - ntop.org
--

-- A sample timeseries driver
local driver = {}

-- ##############################################

--! @brief Driver constructor.
--! @param options global options.
--! @return the newly created driver.
function driver:new(options)
end

--! @brief Append a new data point to the timeseries.
--! @param schema the schema object.
--! @param timestamp the data point timestamp.
--! @param tags map tag_name->tag_value. It contains exactly the tags defined in the schema.
--! @param metrics map metric_name->metric_value. It contains exactly the metrics defined in the schema.
--! @return the true on success, false otherwise.
function driver:append(schema, timestamp, tags, metrics)
end

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
end

-- ##############################################

return driver
