--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_gui_utils = require "ts_gui_utils"

local ts_country = {}

local timeseries_id = "country"

local timeseries_list = {{
    schema = "country:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic"),
    description = i18n("graphs.metric_descr.country_traffic"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
    timeseries = {
        bytes_egress = {
            label = i18n('graphs.metrics_suffixes.egress'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        bytes_ingress = {
            label = i18n('graphs.metrics_suffixes.ingress'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        },
        bytes_inner = {
            label = i18n('graphs.metrics_suffixes.inner'),
            color = ts_gui_utils.get_timeseries_color('bytes_inner')
        }
    },
    always_visibile = true,
    default_visible = true
}, {
    schema = "country:score",
    id = timeseries_id,
    label = i18n("score"),
    description = i18n("graphs.metric_descr.country_score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score = {
            label = i18n('score')
        },
        scoreAsClient = {
            label = i18n('score_as_client')
        },
        scoreAsServer = {
            label = i18n('score_as_server')
        }
    }
}}

function ts_country.getTimeseries(tags, tsOptions)
    return timeseries_list
end

return ts_country
