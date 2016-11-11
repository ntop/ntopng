
-- TODO localize
local RRD_RESULT_ERROR_EMPTY = "Empty RRD"
local RRD_RESULT_ERROR_MALFORMED = "Malformed RRD"

SECONDS_IN_A_HOUR = 3600
SECONDS_IN_A_DAY = SECONDS_IN_A_HOUR*24

function timestamp_to_date(ts)
  return os.date("*t", ts)
end

function date_to_timestamp(dt)
  return os.time(dt)
end

function date_month_tostring(m)
  return os.date("%B", date_to_timestamp(m))  
end

function date_day_tostring(d)
  local res = os.date("%d", date_to_timestamp(d))
  if d.day < 10 then
    res = string.sub(res, 2)
  end
  return res
end

function date_wday_tostring(d)
  return os.date("%A", date_to_timestamp(d))
end

-- returns the days in the given year
function date_get_year_days(y)
  return timestamp_to_date(os.time{year=y+1, day=1, month=1, hour=0} - 1).yday
end

function date_tostring(dt)
  return os.date("%x %X", dt)
end

--
-- Fetches data from RRD derivate counters
--
-- Parameters
--      rrdname = path of the RRD
--      epoch_start = start timestamp for query
--      epoch_end = end timestamp for query
--
-- Returns
--  On error:
--      result.error = error string
--  On success:
--      result.data = a table, where each key is a data series containing a list of fetched values
--      result.count = number of values in each data series
--      result.start = timestamp for first value
--      result.step = timestamp step between values
--      result.names = rrd column names
--
function rrd_fetch_derivate(rrdname, epoch_start, epoch_end)
  local result = {}

  if(not ntop.notEmptyFile(rrdname)) then
    result.error = RRD_RESULT_ERROR_EMPTY
  else
    local fstart, fstep, fnames, fdata = ntop.rrd_fetch(rrdname, 'AVERAGE', epoch_start, epoch_end)
    if(fstart == nil) then
      result.error = RRD_RESULT_ERROR_MALFORMED
    else
      result.start = fstart + fstep
      result.step = fstep
      result.data = {}

      -- for the data series, use the same labels as the RRD counters
      for j=1,#fnames do
        result.data[fnames[j]] = {}
      end

      local get_rrd_value = function(x) if(x ~= x) or (x < 0) then return 0 else return x * fstep end end

      for i=1,#fdata do
        for j=1,#fnames do
          table.insert(result.data[fnames[j]], get_rrd_value(fdata[i][j]))
        end
      end

      result.count = #fdata
      result.names = fnames
    end
  end
  
  return result
end

--
-- Transforms RRD data to meet the specified resolution.
--
-- Parameters
--  epoch_start - wanted epoch start
--  epoch_end - wanted end epoch
--  resolution - wanted resolution
--  traffic - input traffic with the format below, plus the "time" column
--  columns - a list of RRD column names
--  
--  traffic format (compatible with rrd_fetch_derivate return value):
--    .start start RRD date
--    .step  RRD hardware step
--    .count number of RRD rows
--    .data table containing [.count] rows of tables with [columns] format
--
-- Returns
--   On success:
--    result table, containing tables with [columns] format, with the specified resolution
--
--   On RRD error:
--    result
--      .error - with some error message
--
function rrd_fix_resolution(epoch_start, epoch_end, resolution, traffic, columns)
  -- BEGIN parameters check
  if (columns == nil or #columns < 1) then
    error("No data columns")
  end
  epoch_start = tonumber(epoch_start)
  if (epoch_start == nil or traffic == nil) then
    error("Parameter error")
  end
  local rrd_start = tonumber(traffic.start)
  local rrd_step = tonumber(traffic.step)
  local rrd_count = tonumber(traffic.count)
  local rrd_data = traffic.data
  local target_resol = tonumber(resolution)
  if (rrd_start == nil or rrd_step == nil or rrd_count == nil or rrd_data == nil or target_resol == nil) then
    error("Parameter error")
  end
  -- END parameters check

  -- check resolution consinstency
  if traffic.step > resolution then
    return {error=i18n('error_rrd_low_resolution', {prefs=ntop.getHttpPrefix().."/lua/admin/prefs.lua?subpage_active=on_disk_rrds"})}
  end

  -- functions to handle the n-dimensions counters
  local function create_counters()
    local counters = {}
    for i=1,#columns do
      counters[columns[i]] = 0
    end
    return counters
  end
  -- iterates the n-dimensions counters and calls the 1-dimension callback, passing current counter value and column
  -- callback should return the new counter value
  local function for_each_counter_do_update(counters, callback)
    for i=1,#columns do
      local col = columns[i]
      counters[col] = callback(counters[col], col)
    end
  end

  -- initialize
  local integr_ctrs = create_counters()
  local idx = 1
  local time_col = "time"
  local oldtime = epoch_start
  local time_sum = epoch_start
  local result = {[time_col]={}, hwstep=rrd_step}
  for i=1,#columns do
    result[columns[i]] = {}
  end
  
  -- special case
  if rrd_start < epoch_start then
    local toskip = math.max(math.ceil((epoch_start - rrd_start) / rrd_step), rrd_count)
    old_time = rrd_start + rrd_step * (toskip-1)
    local aligment = (1 - (epoch_start - old_time) / rrd_step)

    -- skip starting rows
    idx = toskip + 1
    for_each_counter_do_update(integr_ctrs, function (value, col)
      return value + traffic.data[col][toskip] * aligment
    end)
  end

  -- precondition: rrd_start >= time_sum
  local curtime = rrd_start + (idx-1) * rrd_step
  local orig_resol = target_resol
  
  while idx <= rrd_count and time_sum <= epoch_end do
    -- handle daylight changes
    target_resol = orig_resol
    local from_dst = timestamp_to_date(time_sum).isdst
    local to_dst = timestamp_to_date(curtime).isdst
    if from_dst and not to_dst then
      target_resol = target_resol + 3600
    elseif not from_dst and to_dst then
      -- 1 to avoid infinite loop
      target_resol = math.max(target_resol - 3600, 1)
    end
    
    local tdiff = curtime - time_sum
    
    if tdiff >= target_resol then
      local prefix_t = time_sum + target_resol - oldtime

      -- Calculate the traffic belonging to previous step
      local prefix_slice = prefix_t / rrd_step
      local prefix_ctrs = create_counters()
      -- Set prefix_ctrs with the prefix_slice of traffic
      for_each_counter_do_update(prefix_ctrs, function (value, col)
        return traffic.data[col][idx] * prefix_slice
      end)

      -- Sum prefix slice of traffic and save result
      table.insert(result[time_col], time_sum)
      for_each_counter_do_update(integr_ctrs, function (value, col)
        table.insert(result[col], value + prefix_ctrs[col])
        -- set counters to the remaining slice
        return traffic.data[col][idx] - prefix_ctrs[col]
      end)
      
      time_sum = time_sum + target_resol
      tdiff = tdiff - prefix_t
    else
      -- Accumulate partial slices of traffic
      for_each_counter_do_update(integr_ctrs, function (value, col)
        return value + traffic.data[col][idx]
      end)
    end

    oldtime = curtime
    curtime = curtime + rrd_step
    idx = idx + 1
  end

  -- case RRD end is before epoch_end
  while time_sum <= epoch_end do
    table.insert(result[time_col], time_sum)
    -- Save integr_ctrs result
    for_each_counter_do_update(integr_ctrs, function (value, col)
      table.insert(result[col], value)
      -- will zero integr_ctrs for next intervals
      return 0
    end)
    time_sum = time_sum + target_resol
  end

  return result
end
