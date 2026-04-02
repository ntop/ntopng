--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"
local periodic_activities_utils = require "periodic_activities_utils"
local ts_utils = require "ts_utils_core"

-- ################################################

local iffilter   = _GET["iffilter"]
local filter_script = _GET["periodic_script"]
local filter_issue  = _GET["periodic_script_issue"]

local now = os.time()
local ts_driver = ts_utils.getDriverName()

-- ################################################

local available_interfaces = interface.getIfNames()
available_interfaces[getSystemInterfaceId()] = getSystemInterfaceName()

local data = {}

for _, iface in pairsByKeys(available_interfaces, asc) do
   if not isEmptyString(iffilter) and iffilter ~= tostring(getInterfaceId(iface)) then
      goto continue
   end

   interface.select(iface)
   local ifid = getInterfaceId(iface)
   local scripts_stats = interface.getPeriodicActivitiesStats()

   for script, stats in pairsByKeys(scripts_stats, asc) do
      if not isEmptyString(filter_script) and script ~= filter_script then goto next_script end

      local state = stats.state or "sleeping"

      -- Compute live or recorded last duration
      local last_duration_ms = 0
      if state == "running" then
         if stats.last_start_time and stats.last_start_time > 0 and now >= stats.last_start_time then
            last_duration_ms = (now - stats.last_start_time) * 1000
         end
      else
         if stats.duration and stats.duration.last_duration_ms and stats.duration.last_duration_ms > 0 then
            last_duration_ms = stats.duration.last_duration_ms
         end
      end

      local max_dur_ms = (stats.max_duration_secs or 1) * 1000
      local busy_pct = 0
      if max_dur_ms > 0 then
         busy_pct = round(last_duration_ms / max_dur_ms * 100, 2)
      end

      -- Collect issue keys
      local issues = {}
      for issue, _ in pairs(periodic_activities_utils.periodic_activity_issues) do
         if stats[issue] then
            issues[#issues + 1] = issue
         end
      end

      -- Apply issue filter
      if not isEmptyString(filter_issue) then
         local has_issue = false
         if filter_issue == "any_issue" then
            has_issue = (#issues > 0)
         else
            for _, v in ipairs(issues) do
               if v == filter_issue then has_issue = true; break end
            end
         end
         if not has_issue then goto next_script end
      end

      -- Timeseries info
      local ts_writes, ts_drops
      if stats.timeseries and stats.timeseries.write then
         ts_writes = stats.timeseries.write.tot_calls or 0
         ts_drops  = stats.timeseries.write.tot_drops or 0
      end

      -- SNMP MIB counters
      local snmp_fat_mibs, snmp_other_mibs
      if stats.snmp and stats.snmp.calls then
         local c = stats.snmp.calls
         snmp_fat_mibs   = (c.fat_mibs_v1_v2c or 0) + (c.fat_mibs_v3 or 0)
         snmp_other_mibs = (c.other_mibs_v1_v2c or 0) + (c.other_mibs_v3 or 0)
      end

      -- Last start formatted
      local last_start_ago = ""
      if stats.last_start_time and stats.last_start_time > 0 then
         last_start_ago = format_utils.secondsToTime(now - stats.last_start_time)
      end

      local progress
      if stats.progress and stats.progress > 0 then
         progress = stats.progress
      end

      data[#data + 1] = {
         iface_name         = getHumanReadableInterfaceName(getInterfaceName(ifid)),
         ifid               = ifid,
         script             = script,
         state              = state,
         periodicity        = stats.periodicity or 0,
         periodicity_label  = format_utils.secondsToTime(stats.periodicity or 0),
         max_duration_secs  = stats.max_duration_secs or 0,
         max_duration_label = format_utils.secondsToTime(stats.max_duration_secs or 0),
         last_start_time    = stats.last_start_time or 0,
         last_start_ago     = last_start_ago,
         last_duration_ms   = last_duration_ms,
         last_duration_label = format_utils.secondsToTime(last_duration_ms / 1000),
         busy_pct           = busy_pct,
         available_pct      = math.max(0, 100 - busy_pct),
         progress           = progress,
         tot_not_executed   = stats.num_not_executed or 0,
         tot_running_slow   = stats.num_is_slow or 0,
         ts_writes          = ts_writes,
         ts_drops           = ts_drops,
         snmp_fat_mibs      = snmp_fat_mibs,
         snmp_other_mibs    = snmp_other_mibs,
         issues             = issues,
      }

      ::next_script::
   end

   ::continue::
end

rest_utils.extended_answer(rest_utils.consts.success.ok, data, {
   recordsTotal    = #data,
   recordsFiltered = #data,
   ts_driver       = ts_driver,
})
