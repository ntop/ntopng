--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
local internals_utils = require "internals_utils"
local periodic_activities_utils = require "periodic_activities_utils"
local ts_utils = require "ts_utils_core"
local now = os.time()

sendHTTPContentTypeHeader('application/json')

-- ################################################

local iffilter              = _GET["iffilter"]
local periodic_script       = _GET["periodic_script"]
local periodic_script_issue = _GET["periodic_script_issue"]
local currentPage           = _GET["currentPage"]
local perPage               = _GET["perPage"]
local sortColumn            = _GET["sortColumn"]
local sortOrder             = _GET["sortOrder"]

local sortPrefs = "internals_periodic_activites_data"

-- ################################################

-- Returns the last duration of the activity. If the activity is running
-- last duration is the amount of seconds since the activity was started.
-- If the activity is not running, the last duration is the actual recorded
-- last duration
local function get_last_duration_ms(stats)
   local status = stats.state
   local last_duration = 0

   if status == "running" then
      -- If running, last durations grows with the time as the activity is in progress
      if stats["last_start_time"] and stats["last_start_time"] > 0 and now >= stats["last_start_time"] then
	 last_duration = (now - stats["last_start_time"]) * 1000 --[[ Expected in milliseconds --]]
      end
   else
      if stats.duration.last_duration_ms > 0 then
	 last_duration = stats.duration.last_duration_ms
      end
   end

   return last_duration
end

-- ################################################

local function time_utilization(stats)
   local last_duration = get_last_duration_ms(stats)
   local busy = last_duration / (stats.max_duration_secs  * 1000) * 100

   return {busy = busy, available = 100 - busy}
end

-- ################################################

local function status2label(status)
   if status == "running" then
      return([[<span class="badge bg-success">]] .. i18n("running") .. [[</span>]])
   elseif status == "queued" then
      return([[<span class="badge bg-warning">]] .. i18n("internals.queued") .. [[</span>]])
   elseif status == "sleeping" then
      return([[<span class="badge bg-secondary">]] .. i18n("internals.sleeping") .. [[</span>]])
   else
      return("")
   end
end

-- ################################################

if isEmptyString(sortColumn) or sortColumn == "column_" then
   sortColumn = getDefaultTableSort(sortPrefs)
else
   if((sortColumn ~= "column_")
      and (sortColumn ~= "")) then
      tablePreferences("sort_"..sortPrefs, sortColumn)
   end
end

if isEmptyString(_GET["sortColumn"]) then
   sortOrder = getDefaultTableSortOrder(sortPrefs, true)
end

if((_GET["sortColumn"] ~= "column_")
   and (_GET["sortColumn"] ~= "")) then
   tablePreferences("sort_order_"..sortPrefs, sortOrder, true)
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number", perPage)
end

local sOrder = ternary(sortOrder == "asc", asc_insensitive, rev_insensitive)
local to_skip = (currentPage-1) * perPage

-- ################################################

local ifaces_scripts_stats = {}

local available_interfaces = interface.getIfNames()
-- Add the system interface to the available interfaces
available_interfaces[getSystemInterfaceId()] = getSystemInterfaceName()

for _, iface in pairs(available_interfaces) do
   if iffilter and iffilter ~= tostring(getInterfaceId(iface)) then
      goto continue
   end

   interface.select(iface)

   local scripts_stats = interface.getPeriodicActivitiesStats()

   -- Flatten out the nested tables
   for script, stats in pairs(scripts_stats) do
      ifaces_scripts_stats["ifid_"..getInterfaceId(iface).."_"..script] = {iface = iface, ifid = getInterfaceId(iface), script = script, stats = stats}
   end

   ::continue::
end

local totalRows = 0
local sort_to_key = {}

