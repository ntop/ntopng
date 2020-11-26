--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local template = require "template_utils"
local json = require "dkjson"
local page_utils = require("page_utils")

local is_nedge = ntop.isnEdge()
local is_appliance = ntop.isAppliance()

if not (is_nedge or is_appliance) then
   return
end

local subpages = {
   {name = "mode",               nedge_only = false, label = i18n("nedge.setup_mode"), url = "mode.lua"},
   {name = "network_interfaces", nedge_only = false, label = i18n("prefs.network_interfaces"), url = "interfaces.lua" },
   {name = "network_setup",      nedge_only = false, label = i18n("nedge.interfaces_configuration"), url = "network.lua"},
   {name = "dhcp",               nedge_only = false, label = i18n("nedge.dhcp_server"), url = "dhcp.lua", routing_only = true},
   {name = "dns",                nedge_only = true, label = i18n("nedge.dns_configuration"), url = "dns.lua", vlan_trunk = false},
   {name = "captive_portal",     nedge_only = true,  label = i18n("prefs.toggle_captive_portal_title"), url = "captive_portal.lua", vlan_trunk = false},
   {name = "shapers",            nedge_only = true,  label = i18n("nedge.shapers"), url="shapers.lua"},
   {name = "gateways",           nedge_only = true,  label = i18n("nedge.gateways"), url = "gateways.lua", routing_only = true},
   {name = "static_routes",      nedge_only = true,  label = i18n("nedge.static_routes"), url = "static_routes.lua", routing_only = true},
   {name = "routing",            nedge_only = true,  label = i18n("nedge.routing_policies"), url = "routing.lua", routing_only = true},
   {name = "date_time",          nedge_only = false, label = i18n("nedge.date_time"), url = "date_time.lua"},
   {name = "security",           nedge_only = true,  label = i18n("nedge.security"), url = "security.lua", vlan_trunk = false},
   {name = "misc",               nedge_only = false, label = i18n("prefs.misc"), url = "misc.lua"},
}

local system_setup_ui_utils = {}

function system_setup_ui_utils.process_apply_discard_config(sys_config)
   if table.len(_POST) > 0 and sys_config then
      if _POST["nedge_config_action"] == "discard" then
         sys_config:discard()
      elseif _POST["nedge_config_action"] == "make_permanent" then
         sys_config:applyChanges()
      end
   end
end

function system_setup_ui_utils.print_page_before()
   sendHTTPContentTypeHeader('text/html')

   if not haveAdminPrivileges() then
      return false
   end

   page_utils.set_active_menu_entry(page_utils.menu_entries.system_setup)
   active_page = "admin"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   page_utils.print_page_title(i18n("nedge.system_setup"))
   return true
end

function system_setup_ui_utils.print_setup_page(print_page_body_callback, sys_config, warnings)
   warnings = warnings or {}

   if not system_setup_ui_utils.print_page_before() then
     return false
   end

   system_setup_ui_utils.print_page_after(print_page_body_callback, sys_config, warnings)
   return true
end

function system_setup_ui_utils.print_page_after(print_page_body_callback, sys_config, warnings)
   system_setup_ui_utils.printConfigChange(sys_config, warnings)
   system_setup_ui_utils.printPageBody(sys_config, print_page_body_callback)
end

