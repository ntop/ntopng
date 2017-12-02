require("lua_utils")
local template = require "template_utils"
local host_pools_utils = require "host_pools_utils"

local ifstats = interface.getStats()

local function hasBridgeConfiguration(captive_portal_active)
  return captive_portal_active
    or (#host_pools_utils.getPoolsList(ifstats.id, true) > 1)
    or (not table.empty(getCaptivePortalUsers()))
end

local captive_portal_supported = isCaptivePortalSupported(ifstats, prefs)
local captive_portal_active = isCaptivePortalActive(ifstats, prefs)

local configuration_found = hasBridgeConfiguration(captive_portal_active)
local config_overwrite_warning = "<b>"..string.upper(i18n("warning"))..":</b> "..i18n("bridge_wizard.warning_configuration_exist")

local no_local_networks

if not captive_portal_supported then
  no_local_networks = true

  for net in pairs(ntop.getLocalNetworks()) do
    if not starts(net, "127.0.0.0") then
      no_local_networks = false
      break
    end
  end
else
  no_local_networks = false
end

local no_local_networks_warning = "<b>"..string.upper(i18n("error"))..":</b> "..i18n("bridge_wizard.no_local_networks")

local captive_portal_status
if captive_portal_active then
  captive_portal_status = i18n("bridge_wizard.captive_portal_running")
elseif captive_portal_supported then
  captive_portal_status = i18n("bridge_wizard.captive_portal_available")
else
  captive_portal_status = i18n("bridge_wizard.captive_portal_unavailable")
end

local steps = {
  {    -- Step 1
     title = i18n("bridge_wizard.start"),
     content = i18n("bridge_wizard.intro_1", {iface=ifstats.name}).."<br><br>"..captive_portal_status..[[
     <br>]]..ternary(configuration_found, "<br>"..config_overwrite_warning, "")..[[<br>
     <br>]]..ternary(no_local_networks, "<br>"..no_local_networks_warning, "<br><br>"..i18n("bridge_wizard.click_on_next")),
     size = 2,
  }, { -- Step 2
        title = i18n("bridge_wizard.configure_host_pools"),
        content = i18n("bridge_wizard.host_pool_info")..[[<br><br>
    <label>]]..i18n("bridge_wizard.create_custom_pool")..[[</label>
    <div class="form-group has-feedback" style="margin-bottom:0;">
      <input class="form-control" id="wizard_custom_pool_name" name="pool_name" data-pool_name="pool_name" required/>
      <div class="help-block with-errors" style="height:1.2em;"></div>
    </div>
    <br>
    <div class="checkbox">
      <input type="checkbox" id="wizard_create_guests_pool" name="create_guests_pool">]]..i18n("bridge_wizard.also_create_these_pools")..[[
      <ul>
        <li>]]..i18n("bridge_wizard.the_guests_pool", {guests = i18n("bridge_wizard.guests")})..[[</li>
        <li>]]..i18n("bridge_wizard.the_children_pool", {safe_search = i18n("bridge_wizard.safe_search_guest")})..[[</li>
      </ul>
    </div>]],
        size = 3,
  }, { -- Step 3
     title = i18n("bridge_wizard.configure_user"),
     content = i18n("bridge_wizard.configure_user_message", {pool='<span id="wizard_credentials_pool_name"></span>'})..[[<br><br>
    <label>]]..i18n("bridge_wizard.username")..[[</label>
    <input style="display:none" type="text" name="_" data-ays-ignore="true"/>
    <input style="display:none" type="password" name="_" data-ays-ignore="true"/>
    <div class="form-group has-feedback" style="margin-bottom:0;">
       <input class="form-control" name="username" placeholder="]]..i18n("bridge_wizard.username_title")..[[" data-username="username" required/>
       <div class="help-block with-errors" style="height:1.2em;"></div>
    </div>

    <label>]]..i18n("bridge_wizard.password")..[[</label>
    <div class="form-group has-feedback" style="margin-bottom:0;">
       <input class="form-control" name="password" type="password" pattern="]]..getPasswordInputPattern()..[[" placeholder="]]..i18n("bridge_wizard.password_title")..[[" oninvalid="setCustomValidity(']]..i18n("bridge_wizard.password_format_error")..[[.');" oninput="setCustomValidity('');" required/>
       <div class="help-block with-errors" style="height:1.2em;"></div>
    </div>

    <span id="wizard_guests_creds">
      ]]..i18n("bridge_wizard.predefined_users_message", {
        guests = i18n("bridge_wizard.guests"),
        guests_username = "guest",
        guests_password = "guest",
        children = i18n("bridge_wizard.safe_search_guest"),
        children_username = "children",
        children_password = "children",
      })..[[
    </span>]],
     disabled = not captive_portal_supported,
     size = 3,
     on_show = [[
      $("#wizard_credentials_pool_name").html($("#wizard_custom_pool_name").val());
      $("#wizard_guests_creds").css("display", $("#wizard_create_guests_pool").prop("checked") ? "" : "none");
     ]],
  }, { -- Step 4
     title = i18n("bridge_wizard.policy"),
     content = i18n("bridge_wizard.define_policy", {pool='<span id="wizard_policy_pool_name"></span>'})..[[<br><br><select class="form-control" name="policy_preset">
          <option value="" selected>]]..i18n("bridge_wizard.no_preset")..[[</option>
          <option value="children">]]..i18n("bridge_wizard.children_preset")..[[</option>
          <option value="business">]]..i18n("bridge_wizard.business_preset")..[[</option>
          <option value="no_obfuscation">]]..i18n("bridge_wizard.no_obfuscation_preset")..[[</option>
          <option value="walled_garden">]]..i18n("bridge_wizard.walled_garden_preset")..[[</option>
        </select><br><br>]]..i18n("bridge_wizard.fine_tune", {url=ntop.getHttpPrefix().."/lua/if_stats.lua?page=filtering"}),
     size = 2,
     on_show = [[
      $("#wizard_policy_pool_name").html($("#wizard_custom_pool_name").val());
     ]],
  }, { -- Step 5
     title = i18n("bridge_wizard.done"),
     content = i18n("bridge_wizard.configuration_complete", {iface=ifstats.name})..[[
  <ul>
     <li><a target="_blank" href="]]..ntop.getHttpPrefix()..[[/lua/if_stats.lua?page=pools">]]..i18n("bridge_wizard.host_pools_config")..[[</a></li>
     <li><a target="_blank" href="]]..ntop.getHttpPrefix()..[[/lua/if_stats.lua?page=filtering">]]..i18n("bridge_wizard.policies_config")..[[</a></li>
     ]]..ternary(captive_portal_active, [[
        <li><a target="_blank" href="]]..ntop.getHttpPrefix()..[[/lua/admin/users.lua?captive_portal_users=1">]]..i18n("bridge_wizard.captive_portal_users")..[[</a></li>
     ]], "")..[[
  </ul>]]..ternary(configuration_found, "<br><div>"..config_overwrite_warning.."</div>", ""),
     size = 2,
  }
}

local wizard = {
  id = "bridgeWizardModal",
  title = "Bridge Configuration Wizard",
  style = "width: 50em;",
  body_style = "height: 36em;",
  validator_options = [[{
     custom: {
        member: memberValueValidator,
        pool_name: poolNameValidator,
        username: usernameValidator,
     }, errors: {
        member: "]]..i18n("host_pools.invalid_member")..[[.",
        pool_name: "]]..i18n("bridge_wizard.pool_name_error")..[[.",
        username: "]]..i18n("bridge_wizard.username_error")..[[.",
     }
  }]],
  steps = steps,
  cannot_proceed = no_local_networks,
  form_action = ntop.getHttpPrefix().."/lua/pro/init_bridge.lua?ifid="..ifstats.id,
  form_onsubmit = "checkBridgeWizardForm",
}

print[[
<script>
  function poolNameValidator(input) {
    var value = $(input).val();
    if (value === "") return true;

    /* When we are about to create the guests pool, the custom pool name cannot be the same */
    if($("#wizard_create_guests_pool").prop("checked")
     && ((value === "]] print(i18n("bridge_wizard.guests")) print[[") || (value === "]] print(i18n("bridge_wizard.safe_search_guest")) print[[")))
      return false;

    return true;
  }

  function usernameValidator(input) {
    var value = $(input).val();
    if (value === "") return true;

    /* When we are about to create the guests pool, the custom pool credentials cannot be the same */
    if($("#wizard_create_guests_pool").prop("checked")
     && ((value === "guest") || (value === "children")))
      return false;

    return true;
  }

  function checkBridgeWizardForm(form) {
    var member_input = $("input[name='member']", form);
    if (member_input.length == 1) {
      var member = member_input.val();

      if (! is_mac_address(member)) {
        var is_cidr = is_network_mask(member, true);

        if (is_cidr)
          member_input.val(is_cidr.address + "/" + is_cidr.mask + "@0");
      }
    }

    return true;
  }
</script>
]]
print(template.gen("wizard_dialog.html", {wizard = wizard}))
