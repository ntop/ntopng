--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local recording_utils = require "recording_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.select(ifname)

if recording_utils.isAvailable then
  local ifstats = interface.getStats()
  local storage_info = recording_utils.storageInfo()

  print("<hr /><h2>"..i18n("traffic_recording.traffic_recording_status").."</h2>")

  print("<table class=\"table table-bordered table-striped\">\n")

  print("<tr><th nowrap>"..i18n("interface").."</th><td>"..ifstats.name.."</td></tr>\n")

  local stats = recording_utils.stats(ifstats.name)

  if stats['Bytes'] ~= nil and stats['Packets'] ~= nil then
    print("<tr><th nowrap>"..i18n("if_stats_overview.received_traffic").."</th><td>"..bytesToSize(stats['Bytes']).." ["..formatValue(stats['Packets']).." "..i18n("pkts").."]</td></tr>\n")
  end

  if stats['Dropped'] ~= nil then
    print("<tr><th nowrap>"..i18n("if_stats_overview.dropped_packets").."</th><td>"..stats['Dropped'].." "..i18n("pkts").."</td></tr>\n")
  end

  if stats['BytesOnDisk'] ~= nil then
    print("<tr><th nowrap>"..i18n("traffic_recording.traffic_on_disk").."</th><td>"..bytesToSize(stats['BytesOnDisk']).."</td></tr>\n")
  end

  print("<tr><th nowrap>"..i18n("traffic_recording.storage_dir").."</th><td>"..dirs.pcapdir.."</td></tr>\n")

  print("<tr><th nowrap>"..i18n("traffic_recording.storage_utilization").."</th><td>"..tostring(math.floor(storage_info.used/1024)).."GB / "..tostring(math.floor(storage_info.total/1024)).."GB ("..storage_info.used_perc..")</td></tr>\n")

  print("<tr><th nowrap>"..i18n("about.last_log").."</th><td><code>\n")

  local log = recording_utils.log(ifstats.name, 32)
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
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
