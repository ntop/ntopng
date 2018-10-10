--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
require "prefs_utils"
local recording_utils = require "recording_utils"

sendHTTPContentTypeHeader('text/html')

local message_info = ""
local message_severity = "alert-warning"

if not haveAdminPrivileges() then
  return
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "admin"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

prefs = ntop.getPrefs()

local running_instances = false

-- ================================================================================

local menu_items = {
  {
    id="storage",
    label=i18n("traffic_recording.storage"),
    advanced=false, pro_only=false,  hidden=false, nedge_hidden=true,
    entries= {
      storage_path = {
        title       = i18n("traffic_recording.storage_path"),
        description = i18n("traffic_recording.storage_path_desc")},
      disk_space = {
        title       = i18n("traffic_recording.disk_space"),
        description = i18n("traffic_recording.disk_space_desc")},
    }
  }, {
    id="ifaces",
    label=i18n("traffic_recording.network_interfaces"),
    advanced=false,  pro_only=false,  hidden=false, nedge_hidden=true, 
    entries={
    }
  }, {
    id="license",
    label=i18n("traffic_recording.license"),
    advanced=false, pro_only=false,  hidden=false, nedge_hidden=true,
    entries={
      license = {
        title       = i18n("traffic_recording.license"),
        description = i18n("traffic_recording.license_desc"),
      },
    }
  },
}

-- ================================================================================

