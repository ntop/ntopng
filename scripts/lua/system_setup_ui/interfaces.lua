--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
require "lua_utils"
require "prefs_utils"
prefsSkipRedis(true)

if not (ntop.isnEdge() or ntop.isAppliance()) or not isAdministrator() then
   return
end

local sys_config
if ntop.isnEdge() then
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path
   sys_config = require("nf_config"):create(true)
else -- ntop.isAppliance()
   package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
   sys_config = require("appliance_config"):create(true)
end

system_setup_ui_utils.process_apply_discard_config(sys_config)

local mode = sys_config:getOperatingMode()

if (_POST["lan_interfaces"] ~= nil) and (_POST["wan_interfaces"] ~= nil) then
  sys_config:setLanWanIfaces(split(_POST["lan_interfaces"], ","), split(_POST["wan_interfaces"], ","))

  if (mode == "routing") then
    -- Ensure we are on static mode on the lan inteface
    local lan_iface = sys_config:getLanInterface()
    sys_config:setInterfaceMode(lan_iface, "static")
  end

  sys_config:save()
end

local function valuesToKeys(t)
  local res = {}

  for k, v in pairs(t or {}) do
    res[v] = 1
  end

  return res
end

local function printIfSelected(iface, interfaces_set)
  print([[<option value="]] .. iface ..  [["]])

  if interfaces_set then
    print(" selected")
  end

  print([[>]] .. iface .. [[</option>]])
end

local print_page_body

-- Interaface limits configuration
local min_lan_ifaces = "1"
local min_wan_ifaces = "1"
local max_lan_ifaces = "1"
local max_wan_ifaces = ""
if mode == "routing" then
  -- nothing to change
elseif mode == "bridging" then
  -- temporary limits - we need to support multiple LAN interfaces in C code
  max_wan_ifaces = "1"
elseif mode == "passive" then
  min_wan_ifaces = ""
end

local lan_label
local wan_label
if mode == "passive" then
  lan_label = i18n("appliance.management")
  wan_label = i18n("appliance.capture_interfaces")
else
  lan_label = i18n("nedge.lan")
  wan_label = i18n("nedge.wan")
end

print_page_body = function()
  printPageSection(i18n("prefs.network_interfaces"))

  local ifaces = sys_config:getAllInterfaces()

  print[[
  <tr>
    <td>
      <input name="lan_interfaces" type="hidden">
      <input name="wan_interfaces" type="hidden">

      <div class="form-group mb-3" style="width:40%; margin-left:5%; display:inline-block;">
        <label class='form-label' for="lan_ifaces">]] print(lan_label) print[[</label>
        <select id="lan_ifaces" class="form-select" name="lan_ifaces" style="min-height: 150px;" multiple>]]

  for iface, role in pairsByKeys(ifaces) do
    printIfSelected(iface, role == "lan")
  end

  print[[</select>
      </div>
      <div class="form-group mb-3" style="width:40%; margin-right:5%; display:inline-block; float:right;">
        <label class='form-label' for="wan_ifaces" >]] print(wan_label) print[[</label>
        <select id="wan_ifaces" class="form-select" name="wan_ifaces" style="min-height: 150px;" multiple>]]

  for iface, role in pairsByKeys(ifaces) do
    printIfSelected(iface, role == "wan")
  end

  print[[</select>
      </div>
    </td>
  </tr>

  <script>
    function setSelectValue(select_obj, value) {
      select_obj.data("old_val", value);
    }

    function saveSelectValue(select_obj) {
      setSelectValue(select_obj, $(select_obj).val());
    }

    function getSavedSelectValue(select_obj) {
      return select_obj.data("old_val");
    }

    function handleSelect(select_set, inverse_set, select_min, inverse_min, select_max) {
      var input = $(select_set);
      var inverse_input = $(inverse_set);
      var selection = input.val();
      var inverse_selection = inverse_input.val();

      // Minimum selection check
      if (((typeof select_min !== "undefined") && input.find("option:selected").length < select_min)
            || ((typeof select_max !== "undefined") && input.find("option:selected").length > select_max)) {
        input.val(getSavedSelectValue(input));
        return;
      }

      // Avoid selecting the same elements on the two sets
      for (var i=0; i<selection.length; i++) {
        for (var j=0; j<inverse_selection.length; j++) {
          if (inverse_selection[j] == selection[i]) {
            var to_desel = inverse_input.find("option[value='" + inverse_selection[j] + "']");
            to_desel.prop("selected", false);

            // find an element to select
            var found = false;
            to_desel.siblings().each(function() {
              if (!found && !input.find("option[value='" + $(this).val() + "']").prop("selected")) {
                found = true;
                $(this).prop("selected", true);
              }
            });
          }
        }
      }

      // Minimum selection check
      if (((typeof inverse_min !== "undefined") && inverse_input.find("option:selected").length < inverse_min)) {
        input.val(getSavedSelectValue(input));
        inverse_input.val(getSavedSelectValue(inverse_input));
        return;
      }

      saveSelectValue(input);
      saveSelectValue(inverse_input);
    }

    $("#lan_ifaces").change(function() { handleSelect("#lan_ifaces", "#wan_ifaces", ]]
      print(min_lan_ifaces) print[[, ]]
      print(ternary(isEmptyString(min_wan_ifaces), 'undefined', min_wan_ifaces)) print[[, ]]
      print(ternary(isEmptyString(max_lan_ifaces), 'undefined', max_lan_ifaces)) print[[); });
    $("#wan_ifaces").change(function() { handleSelect("#wan_ifaces", "#lan_ifaces", ]]
      print(ternary(isEmptyString(min_wan_ifaces), 'undefined', min_wan_ifaces)) print[[, ]]
      print(min_lan_ifaces) print[[, ]]
      print(ternary(isEmptyString(max_wan_ifaces), 'undefined', max_wan_ifaces)) print[[); });

    saveSelectValue($("#lan_ifaces"));
    saveSelectValue($("#wan_ifaces"));

    $("#lan_ifaces").closest("form").submit(function() {
      var lan_ifaces = $("#lan_ifaces").val().join(",");
      var wan_ifaces = $("#wan_ifaces").val().join(",");

      // Format conversion
      $(this).find("[name='lan_interfaces']").val(lan_ifaces);
      $(this).find("[name='wan_interfaces']").val(wan_ifaces);

      // Remove name in old fields to avoid submitting them
      $("#lan_ifaces").removeAttr("name");
      $("#wan_ifaces").removeAttr("name");
    });
  </script>
]]

  printSaveButton()
end

system_setup_ui_utils.print_setup_page(print_page_body, sys_config)

