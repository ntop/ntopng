require("lua_utils")
require("prefs_utils")

local is_admin = isAdministrator()
local template = require("template_utils")
local locales_utils = require "locales_utils"
local host_pools = require "host_pools"

print [[

<div id="password_dialog" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="password_dialog_label" aria-hidden="true">
  <div class="modal-dialog modal-lg">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="password_dialog_label">]] print(i18n("manage_users.manage_user_x", {user=[[<span class="password_dialog_title">]].. _SESSION['user'] ..[[</span>]]})) print[[ </h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>

<div class="modal-body">

  <div class="tabbable"> <!-- Only required for left/right tabs -->
  <div class='card'>
  <div class='card-header'>
  <ul class="nav nav-tabs card-header-tabs" role="tablist" id="edit-user-container">
]]
    if(is_admin) then
      print[[<li class="nav-item active" id="li_change_prefs"><a class="nav-link active" href="#change-prefs-dialog" role="tab" data-bs-toggle="tab"> ]] print(i18n("prefs.preferences")) print[[ </a></li>]]
    end
   print[[
    <li class="nav-item ]] print(ternary(is_admin, "", "active")) print[["><a class="nav-link ]] print(ternary(is_admin, "", "active")) print[[" href="#change-password-dialog" role="tab" data-bs-toggle="tab"> ]] print(i18n("login.password")) print[[ </a></li>
    <li class="nav-item"><a class="nav-link" href="#user-token-tab" role="tab" data-bs-toggle="tab"> ]] print(i18n("login.auth_token")) print[[ </a></li>
    <li class="nav-item"><a class="nav-link" href="#user-mfa-tab" role="tab" data-bs-toggle="tab"> <i class="fas fa-shield-alt"></i> ]] print(i18n("mfa.tab_title") or "MFA") print[[ </a></li>
    <li class="nav-item"><a class="nav-link" href="#user-webauthn-tab" role="tab" data-bs-toggle="tab"> <i class="fas fa-fingerprint"></i> ]] print(i18n("webauthn.tab_title") or "Passkeys") print[[ </a></li>

  </ul>
  </div>
  <div class="card-body tab-content">
  <div class="tab-pane ]] print(ternary(is_admin, "", "active")) print[[" id="change-password-dialog">

  <div id="password_alert_placeholder"></div>

<script>
  password_alert = function() {}
  password_alert.error   = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-danger alert-dismissable">' + message + '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>');  }
  password_alert.success = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-success alert-dismissable">' + message + '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>'); }
</script>

  <form data-bs-toggle="validator" id="form_password_reset" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/admin/password_reset.lua" accept-charset="UTF-8">
]]

   print('<input name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[
    <input id="password_dialog_username" type="hidden" name="username" value="]] print(_SESSION["user"] or "") print[[" />

<div class="control-group">
   ]]

local col_md_size = "6"

if(not is_admin) then
   col_md_size = "4"
print [[
  <div class='form-group mb-3'>
  <label class='form-label' for="old_password_input">]] print(i18n("manage_users.old_password")) print[[</label>
  <div class='input-group mb-]] print(col_md_size) print[[ has-feedback'>
        <span class="input-group-text"><i class="fas fa-lock"></i></span>
      <input id="old_password_input" type="password" autocomplete="off" name="old_password" value="" class="form-control" required>
  </div>
  </div>
   ]]
end

print [[
  <div class='form-group mb-3'>
    <label class='form-label' for="new_password_input">]] print(i18n("manage_users.new_password")) print[[</label>
    <div class='input-group mb-]] print(col_md_size) print[['>
        <span class="input-group-text"><i class="fas fa-lock"></i></span>
        <input id="new_password_input" type="password" autocomplete="off" name="new_password" value="" class="form-control" pattern="]] print(getPasswordInputPattern()) print[[" required>
    </div>
  </div>

  <div class='form-group mb-3'>
  <label class='form-label' class='form-label' for="confirm_new_password_input">]] print(i18n("manage_users.new_password_confirm")) print[[</label>
  <div class='input-group md-]] print(col_md_size) print[['>
        <span class="input-group-text"><i class="fas fa-lock"></i></span>
        <input id="confirm_new_password_input" type="password" autocomplete="off" name="confirm_password" value="" class="form-control" pattern="]] print(getPasswordInputPattern()) print[[" required>
  </div>
  </div>


<div><small>]] print(i18n("manage_users.allowed_passwd_charset")) print[[.  </small></div>

<hr>

    <div class="has-feedback text-end">
      <button id="password_reset_submit" class="btn btn-primary">]] print(i18n("manage_users.change_user_password")) print[[</button>
    </div>

</form>
</div> <!-- closes div "change-password-dialog" -->
]]

