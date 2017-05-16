local template = require "template_utils"
local host_pools_utils = require "host_pools_utils"

local function hasBridgeConfiguration(captive_portal_active)
  return captive_portal_active
    or (#host_pools_utils.getPoolsList(_ifstats.id, true) > 1)
    or (not table.empty(getCaptivePortalUsers()))
end

local captive_portal_supported = isCaptivePortalSupported(_ifstats, prefs)
local captive_portal_active = isCaptivePortalActive(_ifstats, prefs)
local bridge_anomaly = "" --i18n("bridge_wizard.bridge_missing_ip", {iface="br0"})
local configuration_found = hasBridgeConfiguration(captive_portal_active)

local config_overwrite_warning = "<b>"..string.upper(i18n("warning"))..":</b> "..i18n("bridge_wizard.warning_configuration_exist")

local captive_portal_status
if captive_portal_active then
  captive_portal_status = i18n("bridge_wizard.captive_portal_running")
elseif captive_portal_supported then
  captive_portal_status = i18n("bridge_wizard.captive_portal_available")
else
  captive_portal_status = i18n("bridge_wizard.captive_portal_unavailable")
end

local step_1_ok = i18n("bridge_wizard.intro_1").."<br><br>"..captive_portal_status..[[
     <br>]]..ternary(configuration_found, "<br><br>"..config_overwrite_warning.."<br><br>", "<br>")..i18n("bridge_wizard.click_on_next")

local step_1_with_errors = [[<div class="alert alert-danger">]]..bridge_anomaly..[[</div><br><br>]]..i18n("bridge_wizard.check_doc", {url="https://github.com/ntop/ntopng/blob/dev/doc/README.inline"})

local steps = {
  {    -- Step 1
     title = i18n("bridge_wizard.start"),
     content = ternary(not isEmptyString(bridge_anomaly), step_1_with_errors, step_1_ok),
     size = 2,
  }, { -- Step 2
     title = i18n("bridge_wizard.configure_user"),
     content = i18n("bridge_wizard.configure_user_message")..[[<br><br>
  <label>]]..i18n("bridge_wizard.username")..[[</label>
  <input style="display:none" type="text" name="_" data-ays-ignore="true"/>
  <input style="display:none" type="password" name="_" data-ays-ignore="true"/>
  <div class="form-group has-feedback" style="margin-bottom:0;">
     <input class="form-control" name="username" placeholder="]]..i18n("bridge_wizard.username_title")..[[" required/>
     <div class="help-block with-errors"></div>
  </div>
  <br>
  <label>]]..i18n("bridge_wizard.password")..[[</label>
  <div class="form-group has-feedback" style="margin-bottom:0;">
     <input class="form-control" name="password" type="password" pattern="]]..getPasswordInputPattern()..[[" placeholder="]]..i18n("bridge_wizard.password_title")..[[" required/>
     <div class="help-block with-errors"></div>
  </div>
     ]],
     disabled = not captive_portal_supported,
     size = 3,
  }, { -- Step 3
        title = i18n("bridge_wizard.configure_host_pools"),
        content = i18n("bridge_wizard.host_pool_info")..[[<br><br>

  <label>]]..i18n("host_pools.pool")..[[</label>
  
  <div class="form-group has-feedback" style="margin-bottom:0;">
     <input class="form-control" name="pool_name" required/>
     <div class="help-block with-errors"></div>
  </div>]]
     ..ternary(not captive_portal_supported,
        [[<label>]]..i18n("bridge_wizard.pool_member")..[[</label>
        <div class="form-group has-feedback" style="margin-bottom:0;">
           <input class="form-control" name="member" data-member="member" placeholder="]]..i18n("bridge_wizard.member_placeholder")..[[" required/>
           <div class="help-block with-errors"></div>
        </div>]], ""),
        size = 3,
  }, { -- Step 4
     title = i18n("bridge_wizard.policy"),
     content = i18n("bridge_wizard.define_policy")..[[<br><br><select class="form-control" name="policy_preset">
        <option value="" selected>]]..i18n("bridge_wizard.no_preset")..[[</option>
        <option value="children">]]..i18n("bridge_wizard.children_preset")..[[</option>
        <option value="business">]]..i18n("bridge_wizard.business_preset")..[[</option>
     </select><br><br>]]..i18n("bridge_wizard.fine_tune", {url=ntop.getHttpPrefix().."/lua/if_stats.lua?page=filtering"}),
     size = 2,
  }, { -- Step 5
     title = i18n("bridge_wizard.done"),
     content = i18n("bridge_wizard.configuration_complete")..[[
  <ul>
     <li><a href="]]..ntop.getHttpPrefix()..[[/lua/if_stats.lua?page=pools">]]..i18n("bridge_wizard.host_pools_config")..[[</a></li>
     <li><a href="]]..ntop.getHttpPrefix()..[[/lua/if_stats.lua?page=filtering">]]..i18n("bridge_wizard.policies_config")..[[</a></li>
     ]]..ternary(captive_portal_active, [[
        <li><a href="]]..ntop.getHttpPrefix()..[[/lua/admin/users.lua?captive_portal_users=1">]]..i18n("bridge_wizard.captive_portal_users")..[[</a></li>
     ]], "")..[[
  </ul>]]..ternary(configuration_found, "<br>"..config_overwrite_warning, ""),
     size = 2,
  }
}

local wizard = {
  id = "bridgeWizardModal",
  title = "Bridge Configuration Wizard",
  style = "width: 50em;",
  body_style = "height: 30em;",
  validator_options = [[{
     custom: {
        member: memberValueValidator,
     }, errors: {
        member: "]]..i18n("host_pools.invalid_member")..[[.",
     }
  }]],
  steps = steps,
  cannot_proceed = (not isEmptyString(bridge_anomaly)),
  form_action = ntop.getHttpPrefix().."/lua/pro/init_bridge.lua?ifid=".._ifstats.id,
  form_onsubmit = "checkBridgeWizardForm",
}

print[[
<script>
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