for k, script_stats in pairs(ifaces_scripts_stats) do
   local stats = script_stats.stats
   local status = stats.state

   if periodic_script then
      if script_stats.script ~= periodic_script then
	 goto continue
      end
   end

   if periodic_script_issue then
      local cur_issue = script_stats.stats[periodic_script_issue] or nil
      local num_cur_issue = script_stats.stats["num_" .. periodic_script_issue] or nil
      
      if periodic_script_issue == "any_issue" then
	 local found = false

	 for issue, _ in pairs(periodic_activities_utils.periodic_activity_issues) do
	    if script_stats.stats[issue] then
	       found = true
	       break
	    end
	 end

	 if not found then
	    goto continue
	 end
      elseif not cur_issue and not num_cur_issue then
	 goto continue
      end
   end
   
   if(sortColumn == "column_time_perc") then
      local utiliz = time_utilization(script_stats.stats)
      sort_to_key[k] = -utiliz["available"]
   elseif(sortColumn == "column_last_duration") then
      sort_to_key[k] = get_last_duration_ms(script_stats.stats)
   elseif(sortColumn == "column_periodic_activity_name") then
      sort_to_key[k] = script_stats.script
   elseif(sortColumn == "column_periodicity") then
      sort_to_key[k] = script_stats.stats.periodicity
   elseif(sortColumn == "column_status") then
      sort_to_key[k] = stats.state
   elseif(sortColumn == "column_last_start_time") then
      sort_to_key[k] = -(script_stats.stats.last_start_time or 0)
   elseif(sortColumn == "column_progress") then
      sort_to_key[k] = script_stats.stats.progress
   elseif(sortColumn == "column_timeseries_writes") then
      if script_stats.stats.timeseries and script_stats.stats.timeseries.write then
	 sort_to_key[k] = (script_stats.stats.timeseries.write.tot_calls or 0)
      else
	 sort_to_key[k] = 0
      end
   elseif(sortColumn == "column_rrd_drops") then
      if script_stats.stats.timeseries and script_stats.stats.timeseries.write then
	 sort_to_key[k] = (script_stats.stats.timeseries.write.tot_drops or 0)
      else
	 sort_to_key[k] = 0
      end
   elseif(sortColumn == "column_max_duration_secs") then
      sort_to_key[k] = script_stats.stats.max_duration_secs or 0
   elseif(sortColumn == "column_tot_not_executed") then
      sort_to_key[k] = (script_stats.stats.num_not_executed or 0)
   elseif(sortColumn == "column_tot_running_slow") then
      sort_to_key[k] = (script_stats.stats.num_is_slow or 0)
   elseif(sortColumn == "column_name") then
      sort_to_key[k] = getHumanReadableInterfaceName(getInterfaceName(script_stats.ifid))
   else
      sort_to_key[k] = script_stats.script
   end

   totalRows = totalRows + 1

   ::continue::
end

-- ################################################

local res = {}
local i = 0
local now = os.time()

