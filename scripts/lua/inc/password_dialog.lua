require("lua_utils")
require("prefs_utils")

local is_admin = isAdministrator()
local template = require("template_utils")

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
    <input id="password_dialog_username" type="hidden" name="username" value="" />

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
      <input id="old_password_input" type="password" name="old_password" value="" class="form-control" required>
  </div>
  </div>
   ]]
end

print [[
  <div class='form-group mb-3'>
    <label class='form-label' for="new_password_input">]] print(i18n("manage_users.new_password")) print[[</label>
    <div class='input-group mb-]] print(col_md_size) print[['>
        <span class="input-group-text"><i class="fas fa-lock"></i></span>
        <input id="new_password_input" type="password" name="new_password" value="" class="form-control" pattern="]] print(getPasswordInputPattern()) print[[" required>
    </div>
  </div>

  <div class='form-group mb-3'>
  <label class='form-label' class='form-label' for="confirm_new_password_input">]] print(i18n("manage_users.new_password_confirm")) print[[</label>
  <div class='input-group md-]] print(col_md_size) print[['>
        <span class="input-group-text"><i class="fas fa-lock"></i></span>
        <input id="confirm_new_password_input" type="password" name="confirm_password" value="" class="form-control" pattern="]] print(getPasswordInputPattern()) print[[" required>
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

  <div class='form-group mb-3'>
    <label class='form-label' for="networks_input">]] print(i18n("manage_users.allowed_networks")) print[[</label>
    <div class='input-group mb-6'>
      <input id="networks_input" type="text" name="allowed_networks" value="" class="form-control w-100" required>
    </div>
    <small>]] print(i18n("manage_users.allowed_networks_descr")) print[[ 192.168.1.0/24,172.16.0.0/16</small>
  </div>


    <div class="form-group mb-3 mb-6">
      <div class="form-check pl-0">]]

    print(template.gen("on_off_switch.html", {
     id = "allow_pcap_download",
     label = i18n("manage_users.allow_pcap_download_descr"),
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

print[[
  <div class='form-group mb-3'>
    <label class='form-label' for="user_language">]] print(i18n("language")) print[[</label>
    <div class='input-group mb-6'>
        <span class="input-group-text"><i class="fas fa-language" aria-hidden="true"></i></span>
      <select name="user_language" id="user_language" class="form-select">]]

for _, lang in ipairs(locales_utils.getAvailableLocales()) do
   print('<option value="'..lang["code"]..'">'..i18n("locales." .. lang["code"])..'</option>')
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
      password_alert.error("Password contains invalid chars. Please use valid ISO8859-1 (latin1) letters and numbers."); return(false);
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
      if(data.host_pool_id) {
        $('#old_host_pool_id').val(data.host_pool_id);
        $('#host_pool_id option[value = '+data.host_pool_id+']').attr('selected','selected');
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
    });

      return(true);
}

/*
$('#password_reset_submit').click(function() {
  $('#form_password_reset').submit();
});
*/
</script>

</div>
</div>
</div>
</div> <!-- password_dialog -->

			    ]]

