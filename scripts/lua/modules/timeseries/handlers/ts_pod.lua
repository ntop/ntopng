--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_gui_utils = require "ts_gui_utils"

local ts_pod = {}

local timeseries_id = "pod"

local timeseries_list = {{
    schema = "pod:num_flows",
    id = timeseries_id,
    label = i18n("graphs.active_flows"),
    description = i18n("graphs.metric_descr.pod_active_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        as_client = {
            label = i18n('graphs.flows_as_client'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        as_server = {
            label = i18n('graphs.flows_as_server'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true,
    default_visible = true
}, {
    schema = "pod:num_containers",
    id = timeseries_id,
    label = i18n("containers_stats.containers"),
    description = i18n("graphs.metric_descr.pod_containers"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.containers'),
    timeseries = {
        num_containers = {
            label = i18n('graphs.metric_labels.num_containers'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    }
}, {
    schema = "pod:rtt",
    id = timeseries_id,
    label = i18n("containers_stats.avg_rtt"),
    description = i18n("graphs.metric_descr.pod_avg_rtt"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        as_client = {
            label = i18n('graphs.rtt_as_client'),
            color = ts_gui_utils.get_timeseries_color('default')
        },
        as_server = {
            label = i18n('graphs.rtt_as_server'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    },
    exclude_asn_mode = true
}, {
    schema = "pod:rtt_variance",
    id = timeseries_id,
    label = i18n("containers_stats.avg_rtt_variance"),
    description = i18n("graphs.metric_descr.pod_avg_rtt_variance"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        as_client = {
            label = i18n('graphs.variance_as_client'),
            color = ts_gui_utils.get_timeseries_color('default')
        },
        as_server = {
            label = i18n('graphs.variance_as_server'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    }
}}

function ts_pod.getTimeseries(tags, tsOptions)
    return timeseries_list
end

return ts_pod