if(is_admin) then

print [[
  </div>
<div class="tab-pane ]] print(ternary(is_admin, "active", "")) print[[" id="change-prefs-dialog">

  <form data-bs-toggle="validator" id="form_pref_change" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/admin/change_user_prefs.lua">
    <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
  <input id="pref_dialog_username" type="hidden" name="username" value="" />

  <div class='form-group mb-3'>
  <label class='form-label' for="host_role_select">]] print(i18n("manage_users.user_role")) print[[</label>
  <div class='input-group mb-6'>
        <select id="host_role_select" name="user_role" class="form-select">
          <option value="unprivileged">]] print(i18n("manage_users.non_privileged_user")) print[[</option>
          <option value="administrator">]] print(i18n("manage_users.administrator")) print[[</option>
        </select>
  </div>
  </div>

  <div id="unprivileged_manage_input">

  <div class='form-group mb-3'>
  <label class='form-label' for="allowed_interface">]] print(i18n("manage_users.allowed_interface")) print[[</label>
  <div class='input-group mb-6'>
        <select name="allowed_interface" id="allowed_interface" class="form-select">
          <option value="">]] print(i18n("manage_users.any_interface")) print[[</option>
]]
   for _, interface_name in pairsByValues(interface.getIfNames(), asc) do
      -- io.write(interface_name.."\n")
      print('<option value="'..getInterfaceId(interface_name)..'"> '..getHumanReadableInterfaceName(interface_name)..'</option>')
   end
   print[[
        </select>
  </div>
  </div>

]]

-- Host pools list for the multi-select
local _hp = host_pools:create()
local _all_pools = _hp:get_all_pools()
if #_all_pools > 0 then
print[[
  <div class='form-group mb-3'>
    <label class='form-label' for="edit_allowed_host_pools_select">]] print(i18n("manage_users.allowed_host_pools")) print[[</label>
    <select id="edit_allowed_host_pools_select" multiple class="form-select">
]]
  for _, pool in ipairs(_all_pools) do
    print('<option value="'..pool["pool_id"]..'">'..pool["name"]..'</option>\n')
  end
print[[
    </select>
    <input type="hidden" id="edit_allowed_host_pools" name="allowed_host_pools" value="">
    <small>]] print(i18n("manage_users.allowed_host_pools_descr")) print[[</small>
  </div>
]]
end

print[[
  <div class='form-group mb-3'>
    <label class='form-label' for="networks_input">]] print(i18n("manage_users.allowed_networks")) print[[</label>
    <div class='input-group mb-6'>
      <input id="networks_input" type="text" name="allowed_networks" value="" class="form-control w-100" required>
    </div>
    <small>]] print(i18n("manage_users.allowed_networks_descr")) print[[ 192.168.1.0/24,172.16.0.0/16</small>
  </div>

]]

print[[
    <div class="form-group mb-3 mb-6">
      <div class="form-check pl-0">]]

      print(template.gen("on_off_switch.html", {
        id = "allow_pcap_download",
        label = i18n("manage_users.allow_pcap_download_descr"),
       }))

      print(template.gen("on_off_switch.html", {
        id = "allow_historical_flows",
        label = i18n("manage_users.allow_historical_flows_descr"),
      }))

      print(template.gen("on_off_switch.html", {
        id = "allow_alerts",
        label = i18n("manage_users.allow_alerts_descr"),
      }))

    print[[
      </div>
    </div>

    </div>

    <script>
    function toggleUserSettings() {
      if ($("#host_role_select").val() == "unprivileged")
        $('#unprivileged_manage_input').show();
      else
        $('#unprivileged_manage_input').hide();
    }
    $("#host_role_select").change(function() { toggleUserSettings(); })
    </script>
]]

if #_all_pools > 0 then
print[[
    <script>
    $(document).ready(function() {
      $("#edit_allowed_host_pools_select").select2({
        width: '100%',
        theme: 'bootstrap-5',
        dropdownParent: $("#edit_allowed_host_pools_select").parent(),
        placeholder: ']] print(i18n("manage_users.allowed_host_pools")) print[[',
        allowClear: true,
      });
    });
    </script>
]]
end

print[[

]]

print[[
  <div class='form-group mb-3'>
    <label class='form-label' for="user_language">]] print(i18n("language")) print[[</label>
    <div class='input-group mb-6'>
        <span class="input-group-text"><i class="fas fa-language" aria-hidden="true"></i></span>
      <select name="user_language" id="user_language" class="form-select">]]

      local codes = {}
      for _, lang in ipairs(locales_utils.getAvailableLocales()) do
	 codes[lang["code"]] = true
      end

      for lang,_ in pairsByKeys(codes, desc) do
       print('<option value="'..lang..'">'..i18n("locales." .. lang)..'</option>')
     end
