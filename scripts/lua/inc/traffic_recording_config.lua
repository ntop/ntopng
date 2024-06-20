--
-- (C) 2013-23 - ntop.org
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

local record_traffic = false
local smart_record_traffic = false
local flow_export = false

-- POST check
if(_SERVER["REQUEST_METHOD"] == "POST") then
  local disk_space
  local smart_disk_space

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

  disk_space = recording_utils.default_disk_space
  if not isEmptyString(_POST["disk_space"]) then
    disk_space = tonumber(_POST["disk_space"])*1024
  end
  ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.disk_space', tostring(disk_space))

  if ntop.isEnterpriseXL() then
    if not isEmptyString(_POST["smart_record_traffic"]) then
      smart_record_traffic = true
      ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.smart_traffic_recording.instance', recording_utils.getN2diskInstanceName(master_ifid))
      ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.smart_traffic_recording.enabled', "1")
    else
      ntop.delCache('ntopng.prefs.ifid_'..master_ifid..'.smart_traffic_recording.enabled')
      ntop.delCache('ntopng.prefs.ifid_'..master_ifid..'.smart_traffic_recording.instance')
    end
    interface.updateSmartRecording()

    smart_disk_space = recording_utils.default_disk_space
    if not isEmptyString(_POST["smart_disk_space"]) then
      smart_disk_space = tonumber(_POST["smart_disk_space"])*1024
    end
    ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.smart_traffic_recording.disk_space', tostring(smart_disk_space))
  end

  if recording_utils.isSupportedZMQInterface(master_ifid) then
    local ext_ifname
    if not isEmptyString(_POST["custom_name"]) then
      -- param check
      for ifname,_ in pairs(recording_utils.getExtInterfaces(master_ifid, true)) do
        if ifname == _POST["custom_name"] then
          ext_ifname = ifname
          break
        end
      end
    end
    if ext_ifname ~= nil then
      ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.ext_ifname', ext_ifname) 
    end

    if not isEmptyString(_POST["flow_export"]) then
      flow_export = true
      ntop.setCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording_flow_export.enabled', "1")
    else
      ntop.delCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording_flow_export.enabled')
    end

  end
  
  if record_traffic then
    local config = {}
    config.max_disk_space = disk_space
    config.bpf_filter = bpf_filter
    if ntop.isEnterpriseXL() and smart_record_traffic then
      config.enable_smart_recording = true
      config.max_smart_disk_space = smart_disk_space
    end
    if recording_utils.isSupportedZMQInterface(master_ifid) and flow_export then 
      config.zmq_endpoint = recording_utils.getZMQProbeAddr(master_ifid)
      recording_utils.stop(master_ifid) -- stop before starting as the interface can be changed
    end
    if recording_utils.createConfig(master_ifid, config) then
      recording_utils.restart(master_ifid, config)
    end
  else
    recording_utils.stop(master_ifid)
  end
end

if ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.enabled') == "1" then
  record_traffic = true
  if ntop.isEnterpriseXL() and ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.smart_traffic_recording.enabled') == "1" then
    smart_record_traffic = true
  end
end

if ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording_flow_export.enabled') == "1" then
  flow_export = true
end

local bpf_filter = ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.bpf_filter')
local disk_space = ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.traffic_recording.disk_space')
local smart_disk_space = ntop.getCache('ntopng.prefs.ifid_'..master_ifid..'.smart_traffic_recording.disk_space')

local storage_info = recording_utils.storageInfo(master_ifid)
local max_space = recording_utils.recommendedSpace(master_ifid, storage_info)

-- Compute suggested max disk space
max_space = math.floor(max_space/(1024*1024*1024))*1024

if ntop.isEnterpriseXL() then
  -- Compute recommended values for storage and smart storage
  if isEmptyString(disk_space) and isEmptyString(smart_disk_space) then
    disk_space = max_space/2
    smart_disk_space = max_space/2
  elseif isEmptyString(disk_space) then
    disk_space = ternary(max_space > tonumber(smart_disk_space), max_space - tonumber(smart_disk_space), 0)
  elseif isEmptyString(smart_disk_space) then
    smart_disk_space = ternary(max_space > tonumber(disk_space),  max_space - tonumber(disk_space), 0)
  end
  smart_disk_space = tostring(math.floor(tonumber(smart_disk_space)/1024))
else
  -- Compute recommended values for storage only
  if isEmptyString(disk_space) then
    disk_space = max_space
  end
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
  local ext_interfaces = recording_utils.getExtInterfaces(master_ifid, true)

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

  print [[
      <tr>
        <th width=30%>]] print(i18n("traffic_recording.export_flows")) print [[</th>
        <td colspan=2>]]
  print(template.gen("on_off_switch.html", {
    id = "flow_export",
    checked = flow_export,
    icon = [[<i class="fas fa-hdd fa-lg"></i> ]] .. i18n("traffic_recording.export_flows")
  }))
  print [[
          <small>]] print(i18n("traffic_recording.export_flows_note"))  print[[</small>
        </td>
      </tr>
  ]]
end

-- Traffic Recording Configuration
print [[
      <tr>
        <th width=30%>]] print(i18n("traffic_recording.traffic_recording")) print [[</th>
        <td colspan=2>]]
  print(template.gen("on_off_switch.html", {
    id = "record_traffic",
    checked = record_traffic,
    icon = [[<i class="fas fa-hdd fa-lg"></i> ]] .. i18n("traffic_recording.continuous_recording")
  }))