function system_setup_ui_utils.printConfigChange(sys_config, warnings)
   local first_start = sys_config.isFirstStart()
   local config_changed = sys_config.configChanged()

   if config_changed or first_start then

      if is_nedge then
         local dhcp_config = sys_config:getDhcpServerConfig()

         if dhcp_config.enabled then
            if not sys_config:hasValidDhcpRange(dhcp_config.subnet.first_ip, dhcp_config.subnet.last_ip) then
               warnings[#warnings + 1] = i18n("nedge.invalid_dhcp_range")
            end
         end
      end

      print(
        template.gen("modal_confirm_dialog.html", {
          dialog={
            id      = "config_apply_dialog_reboot",
            action  = "$('#applyNedgeConfig').submit()",
            title   = i18n("nedge.apply_configuration"),
            message = i18n("nedge.apply_configuration_and_reboot"),
	    custom_alert_class = "alert alert-danger",
            confirm = i18n("nedge.apply_and_reboot"),
            confirm_button = "btn-primary",
          }
        })
      )

      print(
        template.gen("modal_confirm_dialog.html", {
          dialog={
            id      = "config_apply_dialog_restart_self",
            action  = "$('#applyNedgeConfig').submit()",
            title   = i18n("nedge.apply_configuration"),
            message = i18n("nedge.apply_configuration_and_restart_self", {product = ntop.getInfo()["product"]}),
	    custom_alert_class = "alert alert-danger",
            confirm = i18n("nedge.apply_and_restart_self"),
            confirm_button = "btn-primary",
          }
        })
      )

      print[[<div class="alert alert-warning" role="alert"><i class="fas fa-exclamation-triangle fa-sm"></i> ]]
      print[[<strong>]] print(i18n("nedge.setup_config_edited_title")) print[[</strong> ]]
      print(ternary(not sys_config.configChanged(), i18n("nedge.apply_the_initial_device_configuration"), i18n("nedge.setup_config_edited_descr")))
      print[[<button style="visibility:hidden;">&nbsp;</button>]]
      print[[<div style="display: inline-block; float: right;">]]

   if config_changed then
     print[[<form name="modifyNedgeConfig" class="form-inline" style="display:inline;" method="POST">
    <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [["/>
    <input type="hidden" name="nedge_config_action" value="discard">
    <button type="submit" class="btn btn-secondary">]] print(i18n("nedge.setup_discard")) print[[</button>
  </form>]]
  end

      print[[
<form id="applyNedgeConfig" name="modifyNedgeConfig" class="form-inline" style="display:inline;" method="POST">
  <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [["/>
  <input type="hidden" name="nedge_config_action" value="make_permanent">
]]

      if sys_config:needsReboot() then
         print[[<button type="button" data-toggle="modal" data-target="#config_apply_dialog_reboot" class="btn btn-primary">]] print(i18n("nedge.setup_apply")) print[[</button>]]
      elseif sys_config:needsSelfRestart() then
         print[[<button type="button" data-toggle="modal" data-target="#config_apply_dialog_restart_self" class="btn btn-primary">]] print(i18n("nedge.setup_apply")) print[[</button>]]
      else
         print[[<button type="submit" class="btn btn-primary">]] print(i18n("nedge.setup_apply")) print[[</button>]]
      end
      print[[
</form>
</div>
</div>
]]
   end

   for _, warning in ipairs(warnings) do
      if not isEmptyString(warning) then
         printWarningAlert(warning)
      end
   end
end

function system_setup_ui_utils.printPageBody(sys_config, print_page_body_callback)
   print[[
<table class="table">
  <col width="20%">
  <col width="80%">
  <tr>
    <td>
      <div class="list-group">
]]

   local mode = sys_config:getOperatingMode()
   for _, subpage in ipairs(subpages) do
      if not is_nedge and subpage.nedge_only then
         goto continue
      elseif (subpage.routing_only == true) and (not sys_config:isMultipathRoutingEnabled()) then
         goto continue
      elseif (subpage.vlan_trunk == false) and (sys_config:isBridgeOverVLANTrunkEnabled()) then
         goto continue
      end

      print("<a href=\""..ntop.getHttpPrefix().."/lua/")
      if subpage.nedge_only then
         print("pro/nedge/")
      end
      print("system_setup_ui/")
      print(subpage.url)
      print[[" class="list-group-item list-group-item-action]]

      if((_SERVER["URI"] or ''):ends(subpage.url)) then
	 print(" active")
      end

      print[[">]] print(subpage.label) print[[</a>]]

      ::continue::
   end

   print[[
      </div>
    </td>
    <td colspan=2 style="padding-left: 14px;border-left-style: groove; border-width:1px; border-color: #e0e0e0;">
      <form method="POST">
         <table class="table">
]]

   if print_page_body_callback then
      print_page_body_callback()
   end

   print[[
         </table>

         <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[">
      </form>
    </td>
  </tr>
</table>

<script>
   aysHandleForm("form[name!='modifyNedgeConfig']", {
      disable_on_dirty: '.disable-on-dirty',
   });

   /* Use the validator plugin to override default chrome bubble, which is displayed out of window */
   $("form[id!='search-host-form']").validator({disable:true});
</script>]]

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end


function system_setup_ui_utils.printPrivateAddressSelector(label, comment, ip_key, netmask_key, value, showEnabled, extra)
  local field_id = ip_key .. "__id"
  local networks_presets = {
    {prefix="192.168", netmask="255.255.255.0"},
    {prefix="172.16", netmask="255.255.0.0"},
    {prefix="10.0", netmask="255.255.0.0"},
  }
  extra = extra or {}
  local initial_preset = ""
  local initial_quad3 = ""
  local initial_quad4 = ""
  local netmask_value = "255.255.255.0"

  if value ~= nil then
    local parts = string.split(value, "%.")
    local prefix = table.concat({parts[1], parts[2]}, ".")

    for _, preset in pairs(networks_presets) do
      if preset.prefix == prefix then
        initial_preset = preset.prefix
        initial_quad3 = parts[3]
        initial_quad4 = parts[4]
        break
      end
    end
  end

  if ((showEnabled == nil) or (showEnabled == true)) then
    showEnabled = "table-row"
  else
    showEnabled = "none"
  end

   print('<tr id="'..field_id..'" style="display: '..showEnabled..';"><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')
 print [[
    <td align=right>
      <table class="form-group" style="margin-bottom: 0; min-width:22em;">
        <tr class='border-0'>
          ]]

      print[[
          <td class="local-ip-selector border-0 text-right" style="vertical-align:top; padding-left: 2em;">]]

   -- Find initial netmask
   for _, preset in pairs(networks_presets) do
      if preset.prefix == initial_preset then
         netmask_value = preset.netmask
      end
   end

   if extra.net_select ~= false then
      print[[<select name="]] print(field_id) print[[_net" class="form-control d-inline-block" style="width: 9.6rem">]]

      for _, preset in pairs(networks_presets) do
         print[[<option value="]] print(preset.prefix) print[["]]
         if preset.prefix == initial_preset then
            print(" selected")
         end
         print[[>]]
         print(preset.prefix)
         print[[</option>]]
      end
      print[[</select> .]]
   else
      print[[<input type="hidden" name="]] print(field_id) print[[_net" value="]] print(initial_preset) print[[">]]
      print([[<span>]] .. initial_preset .. [[</span>]])
      print(ternary(extra.quad3_select == false, ".", " . "))
   end

   local input_type = "number"
   if extra.quad3_select == false then
      input_type = "hidden"
      print(initial_quad3)
   end

   print[[<input class="form-control d-inline-block" style="width: 4.8rem" type="]] print(input_type) print[[" min="0" max="255" name="]] print(field_id) print[[_quad_3" value="]] print(initial_quad3) print[[" />]]
   print(ternary(extra.quad4_select == false, ".", " . "))

   local input_type = "number"
   if extra.quad4_select == false then
      input_type = "hidden"
      print(initial_quad4)
   end

   print[[<input class="form-control d-inline-block" style="width: 4.8rem" type="]] print(input_type) print[[" min="1" max="254" name="]] print(field_id) print[[_quad_4" value="]] print(initial_quad4) print[[" />
   <input type="hidden" name="]] print(ip_key) print[[">]]
   if netmask_key ~= nil then
      print[[<input type="hidden" name="]] print(netmask_key) print[[" value="]] print(netmask_value) print[[">]]
   end

   print[[</div>
          </td>
        </tr>
        <tr>
          <td colspan="3" style="padding:0;">
            <div class="help-block with-errors text-right" style="height:1em;"></div>
          </td>
        </tr>
      </table>
  </td></tr>

  <script>
      var network_prefixes = ]] print(json.encode(networks_presets)) print[[;
      var form = $("#]] print(field_id) print[[").closest("form");

      if (! form.attr("data-privaddr-]] print(field_id) print[[")) {
        form.attr("data-privaddr-]] print(field_id) print[[", 1);
        form.submit(function(event) {
          var form = $(this);

          if (event.isDefaultPrevented() || (form.find(".has-error").length > 0))
            return false;

          var f_net = form.find('[name="]] print(field_id) print[[_net"]');
          var f_quad3 = form.find('[name="]] print(field_id) print[[_quad_3"]');
          var f_quad4 = form.find('[name="]] print(field_id) print[[_quad_4"]');
          var f_ip = form.find('[name="]] print(ip_key) print[["]');
          f_ip.val([f_net.val(), f_quad3.val(), f_quad4.val()].join("."));

          ]]

   if netmask_key ~= nil then
      print[[
          var f_netmask = form.find('[name="]] print(netmask_key) print[["]');
          var netmask_to_apply = null;

          for(var i=0; i<network_prefixes.length; i++) {
            if(network_prefixes[i].prefix == f_net.val()) {
               netmask_to_apply = network_prefixes[i].netmask;
               break;
            }
         }
          if(netmask_to_apply) f_netmask.val(netmask_to_apply);
         ]]
   end

   print[[
          // Clear the support fields
          f_net.removeAttr("name");
          f_quad3.removeAttr("name");
          f_quad4.removeAttr("name");

          // Reset form for ays
          aysResetForm(form);
          return true;
        });
      }
  </script>]]
end

function system_setup_ui_utils.prefsDateTimeFieldPrefs(label, comment, key, default_value, showEnabled, extra)
  extra = extra or {}

  if ((showEnabled == nil) or (showEnabled == true)) then
    showEnabled = "table-row"
  else
    showEnabled = "none"
  end

  local attributes = {}

  if extra.disabled == true then attributes["disabled"] = "disabled" end
  if extra.required == true then attributes["required"] = "" end

  local input_type = "text"
  print('<tr id="'..key..'" style="display: '..showEnabled..';"><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  local style = {}
  style["text-align"] = "right"
  style["margin-bottom"] = "0.5em"

  print [[
    <td align=right>
      <table class="form-group" style="margin-bottom: 0; min-width:22em;">
        <tr>
          <td width="100%;"></td>]]

      if extra.width == nil then
	 style["width"] = "20em"
	 style["margin-left"] = "auto"
      else
        style["width"] = "15em"
      end
      style["margin-left"] = "auto"

      style = table.merge(style, extra.style)
      attributes = table.merge(attributes, extra.attributes)

      local orig_name = key.."_orig"
      local picker_name = key.."_picker"

      print[[
          <td style="vertical-align:top; padding-left: 2em;">
            <input type="hidden" id="]] print(orig_name) print[[" name="]] print(orig_name) print[[" value="" />
            <div class='input-group date' id=']] print(picker_name) print[[' style="width: 20em;" data-target-input="nearest">
               <input id="]] print(key) print[[" name="]] print(key) print[[" type="text" class="form-control datetimepicker-input" data_target="#]] print(picker_name) print[["/>
            <div class="input-group-append" data-target="#]] print(picker_name) print[[" data-toggle="datetimepicker">
               <div class="input-group-text"><i class="fas fa-calendar"></i></div>
            </div>
        <script type="text/javascript">
            var date_format = 'DD/MM/YYYY HH:mm:ss';
            var language = window.navigator.userLanguage || window.navigator.language;
            var bdate = new Date(]] print(default_value.."") print[[000);

            $(function () {
                $('#]] print(picker_name) print[[').datetimepicker({defaultDate: bdate, format: date_format});
                  $('#]] print(picker_name) print[[')
                  .on("change.datetimepicker", function(e) {
                     var input = $('#]] print(key) print[[').find('[name="' + "]] print(key) print[[" + '"]');
                     aysRecheckForm(input.closest("form"));
                  });
            $('#]] print(orig_name) print[[').val($('#]] print(picker_name) print[[').find("input").val());
            });

        </script>
</div>

          </td>
        </tr>
        <tr>
          <td colspan="3" style="padding:0;">
            <div class="help-block with-errors text-right" style="height:1em;"></div>
          </td>
        </tr>
      </table>
  </td></tr>

]]

end

return system_setup_ui_utils