function printTrafficRecordingSettingsMenu(tab)
  for _, subpage in ipairs(menu_items) do
    if not subpage.hidden then
      local url = ternary(subpage.disabled, "#", ntop.getHttpPrefix() .. [[/lua/admin/traffic_recording.lua?tab=]] .. (subpage.id))
      print[[<a href="]] print(url) print[[" class="list-group-item menu-item]]
      if(tab == subpage.id) then
        print(" active")
      elseif subpage.disabled then
        print(" disabled")
      end
      print[[">]] print(subpage.label) print[[</a>]]
    end
  end
end

-- ================================================================================

function trafficRecordingSettingsGetActiveSubpage(tab)
  local subpage_active

  for _, subpage in ipairs(menu_items) do
    if subpage.id == tab then
      subpage_active = subpage
    end
  end

  -- default subpage
  if isEmptyString(tab) then
    -- Pick the first available subpage
    for _, subpage in ipairs(menu_items) do
      subpage_active = subpage
      tab = subpage.id
      break
    end
  end

  return subpage_active, tab
end

local subpage_active, tab = trafficRecordingSettingsGetActiveSubpage(_GET["tab"])

-- ================================================================================

function printStorageSettings()
  print [[
  <form method="post">
    <table class="table">
      <tr><th colspan=2 class="info">]] print(subpage_active.label) print [[</th></tr>]]

  prefsInputFieldPrefs(
    subpage_active.entries["storage_path"].title,
    subpage_active.entries["storage_path"].description,
    "ntopng.prefs.traffic_recording", "storage_path",
    recording_utils.default_storage_path, false, nil, nil, nil, {style = {width = "25em;"},
    attributes = { spellcheck = "false", maxlength = 255 }, disabled=running_instances})

  prefsInputFieldPrefs(
    subpage_active.entries["disk_space"].title.." (GB)",
    subpage_active.entries["disk_space"].description,
    "ntopng.prefs.traffic_recording", "disk_space", 
    1000, "number", nil, nil, nil, { min=1, max=1000000, disabled=running_instances })

  print [[
      <tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">]] print(i18n("save")) print [[</button></th></tr>
    </table>
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>]]
end

-- ================================================================================

function printInterfaces()
  local interfaces = recording_utils.getInterfaces()

  print [[
  <form method="post">
    <table class="table">
      <tr><th colspan=2 class="info">]] print(subpage_active.label) print [[</th></tr>]]

  for if_name,info in pairsByKeys(interfaces, asc_insensitive) do
    local if_id = if_name
    local if_desc = if_name
    local disabled = false

    if not isEmptyString(info.desc) then
      if_desc = if_desc.." - "..info.desc
    end

    if_desc = i18n("traffic_recording.enable_interface_desc", {interface = if_desc})

    if info.in_use and info.is_zc then
      disabled = true
      if_desc = i18n("traffic_recording.zc_interface_in_use")
    elseif not info.in_use and not info.is_zc then
      disabled = true
      if_desc = i18n("traffic_recording.not_a_ntopng_interface")
    end

    prefsToggleButton(subpage_active, {
      title = if_name,
      description = if_desc, 
      redis_prefix = "ntopng.prefs.traffic_recording.", field = "iface_on_"..if_id,
      content = "", default = "0", to_switch = nil, disabled = disabled
    })
  end

  print [[
      <tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">]] print(i18n("save")) print [[</button></th></tr>
    </table>
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>]]

  if _SERVER["REQUEST_METHOD"] == "POST" then
    local storage_path = ntop.getCache("ntopng.prefs.traffic_recording.storage_path")
    local disk_space = ntop.getCache("ntopng.prefs.traffic_recording.disk_space")
    local config = {}
    if not isEmptyString(storage_path) then
      config.storage_path = storage_path
    end
    if not isEmptyString(disk_space) then
      config.max_disk_space = tonumber(disk_space) * 1024
    end
    for if_name,info in pairsByKeys(interfaces, asc_insensitive) do
      local if_id = if_name
      local if_toggle = ntop.getCache("ntopng.prefs.traffic_recording.iface_on_"..if_id)

      if isEmptyString(if_toggle) or if_toggle ~= "1" then
        if recording_utils.isActive(if_name) then
          recording_utils.stop(if_name)
        end
      else
        if not recording_utils.isActive(if_name) then
          recording_utils.createConfig(if_name, config)
          recording_utils.start(if_name)
        end
      end
    end
  end

  print [[
  <script>
  function update_interfaces_status() {
    $.ajax({
      type: 'GET',
      url: ']] print (ntop.getHttpPrefix()) print [[/lua/get_traffic_recording_info.lua',
      data: { },
      success: function(content) {
        var data = jQuery.parseJSON(content);
        for (var ifname in data) {
          var btn = $('#iface_on_'+ifname+'_on_id');
          if (btn) {
            if (data[ifname].status == 'on') eval('iface_on_'+ifname+'_functionOn()');
            else eval('iface_on_'+ifname+'_functionOff()');
          }
        }
      }
    });
  }
  update_interfaces_status();
  setInterval(update_interfaces_status, 5000);
  </script>
]]
end

-- ================================================================================

function printLicense()

  print [[
  <form method="post">
    <table class="table">
      <tr><th colspan=2 class="info">]] print(subpage_active.label) print [[</th></tr>]]

  prefsInputFieldPrefs(
    subpage_active.entries["license"].title, 
    subpage_active.entries["license"].description,
    "ntopng.prefs.traffic_recording", "n2disk_license",
    "", false, nil, nil, nil, {style = {width = "25em;"},
    attributes = {spellcheck = "false", maxlength = 64 }})

  -- #####################

  print [[<tr><th colspan=2 style="text-align:right;"><button type="submit" onclick="return save_button_users();" class="btn btn-primary" style="width:115px" disabled="disabled">]] print(i18n("save")) print [[</button></th></tr>
    </table>
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>]]

  if _SERVER["REQUEST_METHOD"] == "POST" then
    local license_key = ntop.getCache("ntopng.prefs.traffic_recording.n2disk_license")
    recording_utils.set_license(license_key)
  end
end

-- ================================================================================

if tab == "storage" or tab == "license" then
  local interfaces = recording_utils.getInterfaces()
  for if_name,info in pairs(interfaces) do
    if recording_utils.isActive(if_name) then
      running_instances = true
    end
  end
end

if tab == "storage" then
  if running_instances then
    message_info = i18n("traffic_recording.running_instances_storage")
    message_severity = "alert-info"
  end
elseif tab == "license" then
  if running_instances then
    message_info = i18n("traffic_recording.running_instances_license")
    message_severity = "alert-info"
  end
end

if not isEmptyString(message_info) then
  print[[<div class="alert ]] print(message_severity) print[[" role="alert">]]
  print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
  print(message_info)
  print[[</div>]]
end

print [[<h2>]] print(i18n("traffic_recording.traffic_recording")) print[[</h2>]]

print[[
      <table class="table table-bordered">
        <col width="20%">
        <col width="80%">
        <tr>
          <td style="padding-right: 20px;">
            <div class="list-group">]]

printTrafficRecordingSettingsMenu(tab)

print[[
            </div>
          </td>
          <td colspan=2 style="padding-left: 14px;border-left-style: groove; border-width:1px; border-color: #e0e0e0;">]]

if tab == "storage" then
  printStorageSettings()
elseif tab == "license" then
  printLicense()
elseif tab == "ifaces" then
  printInterfaces()
end

print[[
          </td>
        </tr>
      </table>]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

print [[
<script>
aysHandleForm("form", {
  disable_on_dirty: '.disable-on-dirty',
});

/* Use the validator plugin to override default chrome bubble, which is displayed out of window */
$("form[id!='search-host-form']").validator({disable:true});
</script>]]

