--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()

require "lua_utils"
local recording_utils = require "recording_utils"

if((not isAdministrator()) or (not recording_utils.isAvailable())) then
  return
end

local ifstats = interface.getStats()
local master_ifid = interface.getMasterInterfaceId()
local enabled = false
local running = false
local restart_req = false
local custom_provider = (recording_utils.getCurrentTrafficRecordingProvider(master_ifid) ~= "ntopng")
local extraction_checks_ok, extraction_checks_msg

if _POST["action"] ~= nil and _POST["action"] == "restart" then
  restart_req = true
end

if custom_provider then
   enabled = true
   running = recording_utils.isActive(master_ifid)
   extraction_checks_ok, extraction_checks_msg = recording_utils.checkExtraction(master_ifid)

elseif recording_utils.isEnabled(master_ifid) then
  enabled = true
  if recording_utils.isActive(master_ifid) then
    running = true
  else -- failure
    if restart_req then
      recording_utils.restart(master_ifid)
    end
  end
end

print("<h2>"..i18n("traffic_recording.traffic_recording_status"))
print(" <small><a href='#' onclick='location.reload(); return false;' title='' data-original-title='"..i18n("refresh").."'><i class='fas fa-sync fa-sm' aria-hidden='true' data-original-title='' title=''></i></a></small>")
print("</h2><br>")

print("<table class=\"table table-bordered table-striped\">\n")

print("<tr><th nowrap>"..i18n("interface").."</th><td>"..ifstats.name.."</td></tr>\n")

print("<tr><th nowrap>"..i18n("status").."</th><td>")

if running then
  print(i18n("traffic_recording.recording"))
elseif enabled then
  print("<span style='float: left'>"..i18n("traffic_recording.failure")..". "..i18n("traffic_recording.failure_note").."</span>")

  if not custom_provider then
     print[[<form style="display:inline" id="restart_rec_form" method="post">
    <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
    <input type="hidden" name="action" value="restart" />
</form>]]
     print(" <small><a href='#' onclick='$(\"#restart_rec_form\").submit(); return false;' title='' data-original-title='"..i18n("traffic_recording.restart_service").."'></small>&nbsp;<i class='fas fa-repeat fa-lg' aria-hidden='true' data-original-title='' title=''></i></a>")
  end
else
  print(i18n("traffic_recording.disabled"))
end

print("</td></tr>\n")

-- Traffic Recording stats

local stats = recording_utils.stats(master_ifid)

local first_epoch = stats['FirstDumpedEpoch']
local last_epoch = stats['LastDumpedEpoch']
local start_time = stats['StartEpoch']

if first_epoch ~= nil then
   print("<tr><th width='15%' nowrap>"..i18n("traffic_recording.dump_window").."</th><td>")
   if first_epoch ~= nil and last_epoch ~= nil and 
      first_epoch > 0 and last_epoch > 0 then
      print(formatEpoch(first_epoch).." - "..formatEpoch(last_epoch))
   else
      print(i18n("traffic_recording.no_file"))
   end
   print("</td></tr>\n")
end

if start_time ~= nil then
   print("<tr><th nowrap>"..i18n("traffic_recording.active_since").."</th><td>"..formatEpoch(start_time))
   if (start_time ~= nil) and (first_epoch ~= nil) and (first_epoch > 0) and (start_time > (first_epoch + 10)) then
      print(' - <i class="fas fa-exclamation-triangle"></i> ')
      print(i18n("traffic_recording.missing_data_msg"))
   end
   print("</td></tr>\n")
end

if stats['Bytes'] ~= nil and stats['Packets'] ~= nil then
   print("<tr><th nowrap>"..i18n("if_stats_overview.received_traffic").."</th><td>"..bytesToSize(stats['Bytes']).." ["..formatValue(stats['Packets']).." "..i18n("pkts").."]</td></tr>\n")
end

if stats['Dropped'] ~= nil then
   print("<tr><th nowrap>"..i18n("if_stats_overview.dropped_packets").."</th><td>"..stats['Dropped'].." "..i18n("pkts").."</td></tr>\n")
end

-- Smart Recording stats

stats = recording_utils.smartStats(master_ifid)

first_epoch = stats['FirstDumpedEpoch']
last_epoch = stats['LastDumpedEpoch']

if first_epoch ~= nil then
   print("<tr><th width='15%' nowrap>"..i18n("traffic_recording.smart_window").."</th><td>")
   if first_epoch ~= nil and last_epoch ~= nil and 
      first_epoch > 0 and last_epoch > 0 then
      print(formatEpoch(first_epoch).." - "..formatEpoch(last_epoch))
   else
      print(i18n("traffic_recording.no_file"))
   end
   print("</td></tr>\n")
end

-- Custom Provider

if custom_provider and running then
   local warn = ''

   if not extraction_checks_ok then
      warn = '<i class="fas fa-exclamation-triangle"></i> '
   end

   print("<tr><th nowrap>"..i18n("traffic_recording.traffic_extractions").."</th><td>"..warn..extraction_checks_msg.."</td></tr>\n")
end

-- Logs

print("<tr><th nowrap>"..i18n("about.last_log").."</th><td><code>\n")

local log = recording_utils.log(master_ifid, 32)
local logs = split(log, "\n")
for i = 1, #logs do
  local row = split(logs[i], "]: ")
  if row[2] ~= nil then
    print(row[2].."<br>\n")
  else
    print(row[1].."<br>\n") 
  end
end

print("</code></td></tr>\n")

print("</table>\n")