for key in pairsByValues(sort_to_key, sOrder) do
   if i >= to_skip + perPage then
      break
   end

   if i >= to_skip then
      local record = {}
      local script_stats = ifaces_scripts_stats[key]

      local status = script_stats.stats.state
      local warn = {}

      for issue, issue_i18n in pairs(periodic_activities_utils.periodic_activity_issues) do
	 if script_stats.stats[issue] then
	    warn[#warn + 1] = i18n(issue_i18n.i18n_descr)
	 end
      end

      if #warn > 0 then
	 warn = string.format("<i class=\"fas fa-exclamation-triangle\" title=\"%s\" style=\"color: #f0ad4e;\"></i> ", table.concat(warn, "&#013;"))
      else
	 warn = ''
      end

      record["column_key"] = key
      record["column_ifid"] = string.format("%i", script_stats.ifid)

      if script_stats.stats.progress and script_stats.stats.progress > 0 then
	 record["column_progress"] = string.format("%i %%", script_stats.stats.progress)
      else
	 -- For now prevent a 0 progress froms being erroneusly reported for unsupported activities
	 record["column_progress"] = " "
      end

      if ts_utils.getDriverName() == "rrd" then
	 if script_stats.stats.timeseries and script_stats.stats.timeseries.write then
	    if script_stats.stats.timeseries.write.tot_calls and script_stats.stats.timeseries.write.tot_calls > 0 then
	       record["column_timeseries_writes"] = script_stats.stats.timeseries.write.tot_calls
	    end

	    if script_stats.stats.timeseries.write.tot_drops and script_stats.stats.timeseries.write.tot_drops > 0 then
	       record["column_rrd_drops"] = script_stats.stats.timeseries.write.tot_drops
	    end
	 end
      end

      record["column_max_duration_secs"] = format_utils.secondsToTime(script_stats.stats["max_duration_secs"])

      -- TODO
      record["column_work_completion"] = "90%"

      if script_stats.stats["num_not_executed"] and script_stats.stats["num_not_executed"] > 0 then
	 record["column_tot_not_executed"] = script_stats.stats["num_not_executed"]
      end

      if script_stats.stats["num_is_slow"] and script_stats.stats["num_is_slow"] > 0 then
	 record["column_tot_running_slow"] = script_stats.stats["num_is_slow"]
      end

      if script_stats.stats["last_start_time"] and script_stats.stats["last_start_time"] > 0 then
	 record["column_last_start_time"] = i18n("internals.last_start_time_ago", {time = format_utils.secondsToTime(now - script_stats.stats["last_start_time"])})
	 -- tprint({orig = script_stats.stats[k], k = k, v = record["column_"..k]})
      else
	 record["column_last_start_time"] = ''
      end

      local utiliz = time_utilization(script_stats.stats)
      record["column_time_perc"] = internals_utils.getPeriodicActivitiesFillBar(utiliz["busy"], utiliz["available"])

      record["column_last_duration"] = format_utils.secondsToTime(get_last_duration_ms(script_stats.stats) / 1000)

      record["column_status"] = status2label(status)

      record["column_name"] = string.format('<a href="'..ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid=%i&page=internals&tab=periodic_activities">%s</a>', script_stats.ifid, getHumanReadableInterfaceName(getInterfaceName(script_stats.ifid)))

      local activity_id = script_stats.script:gsub(".lua", "")
      local activity_desc = i18n("internals.activity_descriptions." .. activity_id)

      if not isEmptyString(activity_desc) then
	 activity_desc = ' <i class="fas fa-info-circle fa-sm" title="'.. activity_desc ..'"></i>'
      else
	 activity_desc = ""
      end

      -- local activity_name = string.format("<span id='%s' data-bs-toggle='popover' data-trigger='hover'  data-placement='top' title='%s' data-content='%s'>%s</span><script>$('#%s').popover('hide');$('#%s').popover({placement : 'top', trigger : 'hover'});</script>", activity_id, script_stats.script, i18n("periodic_activities_descr."..script_stats.script), script_stats.script, activity_id, activity_id)
      local activity_name = string.format("<span id='%s' title='%s'>%s</span>", activity_id, i18n("periodic_activities_descr."..script_stats.script), script_stats.script)
      record["column_periodic_activity_name"] = warn .. activity_name .. activity_desc

      record["column_periodicity"] = format_utils.secondsToTime(script_stats.stats.periodicity)

      if areInternalTimeseriesEnabled(script_stats.ifid) then
	 if script_stats.ifid == getSystemInterfaceId() then
	    record["column_chart"] = '<A HREF=\"'..ntop.getHttpPrefix()..'/lua/system_periodic_script_details.lua?periodic_script='..script_stats.script..'&ts_schema=periodic_script:duration\"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
	 else
	    record["column_chart"] = '<A HREF=\"'..ntop.getHttpPrefix()..'/lua/periodic_script_details.lua?periodic_script='..script_stats.script..'&ts_schema=periodic_script:duration&ifid='..script_stats.ifid..'\"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
	 end
      end


      res[#res + 1] = record
   end

   i = i + 1
end

-- ################################################

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = totalRows
result["data"] = res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
