--
-- (C) 2013-22 - ntop.org
--

require "lua_utils"
local graph_utils = require "graph_utils"
local recording_utils = require "recording_utils"
local template = require "template_utils"
local format_utils = require "format_utils"
local master_ifid = interface.getMasterInterfaceId()
local info = ntop.getInfo()

if((not isAdministrator()) or (not recording_utils.isAvailable())) then
  return
end

-- POST check
if(_SERVER["REQUEST_METHOD"] == "POST") then
  local record_traffic = false
  if not isEmptyString(_POST["record_traffic"]) then
    record_traffic = true
    ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.enabled', "1")
  else
    ntop.delCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.enabled')
  end
 
  local bpf_filter = ''
  if not isEmptyString(_POST["bpf_filter"]) then
    bpf_filter = _POST["bpf_filter"]
  end
  ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.bpf_filter', bpf_filter)

  local disk_space = recording_utils.default_disk_space
  if not isEmptyString(_POST["disk_space"]) then
    disk_space = tonumber(_POST["disk_space"])*1024
  end
  ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.disk_space', tostring(disk_space))

  if recording_utils.isSupportedZMQInterface(master_ifid) then
    local ext_ifname
    if not isEmptyString(_POST["custom_name"]) then
      -- param check
      for ifname,_ in pairs(recording_utils.getExtInterfaces(master_ifid)) do
        if ifname == _POST["custom_name"] then
          ext_ifname = ifname
          break
        end
      end
    end
    if ext_ifname ~= nil then
      ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.ext_ifname', ext_ifname) 
    end
  end
  
  if record_traffic then
    local config = {}
    config.max_disk_space = disk_space
    config.bpf_filter = bpf_filter
    if recording_utils.isSupportedZMQInterface(master_ifid) then 
      config.zmq_endpoint = recording_utils.getZMQProbeAddr(master_ifid)
      recording_utils.stop(master_ifid) -- stop before starting as the interface can be changed
    end
    if recording_utils.createConfig(master_ifid, config) then
      recording_utils.restart(master_ifid)
    end
  else
    recording_utils.stop(master_ifid)
  end
end

local record_traffic = false
if ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.enabled') == "1" then
  record_traffic = true
end

local bpf_filter = ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.bpf_filter')

local disk_space = ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.disk_space')
local storage_info = recording_utils.storageInfo(master_ifid)
local max_space = recording_utils.recommendedSpace(master_ifid, storage_info)

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

if recording_utils.isSupportedZMQInterface(master_ifid) then
  local ext_ifname = ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.ext_ifname')
  local ext_interfaces = recording_utils.getExtInterfaces(master_ifid)

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
    icon = [[<i class="fas fa-hdd fa-lg"></i> ]] .. ternary(recording_utils.isSupportedZMQInterface(master_ifid), i18n("traffic_recording.continuous_recording_and_flows"), i18n("traffic_recording.continuous_recording"))
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
        <th>]] print(i18n("traffic_recording.capture_filter_bpf")) print [[</th>
        <td colspan=2>
          <input style="width:300px;display:inline;" class="form-control" name="bpf_filter" placeholder="" class="form-control input-sm" data-bpf="bpf" autocomplete="off" spellcheck="false" value="]] print(bpf_filter) print [["></input><br>
<small>]] print(i18n("traffic_recording.capture_filter_bpf_note")) print[[</small>
        </td>
      </tr>

      <tr>
        <th>]] print(i18n("traffic_recording.storage_dir")) print [[</th>
        <td colspan=2>]] print(recording_utils.getPcapPath(master_ifid)) print [[</td>
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
    <button id="traffic_recording_submit" class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
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
  $("#traffic_recording_form")
    .validator({ custom: { bpf: bpfValidator }, errors: { bpf: 'Invalid filter' } })
    .on('validate.bs.validator', function(e) {
      var submitbtn = $("#traffic_recording_submit");
      var invalid = $(".has-error", $(this)).length > 0;
      if (invalid) {
        submitbtn.addClass("disabled");
      } else {
        submitbtn.removeClass("disabled");
      }
    });
  </script>

  <script>
    aysHandleForm("#traffic_recording_form");
  </script>
]]
