--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local plugins_utils = require("plugins_utils")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.plugins)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- print[[<hr>]]

local ifid = interface.getId()
local edition = _GET["edition"] or ""

-- #######################################################

if(isAdministrator() and (_POST["action"] == "reload")) then
  plugins_utils.loadPlugins()
end

-- #######################################################

local function printPlugins()
  local plugins = plugins_utils.getLoadedPlugins()

  print[[<table class="table table-bordered table-sm table-striped">
    <tr><th width="20%">]] print(i18n("plugins_overview.plugin")) print[[</th><th>]] print(i18n("show_alerts.alert_description")) print[[</th><th>]] print(i18n("plugins_overview.source_location")) print[[</th><th width="10%">]] print(i18n("availability")) print[[</th></tr>]]

  for _, plugin in pairsByField(plugins, "title", asc) do
    local available = ""

    -- Availability
    if(plugin.edition == "enterprise_m") then
      available = "Enterprise M"
      if((edition ~= "") and (edition ~= "enterprise_m")) then goto skip end
    elseif(plugin.edition == "enterprise_l") then
      available = "Enterprise L"
      if((edition ~= "") and (edition ~= "enterprise_l")) then goto skip end
    elseif(plugin.edition == "pro") then
      available = "Pro"
      if((edition ~= "") and (edition ~= "pro")) then goto skip end
    else
      available = "Community"
      if((edition ~= "") and (edition ~= "community")) then goto skip end
    end

    print(string.format([[<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>]], plugin.title, plugin.description, plugin.path, available))
    ::skip::
  end

  print[[</table>]]
end

-- #######################################################

print([[
<div class="row">
  <div class="col-md-12">]])
page_utils.print_page_title(i18n("plugins_overview.loaded_plugins"))
print([[
  </div>
</div>
]])

print[[<div class="row mb-3">
<div class="col col-md-1">
  <form class="form-inline" style="width:12em">
    <select id="filter_select" name="edition" class="form-select">
    <option value="" ]] print(ternary(isEmptyString(edition, "selected", ""))) print[[>]] print(i18n("all")) print[[</option>
    <option value="community" ]] print(ternary(edition == "community", "selected", "")) print[[>]] print(i18n("plugins_overview.edition_only", {edition="Community"})) print[[</option>
    <option value="pro" ]] print(ternary(edition == "pro", "selected", "")) print[[>]] print(i18n("plugins_overview.edition_only", {edition="Pro"})) print[[</option>
    <option value="enterprise_m" ]] print(ternary(edition == "enterprise_m", "selected", "")) print[[>]] print(i18n("plugins_overview.edition_only", {edition="Enterprise M"})) print[[</option>
    <option value="enterprise_l" ]] print(ternary(edition == "enterprise_l", "selected", "")) print[[>]] print(i18n("plugins_overview.edition_only", {edition="Enterprise L"})) print[[</option>
    </select>
  </form>
</div>]]

if isAdministrator() then
  print[[<div class="col col-md--11 text-end">
  <form class="form-inline" method="POST">
    <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[">
    <input name="action" type="hidden" value="reload" />
    <button class="btn btn-primary" style="margin-left:auto" type="submit">]] print(i18n("plugins_overview.reload_plugins")) print[[</button>
  </form>
</div>
]]
end
print("</div>")

printPlugins()

print([[
<script type="text/javascript">
  $("#filter_select").on("change", function() {
    $("#filter_select").closest("form").submit();
  });
</script>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