print[[
        </select>
    </div>
    </div>
]]

print[[
    <hr>
    <div class="has-feedback text-end">
      <button id="pref_change" class="btn btn-primary">]] print(i18n("manage_users.change_user_preferences")) print[[</button>
    </div>
  </form>
</div> <!-- closes div "change-prefs-dialog" -->
]]
end

if not is_admin then
print("</div>")
end

-- get the user token from redis
local api_token = ntop.getUserAPIToken(_SESSION['user'])
local input_value = api_token or i18n("manage_users.token_not_generated")

print([[
  <div class='tab-pane' id='user-token-tab'>
    <div class="form-group mb-3 has-error">
      <label class='form-label' for="token-input">]] .. i18n("manage_users.token") ..[[</label>
      <div class='d-flex'>
        <input readonly class='form-control' id='input-token' value=']].. input_value ..[['>
        <input readonly hidden id='input-username' value=']].._SESSION['user'] ..[['>
        <button ]].. (isEmptyString(api_token) and "style='display: none'" or "") ..[[ class="btn btn-light border ms-1" data-placement="bottom" id="btn-copy-token">
          <i class='fas fa-copy'></i>
        </button>
      </div>
    </div>
    <hr>
    <div class='w-100 text-end'>
      <button class='btn btn-primary' id='btn-generate_token'>]].. i18n("login.generate_token") ..[[</button>
    </div>
<div><small>]].. i18n("login.generate_token_help") ..[[.  </small></div>
  </div>
]])

-- MFA Tab
print([[
  <div class='tab-pane' id='user-mfa-tab'>
    <div id="mfa_alert_placeholder"></div>
    <div class="mb-3">
      <p class="text-muted">]] .. (i18n("mfa.description") or "Protect your account with a Time-based One-Time Password (TOTP) authenticator app such as Google Authenticator, Authy, or similar.") .. [[</p>
    </div>

    <!-- MFA status display -->
    <div id="mfa-status-section">
      <div class="d-flex align-items-center mb-3">
        <span id="mfa-status-badge" class="badge me-2"></span>
        <span id="mfa-status-text"></span>
      </div>
      <button id="btn-mfa-setup" class="btn btn-primary me-2" style="display:none">
        <i class="fas fa-qrcode"></i> ]] .. (i18n("mfa.setup_button") or "Set Up MFA") .. [[
      </button>
      <button id="btn-mfa-disable" class="btn btn-danger" style="display:none">
        <i class="fas fa-times"></i> ]] .. (i18n("mfa.disable_button") or "Disable MFA") .. [[
      </button>
    </div>

    <!-- MFA setup wizard (hidden until user clicks Set Up MFA) -->
    <div id="mfa-setup-section" style="display:none" class="mt-3">
      <hr>
      <h6>]] .. (i18n("mfa.setup_step1") or "Step 1: Scan this QR code with your authenticator app") .. [[</h6>
      <div class="text-center mb-3">
        <div id="mfa-qrcode" class="d-inline-block p-2 border bg-white"></div>
      </div>
      <p class="text-muted small">
        ]] .. (i18n("mfa.manual_entry") or "Or enter this secret manually:") .. [[
        <code id="mfa-secret-display" class="ms-1"></code>
      </p>
      <hr>
      <h6>]] .. (i18n("mfa.setup_step2") or "Step 2: Enter the 6-digit code to confirm") .. [[</h6>
      <div class="input-group mb-3" style="max-width:220px">
        <input type="text" id="mfa-confirm-code" class="form-control text-center"
               maxlength="6" pattern="[0-9]{6}" placeholder="000000"
               inputmode="numeric" autocomplete="one-time-code"> &nbsp;
        <button id="btn-mfa-enable" class="btn btn-success">
          ]] .. (i18n("mfa.enable_button") or "Enable MFA") .. [[
        </button>
      </div>
    </div>

    <!-- Disable MFA confirm (hidden) -->
    <div id="mfa-disable-confirm-section" style="display:none" class="mt-3">
      <hr>
      <p class="text-warning">]] .. (i18n("mfa.disable_warning") or "Enter your current TOTP code to confirm disabling MFA.") .. [[</p>
      <div class="input-group mb-3" style="max-width:220px">
        <input type="text" id="mfa-disable-code" class="form-control text-center"
               maxlength="6" pattern="[0-9]{6}" placeholder="000000"
               inputmode="numeric" autocomplete="one-time-code"> &nbsp;
        <button id="btn-mfa-disable-confirm" class="btn btn-danger">
          ]] .. (i18n("mfa.disable_confirm_button") or "Confirm Disable") .. [[
        </button>
      </div>
    </div>
  </div>
]])

