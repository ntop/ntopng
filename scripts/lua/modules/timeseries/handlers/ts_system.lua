--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
if ntop.isPro and ntop.isPro() then
	package.path = dirs.installdir .. "/scripts/lua/pro/modules/timeseries/handlers/?.lua;" .. package.path
end

local ts_gui_utils = require("ts_gui_utils")

local ts_system = {}

local timeseries_id = "system"

local timeseries_list = {
	{
		schema = "system:cpu_states",
		id = timeseries_id,
		label = i18n("about.cpu_load"),
		description = i18n("graphs.metric_descr.system_cpu_load"),
		priority = 0,
		measure_unit = "percentage",
		chart_type = "bar",
		scale = i18n("graphs.metric_labels.load"),
		timeseries = {
			iowait_pct = {
				label = i18n("about.iowait"),
				color = ts_gui_utils.get_timeseries_color("default"),
			},
			idle_pct = {
				label = i18n("about.idle"),
				color = ts_gui_utils.get_timeseries_color("default"),
				hidden = true,
			},
			active_pct = {
				label = i18n("about.active"),
				color = ts_gui_utils.get_timeseries_color("default"),
			},
		},
		always_visibile = true,
		default_visible = true,
		draw_stacked = true,
	},
	{
		schema = "process:resident_memory",
		id = timeseries_id,
		label = i18n("graphs.process_memory"),
		description = i18n("graphs.metric_descr.process_memory"),
		priority = 0,
		measure_unit = "bytes",
		scale = i18n("graphs.metric_labels.bytes"),
		timeseries = {
			resident_bytes = {
				label = i18n("graphs.metric_labels.bytes"),
				color = ts_gui_utils.get_timeseries_color("bytes"),
			},
		},
		always_visibile = true,
	},
	{
		schema = "process:num_alerts",
		id = timeseries_id,
		label = i18n("graphs.process_alerts"),
		description = i18n("graphs.metric_descr.process_alerts"),
		priority = 0,
		measure_unit = "alertps",
		scale = i18n("graphs.metric_labels.bytes"),
		timeseries = {
			written_alerts = {
				label = i18n("about.alerts_stored"),
				color = ts_gui_utils.get_timeseries_color("default"),
			},
			alerts_queries = {
				label = i18n("about.alert_queries"),
				color = ts_gui_utils.get_timeseries_color("default"),
			},
			dropped_alerts = {
				label = i18n("about.alerts_dropped"),
				color = ts_gui_utils.get_timeseries_color("default"),
			},
		},
	},
	{
		schema = "top:system:thread_cpu_load",
		id = timeseries_id,
		label = i18n("graphs.threads_cpu_load"),
		description = i18n("graphs.metric_descr.threads_cpu_load"),
		priority = 0,
		measure_unit = "percentage_no_limit",
		scale = i18n("graphs.metric_labels.load"),
		timeseries = {
			cpu_utilization_pct = {
				use_serie_name = true,
				color = ts_gui_utils.get_timeseries_color("default"),
			},
		},
		disable_default_ago_ts = true,
		draw_stacked = false,
	},
}

function ts_system.getTimeseries(tags, tsOptions)
	local timeseries = {}
	local emptyEpoch = (not tags.epoch_begin) or not tags.epoch_end or (tsOptions and tsOptions.emptyEpoch == true)

	timeseries = timeseries_list

	if ntop.isPro and ntop.isPro() then
		local ts_system_pro = require("ts_system_pro")
		local timeseries_pro = ts_system_pro.getTimeseries(tags, emptyEpoch, tsOptions)
		timeseries = table.merge(timeseries, timeseries_pro)
	end

	return timeseries
end

return ts_system
