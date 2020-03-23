--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local user_scripts = require("user_scripts")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')
page_utils.manage_system_interface(page_utils.get_shared_interface_flag())

page_utils.set_active_menu_entry(page_utils.menu_entries.user_scripts)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- print[[<hr>]]

local ifid = interface.getId()
local edition = _GET["edition"] or ""

-- #######################################################

local function printUserScripts(title, scripts)
  if table.empty(scripts.modules) then
    return
  end

  print[[<h3>]] print(title) print[[</h3>
    <table class="table table-bordered table-sm table-striped">
    <tr><th class='text-left' width="30%">]] print(i18n("plugins_overview.script")) print[[</th><th width="10%">]] print(i18n("plugins_overview.availability")) print[[</th><th width="30%">]] print(i18n("plugins_overview.hooks")) print[[</th><th>]] print(i18n("plugins_overview.filters")) print[[</th></tr>]]

  for name, script in pairsByKeys(scripts.modules) do
    local available = ""
    local filters = {}
    local hooks = {}

    -- Hooks
    for hook in pairsByKeys(script.hooks) do
      if((hook == "periodicUpdate") and (script.periodic_update_seconds ~= nil)) then
        hook = string.format("%s (%us)", hook, script.periodic_update_seconds)
      end

      hooks[#hooks + 1] = hook
    end
    hooks = table.concat(hooks, ", ")

    -- Filters
    if(script.is_alert) then filters[#filters + 1] = "alerts" end
    if(script.l4_proto) then filters[#filters + 1] = "l4_proto=" .. script.l4_proto end
    if(script.l7_proto) then filters[#filters + 1] = "l7_proto=" .. script.l7_proto end
    if(script.packet_interface_only) then filters[#filters + 1] = "packet_interface" end
    if(script.three_way_handshake_ok) then filters[#filters + 1] = "3wh_completed" end
    if(script.local_only) then filters[#filters + 1] = "local_only" end
    if(script.nedge_only) then filters[#filters + 1] = "nedge=true" end
    if(script.nedge_exclude) then filters[#filters + 1] = "nedge=false" end
    filters = table.concat(filters, ", ")

    if(name == "my_custom_script") then
      goto skip
    end

    -- Availability
    if(script.edition == "enterprise") then
      available = "Enterprise"
      if((edition ~= "") and (edition ~= "enterprise")) then goto skip end
    elseif(script.edition == "pro") then
      available = "Pro"
      if((edition ~= "") and (edition ~= "pro")) then goto skip end
    else
      available = "Community"
      if((edition ~= "") and (edition ~= "community")) then goto skip end
    end

    local edit_url = user_scripts.getScriptEditorUrl(script)

    if(edit_url) then
      name = name .. ' <a href="'.. edit_url ..'" class="badge badge-secondary" style="visibility: visible">' .. i18n("host_pools.view") ..'</a>'
    end

    print(string.format([[<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>]], name, available, hooks, filters))
    ::skip::
  end

  print[[</table>]]
end

-- #######################################################

local ignore_disabled = true
local return_all = true

print[[<form class="form-inline" style="width:12em">
<select id="filter_select" name="edition" class="form-control">
<option value="" ]] print(ternary(isEmptyString(edition, "selected", ""))) print[[>All</option>
<option value="community" ]] print(ternary(edition == "community", "selected", "")) print[[>]] print(i18n("plugins_overview.edition_only", {edition="Community"})) print[[</option>
<option value="pro" ]] print(ternary(edition == "pro", "selected", "")) print[[>]] print(i18n("plugins_overview.edition_only", {edition="Pro"})) print[[</option>
<option value="enterprise" ]] print(ternary(edition == "enterprise", "selected", "")) print[[>]] print(i18n("plugins_overview.edition_only", {edition="Enterprise"})) print[[</option>
</select>
</form>
<script>
  $("#filter_select").on("change", function() {
    $("#filter_select").closest("form").submit();
  });
</script>]]

print("<br><br>")

for _, info in ipairs(user_scripts.listSubdirs()) do
  printUserScripts(info.label, user_scripts.load(ifid, user_scripts.getScriptType(info.id), info.id, {return_all = true}))
  print("<br>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

