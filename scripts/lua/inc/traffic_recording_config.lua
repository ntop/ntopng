--
-- (C) 2013-18 - ntop.org
--

require "lua_utils"
local recording_utils = require "recording_utils"
local format_utils = require "format_utils"
local ifstats = interface.getStats()

if((not isAdministrator()) or (not recording_utils.isAvailable())) then
  return
end

-- POST check
if(_SERVER["REQUEST_METHOD"] == "POST") then
  local record_traffic = false
  if not isEmptyString(_POST["record_traffic"]) then
    record_traffic = true
  end
  ntop.setCache('ntopng.prefs.ifid_'..ifstats.id..'.traffic_recording.enabled', ternary(record_traffic, "true", "false"))

  local disk_space = recording_utils.default_disk_space
  if not isEmptyString(_POST["disk_space"]) then
    disk_space = tonumber(_POST["disk_space"])*1024
  end
  ntop.setCache('ntopng.prefs.ifid_'..ifstats.id..'.traffic_recording.disk_space', tostring(disk_space))

  if recording_utils.isSupportedZMQInterface(ifid) then
    local ext_ifname
    if not isEmptyString(_POST["custom_name"]) then
      -- param check
      for ifname,_ in pairs(ext_interfaces) do
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

local record_traffic = ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.enabled')
local disk_space = ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.disk_space')
local storage_info = recording_utils.storageInfo(ifid)
local max_space = recording_utils.recommendedSpace(storage_info)
if record_traffic == "true" then
  record_traffic_checked = 'checked="checked"'
  record_traffic_value = "false" -- Opposite
else
  record_traffic_checked = ""
  record_traffic_value = "true" -- Opposite
end

max_space = math.floor(max_space/1024)*1024
if isEmptyString(disk_space) then
  disk_space = max_space
end
disk_space = tostring(math.floor(tonumber(disk_space)/1024))

print [[
  <form id="traffic_recording_form" class="form-inline" method="post">
    <table class="table table-striped table-bordered">
      <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
]]

if recording_utils.isSupportedZMQInterface(ifid) then
  local ext_ifname = ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.ext_ifname')
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
          <select class="form-control" name="custom_name" value="]] print(ext_ifname) print [[">
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
        <td colspan=2>
    <input name="record_traffic" type="checkbox" value="1" ]] print (record_traffic_checked) print [[> <i class="fa fa-hdd-o fa-lg"></i> ]] print(ternary(recording_utils.isSupportedZMQInterface(ifid), i18n("traffic_recording.continuous_recording_and_flows"), i18n("traffic_recording.continuous_recording"))) print [[</input>
        </td>
      </tr>

      <tr>
        <th>]] print(i18n("traffic_recording.disk_space")) print [[</th>
        <td colspan=2>
          <input type="number" style="width:127px;display:inline;" class="form-control" name="disk_space" placeholder="" min="1" step="1" max="]] print(max_space/1024) print [[" value="]] print(disk_space) print [["></input><span style="vertical-align: middle"> GB</span><br>
<small>]] print(i18n("traffic_recording.disk_space_note") .. ternary(storage_info.if_used > 0, " "..i18n("traffic_recording.disk_space_note_in_use", {in_use=tostring(format_utils.round(storage_info.if_used/1024, 2))}), "")) print[[</small>
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
          <span style="width: 60%; float: left;">
          <div class='progress'><div class='progress-bar progress-bar-warning' style='width: ]] print(storage_info.used_perc) print [[;'></div></div></span>
        <span style="width: 40%; margin-left: 15px;"> ]] print(tostring(math.floor(storage_info.used/1024))) print [[ GB / ]] print(tostring(math.floor(storage_info.total/1024))) print [[ GB (]] print(storage_info.used_perc) print [[)</span>
        </td>
      </tr>
]]

print [[
    </table>
    <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
  </form>
  <script>
    aysHandleForm("#traffic_recording_form");
  </script>
]]
