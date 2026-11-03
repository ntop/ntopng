--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_gui_utils = require "ts_gui_utils"

local ts_hash_state = {}

local timeseries_id = "ht"

local timeseries_list = {{
   schema = "ht:state",
   id = timeseries_id,
   label = i18n("hash_table.CountriesHash"),
   description = i18n("graphs.metric_descr.ht_CountriesHash"),
   priority = 0,
   measure_unit = "number",
   ts_query = "CountriesHash",
   scale = i18n('graphs.metric_labels.hash_entries'),
   timeseries = {
      num_idle = {
         label = i18n('graphs.metric_labels.num_idle'),
         color = ts_gui_utils.get_timeseries_color('default')
      },
      num_active = {
         label = i18n('graphs.metric_labels.num_active'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   },
   always_visibile = true,
   default_visible = true
}, {
   schema = "ht:state",
   id = timeseries_id,
   label = i18n("hash_table.HostHash"),
   description = i18n("graphs.metric_descr.ht_HostHash"),
   priority = 0,
   measure_unit = "number",
   ts_query = "HostHash",
   scale = i18n('graphs.metric_labels.hash_entries'),
   timeseries = {
      num_idle = {
         label = i18n('graphs.metric_labels.num_idle'),
         color = ts_gui_utils.get_timeseries_color('default')
      },
      num_active = {
         label = i18n('graphs.metric_labels.num_active'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   },
   default_visible = true
}, {
   schema = "ht:state",
   id = timeseries_id,
   label = i18n("hash_table.MacHash"),
   description = i18n("graphs.metric_descr.ht_MacHash"),
   priority = 0,
   measure_unit = "number",
   ts_query = "MacHash",
   scale = i18n('graphs.metric_labels.hash_entries'),
   timeseries = {
      num_idle = {
         label = i18n('graphs.metric_labels.num_idle'),
         color = ts_gui_utils.get_timeseries_color('default')
      },
      num_active = {
         label = i18n('graphs.metric_labels.num_active'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   },
   default_visible = true
}, {
   schema = "ht:state",
   id = timeseries_id,
   label = i18n("hash_table.FlowHash"),
   description = i18n("graphs.metric_descr.ht_FlowHash"),
   priority = 0,
   measure_unit = "number",
   ts_query = "FlowHash",
   scale = i18n('graphs.metric_labels.hash_entries'),
   timeseries = {
      num_idle = {
         label = i18n('graphs.metric_labels.num_idle'),
         color = ts_gui_utils.get_timeseries_color('default')
      },
      num_active = {
         label = i18n('graphs.metric_labels.num_active'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   },
   default_visible = true
}, {
   schema = "ht:state",
   id = timeseries_id,
   label = i18n("hash_table.AutonomousSystemHash"),
   description = i18n("graphs.metric_descr.ht_AutonomousSystemHash"),
   priority = 0,
   measure_unit = "number",
   ts_query = "AutonomousSystemHash",
   scale = i18n('graphs.metric_labels.hash_entries'),
   timeseries = {
      num_idle = {
         label = i18n('graphs.metric_labels.num_idle'),
         color = ts_gui_utils.get_timeseries_color('default')
      },
      num_active = {
         label = i18n('graphs.metric_labels.num_active'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   },
   default_visible = true
}, {
   schema = "ht:state",
   id = timeseries_id,
   label = i18n("hash_table.ObservationPointHash"),
   description = i18n("graphs.metric_descr.ht_ObservationPointHash"),
   priority = 0,
   measure_unit = "number",
   ts_query = "ObservationPointHash",
   scale = i18n('graphs.metric_labels.hash_entries'),
   timeseries = {
      num_idle = {
         label = i18n('graphs.metric_labels.num_idle'),
         color = ts_gui_utils.get_timeseries_color('default')
      },
      num_active = {
         label = i18n('graphs.metric_labels.num_active'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   },
   default_visible = true
}, {
   schema = "ht:state",
   id = timeseries_id,
   label = i18n("hash_table.VlanHash"),
   description = i18n("graphs.metric_descr.ht_VlanHash"),
   priority = 0,
   measure_unit = "number",
   ts_query = "VlanHash",
   scale = i18n('graphs.metric_labels.hash_entries'),
   timeseries = {
      num_idle = {
         label = i18n('graphs.metric_labels.num_idle'),
         color = ts_gui_utils.get_timeseries_color('default')
      },
      num_active = {
         label = i18n('graphs.metric_labels.num_active'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   },
   default_visible = true
},}

function ts_hash_state.getTimeseries(tags, tsOptions)
    -- The charts of one hash table (ht:state tagged by hash_table): only its entry
    if tags and tags.hash_table then
        for _, ts in ipairs(timeseries_list) do
            if ts.ts_query == tags.hash_table then
                return { ts }
            end
        end
    end

    return timeseries_list
end

return ts_hash_state
