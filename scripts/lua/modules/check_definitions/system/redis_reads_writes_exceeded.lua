--
-- (C) 2019-24 - ntop.org
--

local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")
local alert_categories = require "alert_categories"

local script = {
  -- Script category
  category = alert_categories.internals,
  severity = alert_consts.get_printable_severities().warning,

  hooks = {},

  gui = {
     i18n_title = "alerts_dashboard.redis_reads_writes_exceeded",
     i18n_description = "alerts_dashboard.redis_reads_writes_exceeded_descr",
  }
}

-- #################################################################

local function check_redis_reads_writes_exceeded(params)
   local ts_utils = require("ts_utils")
   -- TS options
   local options = {
      max_num_points = 7,
      keep_total = false,
      tags = {
         ifid = '-1'
      },
      with_series = true,
      keep_nan = true,
      epoch_begin = os.time() - (7 * 24 * 60 * 60),
      target_aggregation = 'raw',
      epoch_end = os.time(),
      initial_point = false,
      min_num_points = 2,
      schema = 'redis:reads_writes_v2'
   }
   local ts = ts_utils.timeseries_query(options)
   -- Check if the day target is nan
   if not (ts.series[1].data[7] == ts.series[1].data[7]) then
      return
   end
   local sumr = 0
   local valr = 0
   local sumw = 0
   local valw = 0

   -- Compute the standard deviation
   for i = 1, 7 do
      if (ts.series[1].data[i] == ts.series[1].data[i]) then
         sumr = sumr + (ts.series[1].data[i]-ts.series[1].statistics.average) ^ 2
         valr = valr + 1
      end
      if (ts.series[2].data[i] == ts.series[2].data[i]) then
         sumw = sumw + (ts.series[2].data[i]-ts.series[2].statistics.average) ^ 2
         valw = valw + 1
      end
   end
   
   -- If the days with value are less than 3, don't trigger the alert in any case
   if valr <= 3 or valw <=3 then 
      return
   end
   
   local devstdr = math.sqrt(sumr/valr)
   local devstdw = math.sqrt(sumw/valw)
   
   -- z-score for reads and writes
   local zscorer = (ts.series[1].data[7] - ts.series[1].statistics.average) / devstdr
   local zscorew = (ts.series[2].data[7] - ts.series[2].statistics.average) / devstdw


   local alert = alert_consts.alert_types.alert_redis_reads_writes_exceeded.new(
         zscorer,
         zscorew
      )
   alert:set_info(params)

   if (zscorer > 2.5) or (zscorer < -2.5) then
      alert:trigger(params.alert_entity, nil, params.cur_alerts)      
   elseif (zscorew > 2.5) or (zscorew < -2.5) then
      alert:release(params.alert_entity, nil, params.cur_alerts)
   end
end

-- #################################################################

script.hooks.day = check_redis_reads_writes_exceeded

-- #################################################################

return script
