require("lua_utils")
local host_pools_utils = require 'host_pools_utils'
require("prefs_utils")

print [[

 <style type='text/css'>
.largegroup {
    width:500px
}
</style>
<div id="password_dialog" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="password_dialog_label" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
  <button type="button" class="close" data-dismiss="modal" aria-hidden="true"><i class="fa fa-times"></i></button>
  <h3 id="password_dialog_label">]] print(i18n("manage_users.manage_user_x", {user=[[<span id="password_dialog_title"></span>]]})) print[[ </h3>
</div>

<div class="modal-body">

  <div class="tabbable"> <!-- Only required for left/right tabs -->
  <ul class="nav nav-tabs" role="tablist" id="edit-user-container">
    <li class="active"><a href="#change-password-dialog" role="tab" data-toggle="tab"> ]] print(i18n("login.password")) print[[ </a></li>
]]

local captive_portal_user = false
if is_captive_portal_active and _GET["captive_portal_users"] ~= nil then
   captive_portal_user = true
end

if(user_group=="administrator") then
   print[[<li><a href="#change-prefs-dialog" role="tab" data-toggle="tab"> ]] print(i18n("prefs.preferences")) print[[ </a></li>]]
end
   print[[
  </ul>
  <div class="tab-content">
  <div class="tab-pane active" id="change-password-dialog">

  <div id="password_alert_placeholder"></div>

<script>
  password_alert = function() {}
  password_alert.error   = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-danger"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>');  }
  password_alert.success = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-success"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>'); }
</script>

  <form data-toggle="validator" id="form_password_reset" class="form-inline" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/admin/password_reset.lua" accept-charset="UTF-8">
]]

   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[
    <input id="password_dialog_username" type="hidden" name="username" value="" />

<div class="control-group">
   ]]

local user_group = ntop.getUserGroup()
local col_md_size = "6"

print('<br><div class="row">')

if(user_group ~= "administrator") then
   col_md_size = "4"
print [[
  <div class='form-group col-md-]] print(col_md_size) print[[ has-feedback'>
      <label for="" class="control-label">]] print(i18n("manage_users.old_password")) print[[</label>
      <div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
        <input id="old_password_input" type="password" name="old_password" value="" class="form-control" required>
      </div>
  </div>
   ]]
end

print [[
  <div class='form-group has-feedback col-md-]] print(col_md_size) print[['>
      <label for="" class="control-label">]] print(i18n("manage_users.new_password")) print[[</label>
      <div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
        <input id="new_password_input" type="password" name="new_password" value="" class="form-control" pattern="]] print(getPasswordInputPattern()) print[[" required>
      </div>
  </div>

  <div class='form-group has-feedback col-md-]] print(col_md_size) print[['>
      <label for="" class="control-label">]] print(i18n("manage_users.new_password_confirm")) print[[</label>
      <div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
        <input id="confirm_new_password_input" type="password" name="confirm_password" value="" class="form-control" pattern="]] print(getPasswordInputPattern()) print[[" required>
      </div>
  </div>
</div>

<div><small>]] print(i18n("manage_users.allowed_passwd_charset")) print[[.  </small></div>

<br>

<div class="row">
    <div class="form-group col-md-12 has-feedback">
      <button id="password_reset_submit" class="btn btn-primary btn-block">]] print(i18n("manage_users.change_user_password")) print[[</button>
    </div>
</div>

</form>
</div> <!-- closes div "change-password-dialog" -->
]]

if(user_group=="administrator") then

print [[
</div>
<div class="tab-pane" id="change-prefs-dialog">

  <form data-toggle="validator" id="form_pref_change" class="form-inline" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/admin/change_user_prefs.lua">
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
  <input id="pref_dialog_username" type="hidden" name="username" value="" />

<br>
]]

if not captive_portal_user then
   print[[
<div class="row">
  <div class='col-md-6 form-group has-feedback'>
      <label class="input-label">]] print(i18n("manage_users.user_role")) print[[</label>
      <div class="input-group" style="width:100%;">
        <select id="host_role_select" name="user_role" class="form-control">
          <option value="unprivileged">]] print(i18n("manage_users.non_privileged_user")) print[[</option>
          <option value="administrator">]] print(i18n("manage_users.administrator")) print[[</option>
        </select>
      </div>
  </div>

  <div class='col-md-6 form-group has-feedback'>
      <label class="form-label">]] print(i18n("manage_users.allowed_interface")) print[[</label>
      <div class="input-group" style="width:100%;">
        <select name="allowed_interface" id="allowed_interface" class="form-control">
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
</div>

<br>

<div class="row">
    <div class="form-group col-md-12 has-feedback">
      <label class="control-label">]] print(i18n("manage_users.allowed_networks")) print[[</label>
      <div class="pull-right" style="margin-left:1em;">
        <label class="control-label"></label>
        <div>
          <button type="button" class="btn btn-default" onclick="$('#networks_input').val('0.0.0.0/0,::/0');">Default</button>
        </div>
      </div>
      <div class="input-group"><span class="input-group-addon"><span class="glyphicon glyphicon-tasks"></span></span>
        <input id="networks_input" type="text" name="allowed_networks" value="" class="form-control" required>
      </div>
      <small>]] print(i18n("manage_users.allowed_networks_descr")) print[[ 192.168.1.0/24,172.16.0.0/16</small>
    </div>
</div>

]]

