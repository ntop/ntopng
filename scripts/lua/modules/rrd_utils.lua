local os_utils = require "os_utils"
require "lua_utils"

SECONDS_IN_A_HOUR = 3600
SECONDS_IN_A_DAY = SECONDS_IN_A_HOUR*24

local rrd_utils = {}

--------------------------------------------------------------------------------

-- Note: these date functions are expensive, use with care!

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

--------------------------------------------------------------------------------

-- Considers NaN and negative values as 0
function rrd_get_positive_value(x)
  if(x ~= x) or (x <= 0) then
    return 0
  else
    return x
  end
end

--------------------------------------------------------------------------------

-- Select only one or more data series (columns)
--
-- Parameters:
--  fdata: RRD series data
--  selected: either a
--      - list of columns to select
--      - map of column->alias to select
function rrd_select_columns(fdata, selected)
  if next(selected) == nil then
    -- selected is a list
    for sname, svalue in pairs(fdata) do
      -- check if value is in selected list
      local found = false
      
      for i=1,#selected do
        if selected[i] == sname then
          found = true
          break
        end
      end

      if not found then
        fdata[sname] = nil
      end
    end
  else
    -- selected is a map
    local to_insert = {}
    for sname, svalue in pairs(fdata) do
      if selected[sname] ~= nil then
        if selected[sname] ~= sname then
          -- use alias
          to_insert[selected[sname]] = svalue
          fdata[sname] = nil
        end
      else
        -- not found
        fdata[sname] = nil
      end
    end

    for key,val in pairs(to_insert) do
      fdata[key] = val
    end
  end
end

--------------------------------------------------------------------------------

