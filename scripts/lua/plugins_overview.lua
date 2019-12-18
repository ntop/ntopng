--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local plugins_utils = require("plugins_utils")
local user_scripts = require("user_scripts")
local page_utils = require("page_utils")
active_page = "about"

sendHTTPContentTypeHeader('text/html')
page_utils.print_header(i18n("plugins"))

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- print[[<hr>]]

local ifid = interface.getId()
local edition = _GET["edition"] or ""

-- #######################################################

if(isAdministrator() and (_POST["action"] == "reload")) then
  local plugins_utils = require("plugins_utils")

  plugins_utils.loadPlugins()
  user_scripts.loadDefaultConfig()
end

-- #######################################################

local function printPlugins()
  local plugins = plugins_utils.getLoadedPlugins()

  print[[<h3>Loaded Plugins</h3><br>
  <table class="table table-bordered table-sm table-striped">
    <tr><th width="20%">Plugin</th><th>Description</th><th class="text-center">Version</th><th>Source Location</th><th width="10%">Availability</th></tr>]]

  for _, plugin in pairsByField(plugins, "title", asc) do
    local available = ""

    -- Availability
    if(plugin.edition == "enterprise") then
      available = "Enterprise"
      if((edition ~= "") and (edition ~= "enterprise")) then goto skip end
    elseif(plugin.edition == "pro") then
      available = "Pro"
      if((edition ~= "") and (edition ~= "pro")) then goto skip end
    else
      available = "Community"
      if((edition ~= "") and (edition ~= "community")) then goto skip end
    end

    print(string.format([[<tr><td>%s</td><td>%s</td><td class="text-center">%s</td><td>%s</td><td>%s</td></tr>]], plugin.title, plugin.description, plugin.version, plugin.path, available))
    ::skip::
  end

  print[[</table>]]
end

-- #######################################################

print[[<div class="row">
<div class="col col-md-1">
  <form class="form-inline" style="width:12em">
    <select id="filter_select" name="edition" class="form-control">
    <option value="" ]] print(ternary(isEmptyString(edition, "selected", ""))) print[[>All</option>
    <option value="community" ]] print(ternary(edition == "community", "selected", "")) print[[>Community Only</option>
    <option value="pro" ]] print(ternary(edition == "pro", "selected", "")) print[[>Pro Only</option>
    <option value="enterprise" ]] print(ternary(edition == "enterprise", "selected", "")) print[[>Enterprise Only</option>
    </select>
  </form>
</div>]]

if isAdministrator() then
  print[[<div class="col col-md-2 offset-9">
  <form class="form-inline" method="POST">
    <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[">
    <input name="action" type="hidden" value="reload" />
    <button class="btn btn-primary" style="margin-left:auto" type="submit">Reload Plugins</button>
  </form>
</div>
]]
end

print[[
</div>
<script>
  $("#filter_select").on("change", function() {
    $("#filter_select").closest("form").submit();
  });
</script><br>]]

printPlugins()

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