else -- captive portal user
   print[[

<div class="row">
    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">Host Pool</label>
      <div class="input-group" style="width:100%;">
        <input id="old_host_pool_id" type="hidden" name="old_host_pool_id" value="" />
        <select name="host_pool_id" id="host_pool_id" class="form-control" disabled>

]]

   local pools = host_pools_utils.getPoolsList(getInterfaceId(ifname))
   local no_pools = true

   for _, pool in ipairs(pools) do
      if pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
        print('<option value="'.. pool.id ..'"> '.. pool.name ..'</option>')
        no_pools = false
      end
   end

   print[[
        </select>
      </div>
    </div>

    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("manage_users.authentication_lifetime")) print[[</label>
      <div class="input-group">
        <label class="radio-inline"><input type="radio" id="lifetime_unlimited" name="lifetime_unlimited" checked>]] print(i18n("manage_users.unlimited")) print[[</label>
        <label class="radio-inline"><input type="radio" id="lifetime_limited" name="lifetime_limited">]] print(i18n("manage_users.expires_after")) print[[</label>
      </div>
    </div>
</div>

<div class="row">
    <div class="form-group col-md-6 has-feedback">
    </div>

    <div class="col-md-6 has-feedback text-center">

      <table class="form-group" id="lifetime_selection_table">
        <tr>

          <td style="vertical-align:top;">
]]
   --   require("prefs_utils")
   local res = prefsResolutionButtons("hd", 3600, "user_lifetime_sel")
   print[[
          </td>
          <td style="padding-left: 2em;">
        <input class="form-control text-right" style="display:inline; width:5em; padding-right:1em;" name="lifetime_secs" id="lifetime_secs" type="number" data-min="3600" value="]] print(tostring(res)) print[[">
          </td>
        </tr>
      </table>
    </div>
</div>

]]
end

print[[

<br>

<div class="row">
    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("language")) print[[</label>
      <div class="input-group">
        <span class="input-group-addon"><i class="fa fa-language" aria-hidden="true"></i></span>
        <select name="user_language" id="user_language" class="form-control">]]

for _, lang in pairs(locales_utils.getAvailableLocales()) do
   print('<option value="'..lang["code"]..'">'..i18n("locales." .. lang["code"])..'</option>')
end

print[[
        </select>
      </div>
    </div>

    <div class="form-group col-md-6 has-feedback">
      <label class="form-label"></label>
      <div class="input-group">
      </div>
    </div>
</div>

<br>

<div class="row">
    <div class="form-group col-md-12 has-feedback">
      <button id="pref_change" class="btn btn-primary btn-block">]] print(i18n("manage_users.change_user_preferences")) print[[</button>
    </div>
</div>

<br>

  </form>
</div> <!-- closes div "change-prefs-dialog" -->
]]
end

print [[<script>
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
   	  // window.location.href = 'users.lua';
          window.location.href = window.location.href;

       } else
          password_alert.error(response.message);
    ]]

if(user_group ~= "administrator") then
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

]]

if not captive_portal_user then

print[[
  if($("#networks_input").val().length == 0) {
     password_alert.error("Network list not specified");
     ok = false;
  } else {
     var arrayOfStrings = $("#networks_input").val().split(",");

     for (var i=0; i < arrayOfStrings.length; i++) {
	if(!is_network_mask(arrayOfStrings[i])) {
	   password_alert.error("Invalid network list specified ("+arrayOfStrings[i]+")");
	   ok = false;
	}
     }
  }
]]

end

print[[
  if(ok) {
]]

if captive_portal_user == true then
  print[[
        /* Converts expire resolution into appropriate value */
        resol_selector_finalize(frmprefchange);]]
end

print[[
    $.ajax({
      type: frmprefchange.attr('method'),
      url: frmprefchange.attr('action'),
      data: frmprefchange.serialize(),
      success: function (response) {
        if(response.result == 0) {
          password_alert.success(response.message);
          window.location.href= window.location.href;
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

      $('#password_dialog_title').text(data.username);
      $('#password_dialog_username').val(data.username);
      $('#pref_dialog_username').val(data.username);
      $('#old_password_input').val('');
      $('#new_password_input').val('');
      $('#confirm_password_input').val('');
      $('#host_role_select option[value = '+data.group+']').attr('selected','selected');
      $('#networks_input').val(data.allowed_nets);
      $('#allowed_interface option[value="' + data.allowed_if_id + '"]').attr('selected','selected');

      if(data.language !== "") {
      $('#user_language option[value="' + data.language + '"]').attr('selected','selected');
      }
      if(data.host_pool_id) {
        $('#old_host_pool_id').val(data.host_pool_id);
        $('#host_pool_id option[value = '+data.host_pool_id+']').attr('selected','selected');
      }
      if(data.limited_lifetime) {
        $("#lifetime_selection_table label").removeAttr("disabled");
        $("#lifetime_selection_table input").removeAttr("disabled");
        $("#lifetime_limited").click();
        if (typeof resol_selector_set_value === "function")
          resol_selector_set_value("#lifetime_secs", data.limited_lifetime);
      } else {
        $("#lifetime_selection_table label").attr("disabled", "disabled");
        $("#lifetime_selection_table input").attr("disabled", "disabled");
        $("#lifetime_unlimited").click();
        if (typeof resol_selector_set_value === "function")
          resol_selector_set_value("#lifetime_secs", 3600);
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

