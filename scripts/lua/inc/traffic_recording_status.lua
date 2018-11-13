--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()

require "lua_utils"
local recording_utils = require "recording_utils"

if((not isAdministrator()) or (not recording_utils.isAvailable())) then
  return
end

local ifstats = interface.getStats()
local storage_info = recording_utils.storageInfo(ifstats.id)
local enabled = false
local running = false
local restart_req = false
local print_restart_button = false

if _POST["action"] ~= nil and _POST["action"] == "restart" then
  restart_req = true
end

if recording_utils.isEnabled(ifstats.id) then
  enabled = true
  if recording_utils.isActive(ifstats.id) then
    running = true
  else -- failure
    if restart_req then
      recording_utils.restart(ifstats.id)
    end
  end
end

print("<h2>"..i18n("traffic_recording.traffic_recording_status"))
if enabled and not running and not restart_req then
  print[[<form style="display:inline" id="restart_rec_form" method="post">
    <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
    <input type="hidden" name="action" value="restart" />
</form>]]
  print(" <small><a href='#' onclick='$(\"#restart_rec_form\").submit(); return false;' title='' data-original-title='"..i18n("traffic_recording.restart_service").."'><i class='fa fa-repeat fa-sm' aria-hidden='true' data-original-title='' title=''></i></a></small>")
end
print("</h2>")

print("<table class=\"table table-bordered table-striped\">\n")

print("<tr><th nowrap>"..i18n("interface").."</th><td>"..ifstats.name.."</td></tr>\n")

print("<tr><th nowrap>"..i18n("status").."</th><td>")
if running then
  print(i18n("traffic_recording.recording"))
elseif enabled then
  print("<span style='float: left'>"..i18n("traffic_recording.failure")..". "..i18n("traffic_recording.failure_note").."</span>")
else
  print(i18n("traffic_recording.disabled"))
end

print("</td></tr>\n")

if running then
  local stats = recording_utils.stats(ifstats.id)

  if stats['Duration'] ~= nil then
    local u = split(stats['Duration'], ':');
    local uptime = tonumber(u[1])*24*60*60+tonumber(u[2])*60*60+tonumber(u[3])*60+u[4]
    local start_time = os.time()-uptime
    print("<tr><th nowrap>"..i18n("traffic_recording.active_since").."</th><td>"..formatEpoch(start_time).."</td></tr>\n")
  end

  if stats['FirstDumpedEpoch'] ~= nil then
    local first_epoch = tonumber(stats['FirstDumpedEpoch'])
    local last_epoch = tonumber(stats['LastDumpedEpoch'])
    print("<tr><th nowrap>"..i18n("traffic_recording.dump_window").."</th><td>")
    if first_epoch > 0 and last_epoch > 0 then
      print(formatEpoch(first_epoch).." - "..formatEpoch(last_epoch))
    else
      print(i18n("traffic_recording.no_file"))
    end
    print("</td></tr>\n")
  end

  if stats['Bytes'] ~= nil and stats['Packets'] ~= nil then
    print("<tr><th nowrap>"..i18n("if_stats_overview.received_traffic").."</th><td>"..bytesToSize(stats['Bytes']).." ["..formatValue(stats['Packets']).." "..i18n("pkts").."]</td></tr>\n")
  end

  if stats['Dropped'] ~= nil then
    print("<tr><th nowrap>"..i18n("if_stats_overview.dropped_packets").."</th><td>"..stats['Dropped'].." "..i18n("pkts").."</td></tr>\n")
  end

  if stats['BytesOnDisk'] ~= nil then
    print("<tr><th nowrap>"..i18n("traffic_recording.traffic_on_disk").."</th><td>"..bytesToSize(stats['BytesOnDisk']).."</td></tr>\n")
  end
end

print("<tr><th nowrap>"..i18n("traffic_recording.storage_dir").."</th><td>"..recording_utils.getPcapPath(ifstats.id).."</td></tr>\n")

print("<tr><th nowrap>"..i18n("traffic_recording.storage_utilization").."</th><td>"..tostring(math.floor(storage_info.used/1024)).." GB / "..tostring(math.floor(storage_info.total/1024)).." GB ("..storage_info.used_perc..")</td></tr>\n")

print("<tr><th nowrap>"..i18n("about.last_log").."</th><td><code>\n")

local log = recording_utils.log(ifstats.id, 32)
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