print [[
          <small>]] print(i18n("traffic_recording.traffic_recording_note"))  print[[</small>
        </td>
      </tr>

      <tr id="tr-disk_space">
        <th>]] print(i18n("traffic_recording.disk_space")) print [[</th>
        <td colspan=2>
          <input type="number" style="width:127px;display:inline;" class="form-control" name="disk_space" placeholder="" min="1" step="1" max="]] print(ternary((max_space/1024)>1, (max_space/1024), 1)) print [[" value="]] print(disk_space) print [["></input><span style="vertical-align: middle"> GB</span><br>
<small>]] print(i18n("traffic_recording.disk_space_note") .. ternary(storage_info.if_used > 0, " "..i18n("traffic_recording.disk_space_note_in_use", {in_use=tostring(format_utils.round(storage_info.if_used/(1024*1024*1024), 2))}), "")) print[[</small>
        </td>
      </tr>

      <tr id="tr-bpf_filter">
        <th>]] print(i18n("traffic_recording.capture_filter_bpf")) print [[</th>
        <td colspan=2>
          <input style="width:300px;display:inline;" class="form-control" name="bpf_filter" placeholder="" class="form-control input-sm" data-bpf="bpf" autocomplete="off" spellcheck="false" value="]] print(bpf_filter) print [["></input><br>
<small>]] print(i18n("traffic_recording.capture_filter_bpf_note")) print[[</small>
        </td>
      </tr>

      <tr id="tr-storage_dir">
        <th>]] print(i18n("traffic_recording.storage_dir")) print [[</th>
        <td colspan=2>]] print(recording_utils.getPcapPath(master_ifid)) print [[</td>
      </tr>
]]

-- Smart Recording Configuration
if ntop.isEnterpriseXL() then
print [[
      <tr id="tr-smart_record_traffic">
        <th width=30%>]] print(i18n("traffic_recording.smart_traffic_recording")) print [[</th>
        <td colspan=2>]]
  print(template.gen("on_off_switch.html", {
    id = "smart_record_traffic",
    checked = smart_record_traffic,
    icon = [[<i class="fas fa-hdd fa-lg"></i> ]] .. i18n("traffic_recording.smart_continuous_recording")
  }))
print [[
          <small>]] print(i18n("traffic_recording.smart_traffic_recording_note"))  print[[</small>
        </td>
      </tr>

      <tr id="tr-smart_disk_space">
        <th>]] print(i18n("traffic_recording.smart_disk_space")) print [[</th>
        <td colspan=2>
          <input type="number" style="width:127px;display:inline;" class="form-control" name="smart_disk_space" placeholder="" min="1" step="1" max="]] print(ternary((max_space/1024)>1, (max_space/1024), 1)) print [[" value="]] print(smart_disk_space) print [["></input><span style="vertical-align: middle"> GB</span><br>
<small>]] print(i18n("traffic_recording.smart_disk_space_note"))  print[[</small>
        </td>
      </tr>

      <tr id="tr-smart_storage_dir">
        <th>]] print(i18n("traffic_recording.smart_storage_dir")) print [[</th>
        <td colspan=2>]] print(recording_utils.getSmartPcapPath(master_ifid)) print [[</td>
      </tr>
]]
end

-- Storage Utilization
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

$("#record_traffic").change(function(e) {
  update_record_traffic();
});

function update_record_traffic() {
  if ($("#record_traffic").is(":checked")) {
    toggle_recording_enabled_on();
]]
if ntop.isEnterpriseXL() then
print[[
    $("#tr-smart_record_traffic").css("display","table-row");
]]
end
print[[
  } else {
    toggle_recording_enabled_off();
]]
if ntop.isEnterpriseXL() then
print[[
    $("#smart_record_traffic").prop('checked', false);
    update_smart_record_traffic();
    $("#tr-smart_record_traffic").css("display","none"); 
]]
end
print[[
  }
}

function toggle_recording_enabled_on(){
  $("#tr-disk_space").css("display","table-row");
  $("#tr-bpf_filter").css("display","table-row");
  $("#tr-storage_dir").css("display","table-row");
}

function toggle_recording_enabled_off(){
  $("#tr-disk_space").css("display","none");
  $("#tr-bpf_filter").css("display","none");
  $("#tr-storage_dir").css("display","none");
}
]]

if ntop.isEnterpriseXL() then
print [[
$("#smart_record_traffic").change(function(e) {
  update_smart_record_traffic();
});

function update_smart_record_traffic() {
  if ($("#smart_record_traffic").is(":checked")) {
    toggle_smart_recording_enabled_on();
  } else {
    toggle_smart_recording_enabled_off();
  }
}

function toggle_smart_recording_enabled_on(){
  $("#tr-smart_disk_space").css("display","table-row");
  $("#tr-smart_storage_dir").css("display","table-row");
}

function toggle_smart_recording_enabled_off(){
  $("#tr-smart_disk_space").css("display","none");
  $("#tr-smart_storage_dir").css("display","none");
}
]]
end

print[[
update_record_traffic();
]]
if ntop.isEnterpriseXL() then
print [[
update_smart_record_traffic();
]]
end

print[[
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

aysHandleForm("#traffic_recording_form");
</script>
]]