--
-- Integrates derivate RRD data to meet the specified resolution.
--
-- Parameters
--  epoch_start - the desired epoch start
--  epoch_end - the desired end epoch
--  resolution - the desired resolution
--  start - the raw start date
--  rawdata - the raw derived series data
--  npoints - number of points in each data serie
--  rawstep - rawdata internal step
--  extra - extra parameters, for additional functionalities
--      date_mode - if true, the resolution is interpreted as if you want dates to be
--              separated by this resolution step. This enables daylight checks to
--              to adjust actual time intervals, which are computational intensive because of
--              Lua dates functions usage.
--      with_activity - if true, a new column "activity" will be added to the output data, containing the
--              total activity time in seconds for the interval.
--
-- Returns
--   On success: a list of times,
--               the rawdata parameter will be modified in place
--   On error: a string containing some error message
--
function rrd_interval_integrate(epoch_start, epoch_end, resolution, start, rawdata, npoints, rawstep, extra)
  resolution = math.floor(resolution)
  extra = extra or {}
  local date_mode = extra.date_mode
  local with_activity = extra.with_activity
  local orig_resol = resolution

  -- check resolution consistency
  if rawstep > resolution then
    -- TODO i18n should be available
    --~ return {error=i18n('error_rrd_low_resolution', {prefs=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=on_disk_rrds"})}
    return {error='error_rrd_low_resolution'}
  end

  if epoch_start < start  then
    -- TODO i18n
    return {error='error_rrd_starts_before'}
  end

  if((with_activity) and (rawdata.activity ~= nil)) then
    -- TODO i18n
    return {error='error_activity_column_exists'}
  end

  local function set_resolution(prevtime, newtime)
    if date_mode then
      -- handle daylight changes
      resolution = orig_resol
      local from_dst = timestamp_to_date(prevtime).isdst
      local to_dst = timestamp_to_date(newtime).isdst
      if from_dst and not to_dst then
        resolution = resolution + 3600
      elseif not from_dst and to_dst then
        -- 1 to avoid infinite loop
        resolution = math.max(resolution - 3600, 1)
      end
    end
  end

  -- functions to handle the n-dimensional counters
  local function create_counters()
    local counters = {}
    for sname,sdata in pairs(rawdata) do
      counters[sname] = 0
    end
    return counters
  end
  
  -- iterates the n-dimensional counters and calls the 1-dimension callback, passing current counter value and column
  -- callback should return the new counter value
  local function for_each_counter_do_update(counters, callback)
    for sname,svalue in pairs(rawdata) do
      counters[sname] = callback(counters[sname], sname)
    end
  end

  -- use same table to avoid allocation overhead; Please take care not to cross src_idx with dst_idx
  local src_idx = 1 -- this will be used to read the original data
  local dst_idx = 1 -- this will be used to write the integrated data, in order to avoid further allocations
  local integer_ctrs = create_counters()
  local time_sum = epoch_start

  -- Pre-declare callbacks to improve performance while looping
  local prefix_slice
  local traffic_in_step = 0

  local function c_dump_slice (value, col)
    -- Save the previous value to avoid overwriting it when (src_idx == dst_idx)
    local prev_val = rawdata[col][src_idx]
    -- Calculate the traffic belonging to previous step
    local prefix_traffic = prefix_slice * rawdata[col][src_idx]
    traffic_in_step = traffic_in_step + prefix_traffic

    -- Save into previous step
    rawdata[col][dst_idx] = value + prefix_traffic

    -- Update the counter with suffix traffic
    return prev_val - prefix_traffic
  end

  local function c_accumulate_partial (value, col)
    traffic_in_step = traffic_in_step + rawdata[col][src_idx]
    return value + rawdata[col][src_idx]
  end

  local function c_fill_remaining (value, col)
    rawdata[col][dst_idx] = value
    
    -- will zero integer_ctrs for next intervals
    return 0
  end
  
  local function c_fill_nil (value, col)
    rawdata[col][dst_idx] = nil
  end

  -- normalize derived data
  for sname,sdata in pairs(rawdata) do
    for t=1, #sdata do
      sdata[t] = rrd_get_positive_value(sdata[t]) * rawstep
    end
  end

  --~ io.write("\n\n")
  --~ io.write("\nsrc_idx="..src_idx.." dst_idx="..dst_idx.." fstep/res="..rawstep.."/"..resolution.." fstart/dstart="..start.."/"..epoch_start.."\n")

  -- when the was data starts before desired start
  if start < epoch_start then
    local toskip = math.min(math.ceil((epoch_start - start) / rawstep), npoints)
    local prevtime = start + rawstep * (toskip-1)
    local alignment = (1 - (epoch_start - prevtime) / rawstep)

    -- skip starting rows
    src_idx = toskip + 1
    for_each_counter_do_update(integer_ctrs, function (value, col)
      return value + rawdata[col][toskip] * alignment
    end)
  end

  local curtime = start + (src_idx-1) * rawstep   -- goes up with raw steps
  local times = {}
  local activity = {}
  local activity_secs = 0

  local function debug_me()
    io.write("\nsrc_idx="..src_idx.." dst_idx="..dst_idx.." fstep/res="..rawstep.."/"..resolution.." curtime/dstart="..curtime.."/"..epoch_start.."\n")
    tprint(rawdata)
  end

  --~ debug_me()
  --~ assert(curtime >= epoch_start)
  --~ assert(src_idx <= dst_idx)
  
  -- main integration
  while src_idx <= npoints and time_sum <= epoch_end do
    set_resolution(time_sum, curtime)
    traffic_in_step = 0
    
    if curtime + rawstep >= time_sum + resolution then
      local prefix_t = time_sum + resolution - curtime
      --~ tprint(prefix_t)

      -- Calculate the time fraction belonging to previous step
      prefix_slice = prefix_t / rawstep

      times[dst_idx] = time_sum
      for_each_counter_do_update(integer_ctrs, c_dump_slice)

      if with_activity then
        if traffic_in_step > 0 then
          activity_secs = activity_secs + prefix_t
        end

        activity[dst_idx] = activity_secs;
        activity_secs = 0
      end

      dst_idx = dst_idx + 1
      
      time_sum = time_sum + resolution
    else
      -- Accumulate partial slices of traffic
      for_each_counter_do_update(integer_ctrs, c_accumulate_partial)

      if(with_activity and (traffic_in_step > 0)) then
        activity_secs = activity_secs + rawstep
      end
    end

    curtime = curtime + rawstep
    src_idx = src_idx + 1
  end

  -- case RRD end is before epoch_end
  while time_sum <= epoch_end do
    -- Save integer_ctrs result
    set_resolution(curtime, time_sum)
    times[dst_idx] = time_sum
    if with_activity then activity[dst_idx] = activity_secs; activity_secs = 0 end
    --~ assert(dst_idx < src_idx)
    for_each_counter_do_update(integer_ctrs, c_fill_remaining)
    dst_idx = dst_idx + 1
    curtime = time_sum
    time_sum = time_sum + resolution
  end

  --~ debug_me()

  -- nullify remaining data to free table entries
  while dst_idx <= npoints do
    for_each_counter_do_update(integer_ctrs, c_fill_nil)
    dst_idx = dst_idx + 1
  end

  if with_activity then rawdata.activity = activity end
  return times
end


function get_interface_rrd_creation_key(ifid)
   local k = "ntopng.prefs.ifid_"..ifid..".interface_rrd_creation"
   return k
end

function interface_rrd_creation_enabled(ifId)
   return not (ntop.getPref(get_interface_rrd_creation_key(ifId)) == "false")
end

-- ########################################################

local function create_rrd(name, step, ds)
   step = tonumber(step)
   if step == nil or step <= 1 then step = 1 end
   if(not(ntop.exists(name))) then
      if(enable_second_debug == 1) then io.write('Creating RRD ', name, '\n') end
      local prefs = ntop.getPrefs()
      ntop.rrd_create(
	 name,
	 step,   -- step
	 'DS:' .. ds .. ':DERIVE:'.. step * 5 .. ':U:U',
	 'RRA:AVERAGE:0.5:1:'..tostring(prefs.intf_rrd_raw_days*24*(3600/step)),   -- raw: 1 day = 86400
	 'RRA:AVERAGE:0.5:'..(60/step)..':'..tostring(prefs.intf_rrd_1min_days*24*60),   -- 1 min resolution = 1 month
	 'RRA:AVERAGE:0.5:'..(3600/step)..':'..tostring(prefs.intf_rrd_1h_days*24), -- 1h resolution (3600 points)   2400 hours = 100 days
	 'RRA:AVERAGE:0.5:'..(86400)..':'..tostring(prefs.intf_rrd_1d_days) -- 1d resolution (86400 points)  365 days
	 -- 'RRA:HWPREDICT:1440:0.1:0.0035:20'
      )
   end
end

-- ########################################################

local function create_rrd_num(name, ds, step)
   step = tonumber(step)
   if step == nil or step <= 1 then step = 1 end
   if(not(ntop.exists(name))) then
      if(enable_second_debug == 1) then io.write('Creating RRD ', name, '\n') end
      local prefs = ntop.getPrefs()
      ntop.rrd_create(
	 name,
	 step,   -- step
	 'DS:' .. ds .. ':GAUGE:' .. step * 5 .. ':0:U',
	 'RRA:AVERAGE:0.5:1:'..tostring(prefs.intf_rrd_raw_days*24*(3600/step)),   -- raw: 1 day = 86400
	 'RRA:AVERAGE:0.5:'..(3600/step)..':'..tostring(prefs.intf_rrd_1h_days*24), -- 1h resolution (3600 points)   2400 hours = 100 days
	 'RRA:AVERAGE:0.5:'..(86400/step)..':'..tostring(prefs.intf_rrd_1d_days) -- 1d resolution (86400 points)  365 days
	 -- 'RRA:HWPREDICT:1440:0.1:0.0035:20'
      )
   end
end

-- ########################################################

function rrd_utils.makeRRD(basedir, when, if_id, key, rrdname, step, value)
   local name = os_utils.fixPath(basedir .. "/" .. rrdname .. ".rrd")

   if rrdname:find("^num_") then
      create_rrd_num(name, rrdname, step)
   else
      create_rrd(name, step, rrdname)
   end

   ntop.rrd_update(name, nil, string.format("%u", value or 0))

   local tskey = if_id
   if(key ~= nil) then tskey = tskey ..":"..key end
   ntop.tsSet(when, "iface", nil, rrdname, 0, tonumber(value))

   if(step == 1 and (if_id == 0) and string.contains(name, "packets")) then
      -- io.write('Updating RRD ['.. if_id..'] '.. name .. " " .. value ..'\n')
   end
   
   if(enable_second_debug) then
      -- io.write('Updating RRD ['.. if_id..'] '.. name .. " " .. value ..'\n')
   end
end

return rrd_utils
