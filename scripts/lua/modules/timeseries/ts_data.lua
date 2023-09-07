local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local ts_data = {}

-- If in memory, this function adds info to the tags regarding the host
local function addHostInfo(tags)
    -- Checking if the host is in memory
    local host = hostkey2hostinfo(tags.host)
    local serialize_by_mac = ntop.getPref(string.format("ntopng.prefs.ifid_" .. tags.ifid ..
                                                            ".serialize_local_broadcast_hosts_as_macs")) == "1"

    if not isEmptyString(host["host"]) and serialize_by_mac then
        local host_info = interface.getHostMinInfo(host["host"], host["vlan"])
        if (host_info ~= nil) then
            -- Add the label if available
            if (host_info.name) and not isEmptyString(host_info.name) then
                -- Add the symbolic host name (if present)
                tags.label = host_info.name
            end

            -- Add the label MAC if available
            if (host_info.mac) and not isEmptyString(host_info.mac) then
                tags.mac = host_info.mac;
            end

            tags.host_ip = host_info.ip
        end
    end

    return tags
end

local function performQuery(options)
    local ts_utils = require("ts_utils")

    local res = {}
    if starts(options.schema, "top:") then
        local top_schema = options.schema
        local schema = split(options.schema, "top:")[2]
        options.schema = schema
        res = ts_utils.timeseries_query_top(options)
        options.schema = top_schema
    else
        res = ts_utils.timeseries_query(options)
    end

    return res
end

local function compareBackward(compare_backward, curr_res, options)
    local graph_common = require "graph_common"
    local ts_common = require("ts_common")
    
    local backward_sec = graph_common.getZoomDuration(compare_backward)
    local start_cmp = curr_res.metadata.epoch_begin - backward_sec
    local end_cmp = start_cmp + curr_res.metadata.epoch_step * (curr_res.metadata.num_point - 1)

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
        curr_res.additional_series[compare_backward .. "_" .. i18n("details.ago")] = res
    end

    return curr_res
end

function ts_data.get_timeseries(http_context)
    local graph_utils = require "graph_utils"

    local ts_schema = http_context.ts_schema
    local compare_backward = http_context.ts_compare
    local extended_times = http_context.extended
    local ts_aggregation = http_context.ts_aggregation

    local options = {
        max_num_points = tonumber(http_context.limit) or 60,
        initial_point = toboolean(http_context.initial_point),
        epoch_begin = tonumber(http_context.epoch_begin) or (os.time() - 3600),
        epoch_end = tonumber(http_context.epoch_end) or os.time(),
        with_series = true,
        target_aggregation = ts_aggregation or "raw",
        keep_nan = true,
        keep_total = false,
        tags = http_context.tags,
        schema = ts_schema
    }

    if options.tags.ifid then
        interface.select(options.tags.ifid)
    end

    if http_context.tskey then
        -- This can contain a MAC address for local broadcast domain hosts
        local tskey = http_context.tskey

        -- Setting host_ip (check that the provided IP matches the provided
        -- mac address as safety check and to avoid security issues)
        if (options.schema == "top:snmp_if:packets") or (options.schema == "top:snmp_if:traffic") or (options.schema == "top:flowdev_port:traffic") then
            -- NOTE: the host here is not required, if added return an empty serie
            tskey = 0
            options.tags.host = nil
        end

        if options.tags.host then
            options.tags = addHostInfo(options.tags)
        end

        if tskey ~= 0 then
            options.tags.host = tskey
        end
    end

    if ((options.schema == "top:flow_check:duration") or (options.schema == "top:elem_check:duration")) then
        -- NOTE: Temporary fix for top checks page
        options.tags.check = nil
    end

    local res = {}

    -- if Mac address ts is requested, check if the serialize by mac is enabled and if no data is found, use the host timeseries. 
    -- if (table.len(res) == 0) or (res.statistics) and (res.statistics.total == 0) then
    local serialize_by_mac = ntop.getPref(string.format("ntopng.prefs.ifid_" .. options.tags.ifid ..
                                                            ".serialize_local_broadcast_hosts_as_macs")) == "1"
    local tmp = split(options.schema, ":")

    if (serialize_by_mac) and (options.tags.mac) then
        options.schema = "host:" .. tmp[2]
        options.tags.host = options.tags.mac .. "_v4"
    end

    res = performQuery(options) or {}
    
    -- No result found
    if res == nil then
        local ts_utils = require("ts_utils")
        res = {}

        if ts_utils.getLastError() then
            local rest_utils = require "rest_utils"

            -- Return an error in case of no result
            res["tsLastError"] = ts_utils.getLastError()
            res["error"] = ts_utils.getLastErrorMessage()
            rest_utils.answer(rest_utils.consts.err.internal_error, res)
        end

        -- Jump to the end
        return res
    end

    -- Add metadata other metadata
    if not res.metadata then
        res.metadata = {}
    end

    if not isEmptyString(compare_backward) and (res.metadata.epoch_step) then
        res = compareBackward(compare_backward, res, options)
    end

    return res
end -- end get_timeseries

return ts_data
