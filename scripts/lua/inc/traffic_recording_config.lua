--
-- (C) 2013-21 - ntop.org
--

require "lua_utils"
local graph_utils = require "graph_utils"
local recording_utils = require "recording_utils"
local template = require "template_utils"
local format_utils = require "format_utils"
local ifstats = interface.getStats()
local info = ntop.getInfo()

if((not isAdministrator()) or (not recording_utils.isAvailable())) then
  return
end

-- POST check
if(_SERVER["REQUEST_METHOD"] == "POST") then
  local record_traffic = false
  if not isEmptyString(_POST["record_traffic"]) then
    record_traffic = true
    ntop.setCache('ntopng.prefs.ifid_'..ifstats.id..'.traffic_recording.enabled', "1")
  else
    ntop.delCache('ntopng.prefs.ifid_'..ifstats.id..'.traffic_recording.enabled')
  end
  

  local disk_space = recording_utils.default_disk_space
  if not isEmptyString(_POST["disk_space"]) then
    disk_space = tonumber(_POST["disk_space"])*1024
  end
  ntop.setCache('ntopng.prefs.ifid_'..ifstats.id..'.traffic_recording.disk_space', tostring(disk_space))

  if recording_utils.isSupportedZMQInterface(ifid) then
    local ext_ifname
    if not isEmptyString(_POST["custom_name"]) then
      -- param check
      for ifname,_ in pairs(recording_utils.getExtInterfaces(ifid)) do
        if ifname == _POST["custom_name"] then
          ext_ifname = ifname
          break
        end
      end
    end
    if ext_ifname ~= nil then
      ntop.setCache('ntopng.prefs.ifid_'..ifstats.id..'.traffic_recording.ext_ifname', ext_ifname) 
    end
  end
  
  if record_traffic then
    local config = {}
    config.max_disk_space = disk_space
    if recording_utils.isSupportedZMQInterface(ifid) then 
      config.zmq_endpoint = recording_utils.getZMQProbeAddr(ifid)
      recording_utils.stop(ifstats.id) -- stop before starting as the interface can be changed
    end
    if recording_utils.createConfig(ifstats.id, config) then
      recording_utils.restart(ifstats.id)
    end
  else
    recording_utils.stop(ifstats.id)
  end
end

local record_traffic = false
if ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.enabled') == "1" then
  record_traffic = true
end

local disk_space = ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.disk_space')
local storage_info = recording_utils.storageInfo(ifid)
local max_space = recording_utils.recommendedSpace(ifid, storage_info)

max_space = math.floor(max_space/(1024*1024*1024))*1024
if isEmptyString(disk_space) then
  disk_space = max_space
end
disk_space = tostring(math.floor(tonumber(disk_space)/1024))

print("<h2>"..i18n("traffic_recording.traffic_recording_settings").."</h2><br>")

print [[
  <form id="traffic_recording_form" class="form-inline" method="post">
    <table class="table table-striped table-bordered">
      <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
]]

if recording_utils.isSupportedZMQInterface(ifid) then
  local ext_ifname = ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.ext_ifname')
  local ext_interfaces = recording_utils.getExtInterfaces(ifid)

  if isEmptyString(ext_ifname) then
    for ifname,_ in pairs(ext_interfaces) do
      ext_ifname = ifname
      break
    end
  end
  print [[
      <tr>
        <th width=30%>]] print(i18n("traffic_recording.ext_interface")) print [[</th>
        <td colspan=2>
          <select class="form-select" name="custom_name" value="]] print(ext_ifname) print [[">
  ]]
  for ifname,info in pairsByKeys(ext_interfaces, asc) do
    print("<option value=\""..ifname.."\" "..ternary(ifname == ext_ifname, "selected", "")..">"..info.ifdesc.."</option>")
  end
  print [[
      </select>
        </td>
      </tr>
  ]]
end

print [[
      <tr>
        <th width=30%>]] print(i18n("traffic_recording.traffic_recording")) print [[</th>
        <td colspan=2>]]

  print(template.gen("on_off_switch.html", {
    id = "record_traffic",
    checked = record_traffic,
    icon = [[<i class="fas fa-hdd fa-lg"></i> ]] .. ternary(recording_utils.isSupportedZMQInterface(ifid), i18n("traffic_recording.continuous_recording_and_flows"), i18n("traffic_recording.continuous_recording"))
  }))

print [[
    </td>
      </tr>

      <tr>
        <th>]] print(i18n("traffic_recording.disk_space")) print [[</th>
        <td colspan=2>
          <input type="number" style="width:127px;display:inline;" class="form-control" name="disk_space" placeholder="" min="1" step="1" max="]] print(max_space/1024) print [[" value="]] print(disk_space) print [["></input><span style="vertical-align: middle"> GB</span><br>
<small>]] print(i18n("traffic_recording.disk_space_note") .. ternary(storage_info.if_used > 0, " "..i18n("traffic_recording.disk_space_note_in_use", {in_use=tostring(format_utils.round(storage_info.if_used/(1024*1024*1024), 2))}), "")) print[[</small>
        </td>
      </tr>

      <tr>
        <th>]] print(i18n("traffic_recording.storage_dir")) print [[</th>
        <td colspan=2>]] print(recording_utils.getPcapPath(ifid)) print [[</td>
      </tr>
]]

print [[
      <tr>
        <th>]] print(i18n("traffic_recording.storage_utilization")) print [[</th>
        <td>
          <span style="float: left">
]]

local system_used = storage_info.total - storage_info.avail - storage_info.if_used - storage_info.extraction_used

print(graph_utils.stackedProgressBars(storage_info.total, {
  {
    title = i18n("system"),
    value = system_used,
    class = "info",
  }, {
    title = i18n("traffic_recording.packet_dumps"),
    value = storage_info.if_used,
    class = "primary",
  }, {
    title = i18n("traffic_recording.extracted_packets"),
    value = storage_info.extraction_used,
    class = "warning",
  }
}, i18n("free"), bytesToSize))

print[[
          </span>
        </td>
      </tr>
]]

print [[
    </table>
    <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
  </form>
  <span>]]

print(i18n("notes"))
print[[
  <ul>
      <li>]] print(i18n("traffic_recording.global_settings_note", {url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=recording"})) print[[</li>
      <li>]] print(i18n("traffic_recording.storage_directory_config", {option="--pcap-dir", product=info.product})) print[[</li>
    </ul>
  </span>

  <script>
    aysHandleForm("#traffic_recording_form");
  </script>
]]