-- WebAuthn/Passkeys Tab
print([[
  <div class='tab-pane' id='user-webauthn-tab'>
    <div id="webauthn_alert_placeholder"></div>
    <div class="mb-3">
      <p class="text-muted">]] .. (i18n("webauthn.description") or "Use biometric authentication (Touch ID, Face ID) or hardware security keys as a second factor to protect your account.") .. [[</p>
    </div>

    <div id="webauthn-creds-list" class="mb-3"></div>

    <button id="btn-webauthn-add" class="btn btn-primary">
      <i class="fas fa-plus"></i> ]] .. (i18n("webauthn.add_passkey") or "Add Passkey") .. [[
    </button>
  </div>
]])

print [[
  <script type='text/javascript'>

  $(document).ready(function() {

    $(`#btn-copy-token`).click(function() {
      
      const $this = $(this);
      const inputToken = document.querySelector('#input-token');
      inputToken.select();

      // copy the token to the clipboard
      document.execCommand("copy");

      // show a tooltip
      $this.tooltip({title: ']] print(i18n("copied")) print[[!', delay: {show: 50, hide: 300}});
      $this.tooltip('show');
      // destroy the tooltip after the hide event
      $this.on('hidden.bs.tooltip', function () {
        $this.tooltip('dispose');
      });
    });

    $(`#btn-generate_token`).click(async function(e) {

      const user = $(`#input-username`).val() || loggedUser;
      const response = await fetch(`${http_prefix}/lua/rest/v2/create/ntopng/api_token.lua`, {
        method: 'POST',
        body: JSON.stringify({username: user, csrf: ']] print(ntop.getRandomCSRFValue()) print [['}),
        headers: {
          'Content-Type': 'application/json; charset=utf-8'
        }
      });

      const data = await response.json();
      const token = data.rsp.api_token;
      $(`#input-token`).val(token);
      $(`#btn-copy-token`).show();

      $(this).removeAttr("disabled");
    });

  });

  $("#lifetime_unlimited").click(function() {
    $("#lifetime_selection_table label").attr("disabled", "disabled");
    $("#lifetime_selection_table input").attr("disabled", "disabled");
    $("#lifetime_limited").removeAttr("checked").prop("checked", false);
  });

  $("#lifetime_limited").click(function() {
    $("#lifetime_selection_table input").removeAttr("disabled");
    $("#lifetime_selection_table label").removeAttr("disabled");
    $("#lifetime_unlimited").removeAttr("checked").prop("checked", false);
  });

  function isValid(str) { /* return /^[\w%]+$/.test(str); */ return true; }
  function isValidPassword(str)   { return /]] print(getPasswordInputPattern()) print[[/.test(str); }
  function isDefaultPassword(str) { return /^admin$/.test(str); }

  var frmpassreset = $('#form_password_reset');
  frmpassreset.submit(function () {
    if(!isValidPassword($("#new_password_input").val())) {
      password_alert.error("]] print(i18n("invalid_password")) print[["); return(false);
    }
    if(isDefaultPassword($("#new_password_input").val())) {
      password_alert.error("Password is weak. Please choose a stronger password."); return(false);
    }
    if($("#new_password_input").val().length < 5) {
      password_alert.error("Password too short (< 5 characters)"); return(false);
    }
    if($("#new_password_input").val() != $("#confirm_new_password_input").val()) {
      password_alert.error("Passwords don't match"); return(false);
    }

    // Don't do any escape, form contain Unicode UTF-8 encoded chars
    // $('#old_password_input').val(escape($('#old_password_input').val()))
    // $('#new_password_input').val(escape($('#new_password_input').val()))
    // $('#confirm_new_password_input').val(escape($('#confirm_new_password_input').val()))

    $.ajax({
      type: frmpassreset.attr('method'),
      url: frmpassreset.attr('action'),
      data: frmpassreset.serialize(),
      success: function (data) {

        var response = jQuery.parseJSON(data);
        if(response.result == 0) {
          password_alert.success(response.message);
          const url = new URL(window.location);
          window.location.href = url.origin + url.pathname;

       } else
          password_alert.error(response.message);
    ]]

if(not is_admin) then
   print('$("old_password_input").text("");\n');
end

print [[
        $("new_password_input").text("");
        $("confirm_new_password_input").text("");
      }
    });
    return false;
  });

  var frmprefchange = $('#form_pref_change');

  frmprefchange.submit(function () {
    /* Set selected host pools into the hidden field */
    if ($("#edit_allowed_host_pools_select").length) {
      var selectedPools = ($("#edit_allowed_host_pools_select").val() || []).join(',');
      $("#edit_allowed_host_pools").val(selectedPools);
    }

    var ok = true;
    if($("#networks_input").val().length == 0) {
      password_alert.error("Network list not specified");
      ok = false;
    } else {
      var arrayOfStrings = $("#networks_input").val().split(",");

      for (var i=0; i < arrayOfStrings.length; i++) {
	if(!NtopUtils.is_network_mask(arrayOfStrings[i])) {
	   password_alert.error("Invalid network list specified ("+arrayOfStrings[i]+")");
	   ok = false;
	}
      }
    }
    if(ok) {
      $.ajax({
        type: frmprefchange.attr('method'),
        url: frmprefchange.attr('action'),
        data: frmprefchange.serialize(),
        success: function (response) {
          if(response.result == 0) {

            const destURL = new URL(window.location);
            destURL.searchParams.delete('user');

            password_alert.success(response.message);
            window.location.href= destURL.toString();
         } else
           password_alert.error(response.message);
        }
      });
    }

    return false;
   });
</script>

</div> <!-- closes "tab-content" -->
</div> <!-- closes "tabbable" -->
</div> <!-- modal-body -->

<script>

function reset_pwd_dialog(user) {
      $.getJSON(']] print(ntop.getHttpPrefix()) print[[/lua/admin/get_user_info.lua?username='+user, function(data) {

      $('.password_dialog_title').text(data.username);
      $('#password_dialog_username').val(data.username);
      $('#pref_dialog_username').val(data.username);
      $('#old_password_input').val('');
      $('#new_password_input').val('');
      $('#confirm_password_input').val('');
      $('#host_role_select').val(data.group);
      if(data.username === "admin")
        $('#host_role_select').attr("disabled", "disabled");
      else
        $('#host_role_select').removeAttr("disabled");
      toggleUserSettings();
      $('#networks_input').val(data.allowed_nets);
      $('#allowed_interface option[value="' + data.allowed_if_id + '"]').attr('selected','selected');


      if(data.language !== "")
        $('#user_language option[value="' + data.language + '"]').attr('selected','selected');
        
      $('#allow_pcap_download').prop('checked', data.allow_pcap_download === true ? true : false);
      $('#allow_historical_flows').prop('checked', data.allow_historical_flows === true ? true : false);
      $('#allow_alerts').prop('checked', data.allow_alerts === true ? true : false);

      if(data.host_pool_id) {
        $('#old_host_pool_id').val(data.host_pool_id);
        $('#host_pool_id option[value = '+data.host_pool_id+']').attr('selected','selected');
      }

      /* Restore allowed host pools selection */
      if ($("#edit_allowed_host_pools_select").length) {
        const poolIds = (data.allowed_host_pools && data.allowed_host_pools !== '')
          ? data.allowed_host_pools.split(',').map(function(p) { return p.trim(); })
          : [];
        $("#edit_allowed_host_pools_select").val(poolIds).trigger("change");
        $("#edit_allowed_host_pools").val(data.allowed_host_pools || '');
      }

     if (isAdministrator || loggedUser === data.username) {
        $(`[href="#user-token-tab"]`).show();
        $(`#input-username`).val(data.username);
        $(`#input-token`).val(data.api_token);

        if (data.api_token === "") {
          $(`#btn-copy-token`).hide();
          $(`#input-token`).val(']] print(i18n("manage_users.token_not_generated")) print[[');
        }
        else {
          $(`#btn-copy-token`).show();
        }
      }
      else {
        $(`#input-token`).val('');
        $(`#input-username`).val('');
        $(`[href="#user-token-tab"]`).hide();
      }

      $('#form_pref_change').show();
      $('#pref_part_separator').show();
      $('#password_alert_placeholder').html('');
      $('#add_user_alert_placeholder').html('');

      /* Update MFA tab status */
      updateMfaStatus(data.username, data.totp_enabled === true);

      /* Update WebAuthn/Passkeys tab status */
      if (typeof updateWebAuthnStatus === 'function') updateWebAuthnStatus(data.username);
    });

      return(true);
}

/* ---- MFA management helpers ---- */

var mfa_alert = {};
mfa_alert.error   = function(msg) { $('#mfa_alert_placeholder').html('<div class="alert alert-danger alert-dismissable">' + msg + '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>'); };
mfa_alert.success = function(msg) { $('#mfa_alert_placeholder').html('<div class="alert alert-success alert-dismissable">' + msg + '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>'); };
mfa_alert.clear   = function()    { $('#mfa_alert_placeholder').html(''); };

var _mfa_current_user = '';
var _mfa_enabled = false;
var _has_passkeys = false;
/* Enforce mutual exclusion: when MFA is on, disable Passkeys tab; when Passkeys
   exist, disable MFA tab. Both cannot be active at the same time. */
function syncAuthTabStates() {
  var $mfaTab = $('[href="#user-mfa-tab"]');
  var $passkeysTab = $('[href="#user-webauthn-tab"]');
  function disableTab($tab, msg) {
    /* pointer-events:none blocks mouseenter, so we wrap the anchor in a
       transparent overlay <span> that intercepts hover and shows the tooltip. */
    $tab.addClass('disabled')
        .attr('aria-disabled', 'true')
        .attr('tabindex', '-1')
        .css('pointer-events', 'none')
        .css('opacity', '0.5');
    if (msg) {
      var $li = $tab.closest('li.nav-item');
      if (!$li.find('.tab-disabled-overlay').length) {
        var $overlay = $('<span class="tab-disabled-overlay" style="position:absolute;inset:0;cursor:not-allowed;z-index:1;"></span>');
        $li.css('position', 'relative').append($overlay);
      }
      $li.find('.tab-disabled-overlay')
         .attr('data-bs-toggle', 'tooltip')
         .attr('data-bs-placement', 'bottom')
         .attr('title', msg);
      var overlayEl = $li.find('.tab-disabled-overlay')[0];
      if (overlayEl) {
        if (overlayEl._bsTooltip) { overlayEl._bsTooltip.dispose(); }
        overlayEl._bsTooltip = new bootstrap.Tooltip(overlayEl, { trigger: 'hover' });
      }
    }
  }

  function enableTab($tab) {
    $tab.removeClass('disabled')
        .removeAttr('aria-disabled')
        .removeAttr('tabindex')
        .css('pointer-events', '')
        .css('opacity', '');
    var $li = $tab.closest('li.nav-item');
    var overlayEl = $li.find('.tab-disabled-overlay')[0];
    if (overlayEl) {
      if (overlayEl._bsTooltip) { overlayEl._bsTooltip.dispose(); }
      $li.find('.tab-disabled-overlay').remove();
    }
  }

  var webauthn_available = window.isSecureContext && !!window.PublicKeyCredential;
  if (!webauthn_available) {
    disableTab($passkeysTab, ']] print(i18n("mfa.passkey_disabled_http")) print[[' );
    enableTab($mfaTab);
    return;
  }

  if (_mfa_enabled) {
    disableTab($passkeysTab, ']] print(i18n("mfa.passkey_disabled")) print[[' );
    enableTab($mfaTab);
  } else if (_has_passkeys) {
    disableTab($mfaTab, ']] print(i18n("mfa.passkey_enabled")) print[[' );
    enableTab($passkeysTab);
  } else {
    enableTab($mfaTab); enableTab($passkeysTab);
  }
}

function updateMfaStatus(username, enabled) {
  _mfa_current_user = username;
  _mfa_enabled = (enabled === true);
  $('#mfa-setup-section').hide();
  $('#mfa-disable-confirm-section').hide();
  mfa_alert.clear();
  syncAuthTabStates();
  if (enabled) {
    $('#mfa-status-badge').removeClass('bg-secondary').addClass('bg-success').text(']] print(i18n("mfa.status_enabled") or "Enabled") print[[');
    $('#mfa-status-text').text(']] print(i18n("mfa.status_enabled_desc") or "Two-factor authentication is active for this account.") print[[');
    $('#btn-mfa-setup').hide();
    $('#btn-mfa-disable').show();
  } else {
    $('#mfa-status-badge').removeClass('bg-success').addClass('bg-secondary').text(']] print(i18n("mfa.status_disabled") or "Disabled") print[[');
    $('#mfa-status-text').text(']] print(i18n("mfa.status_disabled_desc") or "Two-factor authentication is not enabled.") print[[');
    $('#btn-mfa-setup').show();
    $('#btn-mfa-disable').hide();
  }
}

$(document).ready(function() {

  $('#btn-mfa-setup').click(async function() {
    mfa_alert.clear();
    const resp = await fetch(`${http_prefix}/lua/admin/change_user_mfa.lua`, {
      method: 'POST',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: `action=generate_secret&username=${encodeURIComponent(_mfa_current_user)}&csrf=]] print(ntop.getRandomCSRFValue()) print[[`
    });
    const data = await resp.json();
    if (data.result !== 0) { mfa_alert.error(data.message); return; }

    $('#mfa-secret-display').text(data.secret);

    /* Render QR code using the qrcode npm package */
    const qrDiv = document.getElementById('mfa-qrcode');
    qrDiv.innerHTML = '';
    if (typeof QRCode !== 'undefined' && typeof QRCode.toCanvas === 'function') {
      const canvas = document.createElement('canvas');
      qrDiv.appendChild(canvas);
      QRCode.toCanvas(canvas, data.provisioning_uri, { width: 200, errorCorrectionLevel: 'M' });
    } else {
      /* Fallback: show the URI as text */
      qrDiv.innerHTML = '<small class="text-break" style="max-width:300px;display:block;">' + data.provisioning_uri + '</small>';
    }

    $('#mfa-setup-section').show();
    $('#mfa-confirm-code').val('').focus();
  });

  $('#btn-mfa-enable').click(async function() {
    const code = $('#mfa-confirm-code').val().trim();
    if (!/^[0-9]{6}$/.test(code)) { mfa_alert.error(']] print(i18n("mfa.enter_6_digits") or "Please enter a 6-digit code.") print[['); return; }

    const resp = await fetch(`${http_prefix}/lua/admin/change_user_mfa.lua`, {
      method: 'POST',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: `action=enable&username=${encodeURIComponent(_mfa_current_user)}&totp=${encodeURIComponent(code)}&csrf=]] print(ntop.getRandomCSRFValue()) print[[`
    });
    const data = await resp.json();
    if (data.result !== 0) { mfa_alert.error(data.message); return; }
    mfa_alert.success(']] print(i18n("mfa.enabled_success") or "MFA has been enabled successfully.") print[[');
    updateMfaStatus(_mfa_current_user, true);
  });

  $('#btn-mfa-disable').click(function() {
    $('#mfa-disable-confirm-section').show();
    $('#mfa-disable-code').val('').focus();
  });

  $('#btn-mfa-disable-confirm').click(async function() {
    const code = $('#mfa-disable-code').val().trim();
    const body_parts = [`action=disable&username=${encodeURIComponent(_mfa_current_user)}&csrf=]] print(ntop.getRandomCSRFValue()) print[[`];
    if (code !== '') body_parts.push(`totp=${encodeURIComponent(code)}`);

    const resp = await fetch(`${http_prefix}/lua/admin/change_user_mfa.lua`, {
      method: 'POST',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body_parts.join('&')
    });
    const data = await resp.json();
    if (data.result !== 0) { mfa_alert.error(data.message); return; }
    mfa_alert.success(']] print(i18n("mfa.disabled_success") or "MFA has been disabled.") print[[');
    updateMfaStatus(_mfa_current_user, false);
  });

});

/*
$('#password_reset_submit').click(function() {
  $('#form_password_reset').submit();
});
*/
</script>

<script>
(function() {
  var _webauthn_user = '';
  var wa_alert = {};
  wa_alert.error   = function(m) { document.getElementById('webauthn_alert_placeholder').innerHTML = '<div class="alert alert-danger alert-dismissable">' + m + '<button type="button" class="btn-close" data-bs-dismiss="alert"></button></div>'; };
  wa_alert.success = function(m) { document.getElementById('webauthn_alert_placeholder').innerHTML = '<div class="alert alert-success alert-dismissable">' + m + '<button type="button" class="btn-close" data-bs-dismiss="alert"></button></div>'; };
  wa_alert.clear   = function()  { document.getElementById('webauthn_alert_placeholder').innerHTML = ''; };

  function b64url_decode(str) {
    str = str.replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) str += '=';
    var bin = atob(str);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes.buffer;
  }

  function b64url_encode(buf) {
    var bytes = new Uint8Array(buf);
    var str = '';
    for (var i = 0; i < bytes.length; i++) str += String.fromCharCode(bytes[i]);
    return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }

  window.updateWebAuthnStatus = function(username) {
    _webauthn_user = username;
    wa_alert.clear();
    fetch(http_prefix + '/lua/admin/change_user_webauthn.lua?action=list&username=' + encodeURIComponent(username))
      .then(function(r) { return r.json(); })
      .then(function(data) {
        var list = document.getElementById('webauthn-creds-list');
        if (!list) return;
        if (!data.credentials || data.credentials.length === 0) {
          _has_passkeys = false;
          syncAuthTabStates();
          list.innerHTML = '<p class="text-muted">]] print(i18n("webauthn.no_creds") or "No passkeys registered.") print[[</p>';
          return;
        }
        var html = '<table class="table table-sm"><thead><tr><th>Name</th><th>Uses</th><th></th></tr></thead><tbody>';
        _has_passkeys = true;
        syncAuthTabStates();
        data.credentials.forEach(function(c) {
          html += '<tr><td>' + (c.name || 'Passkey') + '</td><td>' + (c.sign_count || 0) + '</td>' +
                  '<td><button class="btn btn-sm btn-danger btn-del-passkey" data-cred-id="' + c.id + '">]] print(i18n("webauthn.remove_passkey") or "Remove") print[[</button></td></tr>';
        });
        html += '</tbody></table>';
        list.innerHTML = html;
        document.querySelectorAll('.btn-del-passkey').forEach(function(btn) {
          btn.addEventListener('click', function() {
            if (!confirm('Remove this passkey?')) return;
            var cid = this.getAttribute('data-cred-id');
            fetch(http_prefix + '/lua/admin/change_user_webauthn.lua', {
              method: 'POST',
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'action=delete&username=' + encodeURIComponent(_webauthn_user) + '&cred_id=' + encodeURIComponent(cid) + '&csrf=]] print(ntop.getRandomCSRFValue()) print[['
            }).then(function(r) { return r.json(); }).then(function(d) {
              if (d.result === 0) { wa_alert.success(']] print(i18n("webauthn.removed") or "Passkey removed.") print[['); window.updateWebAuthnStatus(_webauthn_user); }
              else wa_alert.error(d.message);
            });
          });
        });
      });
  };

  document.addEventListener('DOMContentLoaded', function() {
    var addBtn = document.getElementById('btn-webauthn-add');
    if (!addBtn) return;
    addBtn.addEventListener('click', async function() {
      if (!window.isSecureContext || !window.PublicKeyCredential) { wa_alert.error(']] print(i18n("webauthn.not_supported") or "WebAuthn requires a secure context (HTTPS or localhost). Please access ntopng via HTTPS.") print[['); return; }
      wa_alert.clear();
      var _username = _webauthn_user || document.getElementById('password_dialog_username').value || loggedUser;
      if (!_username) { wa_alert.error('Missing username'); return; }
      try {
        var optResp = await fetch(http_prefix + '/lua/admin/change_user_webauthn.lua', {
          method: 'POST',
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'action=get_registration_options&username=' + encodeURIComponent(_username) + '&csrf=]] print(ntop.getRandomCSRFValue()) print[['
        });
        var opts = await optResp.json();
        if (opts.result !== 0) { wa_alert.error(opts.message); return; }

        var credName = prompt('Name for this passkey (e.g. "My iPhone"):', 'Passkey') || 'Passkey';

        var challengeBuf = b64url_decode(opts.challenge);
        var userIdBuf = new TextEncoder().encode(opts.user.id);
        var cred = await navigator.credentials.create({
          publicKey: {
            challenge: challengeBuf,
            rp: { name: opts.rp.name },
            user: { id: userIdBuf, name: opts.user.name, displayName: opts.user.displayName },
            pubKeyCredParams: opts.pubKeyCredParams,
            authenticatorSelection: opts.authenticatorSelection,
            attestation: opts.attestation,
            timeout: opts.timeout
          }
        });

        var completeResp = await fetch(http_prefix + '/lua/admin/change_user_webauthn.lua', {
          method: 'POST',
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: [
            'action=complete_registration',
            'username=' + encodeURIComponent(_username),
            'cred_name=' + encodeURIComponent(credName),
            'cred_id=' + encodeURIComponent(b64url_encode(cred.rawId)),
            'client_data=' + encodeURIComponent(b64url_encode(cred.response.clientDataJSON)),
            'att_obj=' + encodeURIComponent(b64url_encode(cred.response.attestationObject)),
            'challenge=' + encodeURIComponent(opts.challenge),
            'origin=' + encodeURIComponent(window.location.origin),
            'rp_id=' + encodeURIComponent(window.location.hostname),
            'csrf=]] print(ntop.getRandomCSRFValue()) print[['
          ].join('&')
        });
        var completeData = await completeResp.json();
        if (completeData.result === 0) {
          wa_alert.success(']] print(i18n("webauthn.registered") or "Passkey registered successfully!") print[[');
          window.updateWebAuthnStatus(_username);
        } else {
          wa_alert.error('Registration failed: ' + completeData.message);
        }
      } catch(e) {
        if (e.name !== 'NotAllowedError') wa_alert.error('Error: ' + e.message);
      }
    });
  });
})();
</script>

</div>
</div>
</div>
</div> <!-- password_dialog -->

			    ]]

