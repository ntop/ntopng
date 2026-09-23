--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require("lua_utils_get")
require("check_redis_prefs")
local ts_utils = require("ts_utils")
local ts_gui_utils = require("ts_gui_utils")

local ts_host_pool = {}

local timeseries_id = "host_pool"

local timeseries_list = {
	{
		schema = "host_pool:traffic",
		id = timeseries_id,
		label = i18n("graphs.traffic_rxtx"),
		description = i18n("graphs.metric_descr.host_pool_traffic_rxtx"),
		priority = 0,
		measure_unit = "bps",
		scale = i18n("graphs.metric_labels.traffic"),
		timeseries = {
			bytes_sent = {
				label = i18n("graphs.metric_labels.sent"),
				color = ts_gui_utils.get_timeseries_color("bytes_sent"),
			},
			bytes_rcvd = {
				invert_direction = true,
				label = i18n("graphs.metric_labels.rcvd"),
				color = ts_gui_utils.get_timeseries_color("bytes_rcvd"),
			},
		},
		always_visibile = true,
		default_visible = true,
	},
	{
		schema = "host_pool:throughput_bps",
		id = timeseries_id,
		label = i18n("graphs.throughput_bps"),
		description = i18n("graphs.throughput_bps"),
		priority = 0,
		measure_unit = "bps",
		scale = i18n("graphs.metric_labels.traffic"),
		timeseries = {
			bps = {
				label = i18n("graphs.metric_labels.throughput"),
				color = ts_gui_utils.get_timeseries_color("bytes"),
			},
		},
	},
	{
		schema = "host_pool:blocked_flows",
		id = timeseries_id,
		label = i18n("graphs.blocked_flows"),
		description = i18n("graphs.metric_descr.host_pool_blocked_flows"),
		nedge_only = true,
		priority = 0,
		measure_unit = "number",
		scale = i18n("graphs.metric_labels.flows"),
		timeseries = {
			num_flows = {
				label = i18n("graphs.metric_labels.num_flows"),
				color = ts_gui_utils.get_timeseries_color("default"),
			},
		},
	},
	{
		schema = "host_pool:hosts",
		id = timeseries_id,
		label = i18n("graphs.active_hosts"),
		description = i18n("graphs.metric_descr.host_pool_active_hosts"),
		priority = 0,
		measure_unit = "number",
		scale = i18n("graphs.metric_labels.hosts"),
		timeseries = {
			num_hosts = {
				label = i18n("graphs.metric_labels.num_hosts"),
				color = ts_gui_utils.get_timeseries_color("default"),
			},
		},
	},
	{
		schema = "host_pool:devices",
		id = timeseries_id,
		label = i18n("graphs.active_devices"),
		description = i18n("graphs.metric_descr.host_pool_active_devices"),
		priority = 0,
		measure_unit = "number",
		scale = i18n("graphs.metric_labels.devices"),
		timeseries = {
			num_devices = {
				label = i18n("graphs.metric_labels.num_devices"),
				color = ts_gui_utils.get_timeseries_color("default"),
			},
		},
	},
}

local function addTopTimeseries(tags, tsOptions)
	local timeseries = {}
	local host_pool_ts_enabled = ntop.getCache("ntopng.prefs.host_pools_rrd_creation")

	-- Top l7 Protocols
	-- Note: a single grouped query, series with no data are not returned
	if host_pool_ts_enabled then
		local series = ts_utils.queryTotalByTag("host_pool:ndpi", tags.epoch_begin, tags.epoch_end, tags, "protocol")
			or {}

		for _, serie in ipairs(series) do
			local protocol = serie.tags.protocol

			timeseries[#timeseries + 1] = {
				schema = "top:host_pool:ndpi",
				disable_perc_95_ts = true,
				group = i18n("graphs.l7_proto"),
				priority = 2,
				query = "protocol:" .. protocol,
				label = protocol,
				measure_unit = "bps",
				scale = i18n("graphs.metric_labels.traffic"),
				timeseries = {
					bytes_sent = {
						label = protocol .. " " .. i18n("graphs.metric_labels.sent"),
						color = ts_gui_utils.get_timeseries_color("bytes"),
					},
					bytes_rcvd = {
						label = protocol .. " " .. i18n("graphs.metric_labels.rcvd"),
						color = ts_gui_utils.get_timeseries_color("bytes"),
					},
				},
			}
		end
	end
   
   return timeseries
end

function ts_host_pool.getTimeseries(tags, tsOptions)
	local timeseries = {}
	local emptyEpoch = false
	if (not tags.epoch_begin) or not tags.epoch_end then
		emptyEpoch = true
	end
	timeseries = timeseries_list

	if not emptyEpoch then
		-- Remove empty timeseries
		timeseries = ts_gui_utils.removeEmptyTimeseries(timeseries, tags)
		local top_timeseries = addTopTimeseries(tags, tsOptions)
		timeseries = table.merge(timeseries, top_timeseries)
	end
	return timeseries
end

return ts_host_pool
