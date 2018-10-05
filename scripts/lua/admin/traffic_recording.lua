--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
require "prefs_utils"
local template = require "template_utils"
local callback_utils = require "callback_utils"
local lists_utils = require "lists_utils"

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
end

sendHTTPContentTypeHeader('text/html')

local product = ntop.getInfo().product
local message_info = ""
local message_severity = "alert-warning"

if not haveAdminPrivileges() then
   return
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "admin"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

prefs = ntop.getPrefs()

if not isEmptyString(message_info) then
  print[[<div class="alert ]] print(message_severity) print[[" role="alert">]]
  print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
  print(message_info)
  print[[</div>]]
end

print [[<h2>]] print(i18n("traffic_recording.traffic_recording")) print[[</h2>]]

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

function printInterfaces()
  local all_interfaces = interface.getIfNames()

  print [[
  <form method="post">
    <table class="table">
      <tr><th colspan=2 class="info">]] print(subpage_active.label) print [[</th></tr>]]

  for if_id,if_name in pairsByValues(all_interfaces, asc_insensitive) do
    if _POST["iface_on_"..if_id] ~= nil then
      -- tprint(_POST["iface_on_"..if_id])
    end
  end

  for if_id,if_name in pairsByValues(all_interfaces, asc_insensitive) do
    prefsToggleButton(subpage_active, {
      title = if_name,
      description = i18n("traffic_recording.enable_interface_desc", {interface = if_name}),
      redis_key = "ntopng.prefs.traffic_recording", field = "iface_on_"..if_id,
      content = "", default = "0", to_switch = nil,
    })
  end

  print [[
      <tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">]] print(i18n("save")) print [[</button></th></tr>
    </table>
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>]]
end

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
    "/storage", false, nil, nil, nil, {style = {width = "25em;"},
    attributes = { spellcheck = "false", maxlength = 255 }})

  prefsInputFieldPrefs(
    subpage_active.entries["disk_space"].title.." (GB)",
    subpage_active.entries["disk_space"].description,
    "ntopng.prefs.traffic_recording", "disk_space", 
    1000, "number", nil, nil, nil, { min=1, max=1000000 })

  print [[
      <tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">]] print(i18n("save")) print [[</button></th></tr>
    </table>
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>]]
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
end

-- ================================================================================

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

-- if _SERVER["REQUEST_METHOD"] == "POST" then
--  -- Something has changed
--  ntop.reloadPreferences()
-- end

