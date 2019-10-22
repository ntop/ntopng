--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local user_scripts = require("user_scripts")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')
page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print[[<hr>]]

local ifid = interface.getId()
local edition = _GET["edition"] or ""

-- #######################################################

local function printUserScripts(title, scripts)
  print[[<h3>]] print(title) print[[</h3>
    <table class="table table-bordered table-condensed table-striped">
    <tr><th class='text-center' width="30%">Script</th><th width="10%">Availability</th><th width="30%">Hooks</th><th>Filters</th></tr>]]

  for name, script in pairsByKeys(scripts.modules) do
    local available = ""
    local filters = {}
    local hooks = {}

    -- Hooks
    for hook in pairsByKeys(script.hooks) do
      hooks[#hooks + 1] = hook
    end
    hooks = table.concat(hooks, ", ")

    -- Filters
    if(script.is_alert) then filters[#filters + 1] = "alerts" end
    if(script.l4_proto) then filters[#filters + 1] = "l4_proto=" .. script.l4_proto end
    if(script.l7_proto) then filters[#filters + 1] = "l7_proto=" .. script.l7_proto end
    if(script.packet_interface_only) then filters[#filters + 1] = "packet_interface" end
    if(script.local_only) then filters[#filters + 1] = "local_only" end
    if(script.nedge_only) then filters[#filters + 1] = "nedge=true" end
    if(script.nedge_exclude) then filters[#filters + 1] = "nedge=false" end
    filters = table.concat(filters, ", ")

    if(name == "my_custom_script") then
      goto skip
    end

    -- Availability
    if(string.find(script.path, "/enterprise/")) then
      available = "Enterprise"
      if((edition ~= "") and (edition ~= "enterprise")) then goto skip end
    elseif(string.find(script.path, "/pro/")) then
      available = "Pro"
      if((edition ~= "") and (edition ~= "pro")) then goto skip end
    else
      available = "Community"
      if((edition ~= "") and (edition ~= "community")) then goto skip end
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
<option value="community" ]] print(ternary(edition == "community", "selected", "")) print[[>Community Only</option>
<option value="pro" ]] print(ternary(edition == "pro", "selected", "")) print[[>Pro Only</option>
<option value="enterprise" ]] print(ternary(edition == "enterprise", "selected", "")) print[[>Enterprise Only</option>
</select>
</form>
<script>
  $("#filter_select").on("change", function() {
    $("#filter_select").closest("form").submit();
  });
</script>]]

printUserScripts("Interface Scripts", user_scripts.load(user_scripts.script_types.traffic_element, ifid, "interface", nil, ignore_disabled, nil, return_all))
print("<br>")
printUserScripts("Host Scripts", user_scripts.load(user_scripts.script_types.traffic_element, ifid, "host", nil, ignore_disabled, nil, return_all))
print("<br>")
printUserScripts("Network Scripts", user_scripts.load(user_scripts.script_types.traffic_element, ifid, "network", nil, ignore_disabled, nil, return_all))
print("<br>")
printUserScripts("Flow Scripts", user_scripts.load(user_scripts.script_types.flow, ifid, "flow", nil, ignore_disabled, nil, return_all))

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

