require("lua_utils")
local template = require "template_utils"
require("prefs_utils")

local messages = {ntopng=ternary(ntop.isnEdge(), i18n("nedge.add_system_user"), i18n("login.add_web_user"))}

local add_user_msg = messages["ntopng"]

print [[
<div id="add_user_dialog" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="add_user_dialog_label" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
	<h5 class='modal-title' id="add_user_dialog_label">]]print(add_user_msg)print[[</h5>
  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <form data-bs-toggle="validator" id="form_add_user" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/rest/v2/add/ntopng/user.lua" accept-charset="UTF-8">
<div class="modal-body">

  <div id="add_user_alert_placeholder"></div>

<script type="text/javascript">
  add_user_alert = function() {}
  add_user_alert.error =   function(message, no_close) { $('#add_user_alert_placeholder').html('<div class="alert alert-dismissible alert-danger">' + message + (no_close ? '' : '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>') + '</div>');
 }
  add_user_alert.success = function(message) { $('#add_user_alert_placeholder').html('<div class="alert alert-success">' + message); }

</script>

			   ]]

print('<input name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[
  <div class="form-group mb-3">
    <label for="username_input">]] print(i18n("login.username")) print[[</label>
    <div class="input-group mb-6">
	<span class="input-group-text"><i class="fas fa-user-circle" aria-hidden="true"></i></span>
      <input id="username_input" type="text" name="username" value="" class="form-control" pattern="^[\w]{1,}$" required>
    </div>
    </div>
    <div class="form-group mb-3">

    <label for="full_name_input">]] print(i18n("users.full_name")) print[[</label>
    <div class="input-group mb-6">
	<span class="input-group-text"><i class="fas fa-user" aria-hidden="true"></i></span>
      <input id="full_name_input" type="text" name="full_name" value="" class="form-control">
    </div>
</div>

<div class="form-group mb-3">
    <label for="password_input">]] print(i18n("login.password")) print[[</label>
    <div class="input-group mb-6">
	<span class="input-group-text"><i class="fas fa-lock"></i></span>
      <input id="password_input" type="password" name="password" value="" class="form-control"  pattern="]] print(getPasswordInputPattern()) print[[" required>
    </div>
</div>

<div class="form-group mb-3">
    <label for="confirm_password_input">]] print(i18n("login.confirm_password")) print[[</label>
    <div class="input-group mb-6">
	<span class="input-group-text"><i class="fas fa-lock"></i></span>
      <input id="confirm_password_input" type="password" name="confirm_password" value="" class="form-control" pattern="]] print(getPasswordInputPattern()) print[[" required>
    </div>
</div>

<div class="form-group mb-3">
    <label for="user_role">]] print(i18n("manage_users.user_role")) print[[</label>
    <div class="input-group mb-6">
	<select id="user_role" name="user_role" class="form-select" style="width:100%;">
	  <option value="unprivileged">]] print(i18n("manage_users.non_privileged_user")) print[[</option>
	  <option value="administrator">]] print(i18n("manage_users.administrator")) print[[</option>
	</select>
    </div>
  </div>

    <div id="unprivileged_input">

  <div class="form-group mb-3">
    <label for="allowed_interface_input">]] print(i18n("manage_users.allowed_interface")) print[[</label>
    <div class="input-group mb-6">
	<select id="allowed_interface_input" name="allowed_interface" class="form-select ">
	  <option value="">]] print(i18n("manage_users.any_interface")) print[[</option>
]]

   for _, interface_name in pairsByValues(interface.getIfNames(), asc) do
      print('<option value="'..getInterfaceId(interface_name)..'"> '..getHumanReadableInterfaceName(interface_name)..'</option>')
   end
   print[[
	</select>
    </div>
    </div>

  <div class="form-group mb-3">
    <label for="allowed_networks_input">]] print(i18n("manage_users.allowed_networks")) print[[</label>
    <div class="input-group mb-6">
      <input id="allowed_networks_input" type="text" name="allowed_networks" value="" class="form-control">
      <small>]] print(i18n("manage_users.allowed_networks_descr")) print[[: 192.168.1.0/24,172.16.0.0/16</small>
    </div>
  </div>

    <div class="form-group mb-3">
      <div class="form-check">]]

   print(template.gen("on_off_switch.html", {
     id = "allow_pcap_download",
     label = i18n("manage_users.allow_pcap_download_descr"),
   }))

   print[[
      </div>
    </div>

    </div>

    <script>
    $("#user_role").change(function() {
      if ($(this).val() == "unprivileged")
        $('#unprivileged_input').show();
      else
        $('#unprivileged_input').hide();
    });
    </script>
]]

  print[[
    <div class="form-group mb-3">

    <label for="user_language">]] print(i18n("language")) print[[</label>
    <div class="input-group mb-3">
      <span class="input-group-text"><i class="fas fa-language" aria-hidden="true"></i></span>
      <select id="user_language" name="user_language" class="form-select">]]

  for _, lang in ipairs(locales_utils.getAvailableLocales()) do
     print('<option value="'..lang["code"]..'">'..i18n("locales." .. lang["code"])..'</option>')
  end

  print[[
      </select>
    </div>
    </div>
]]

print[[    

<script>

  $("#add_lifetime_selection_table label").attr("disabled", "disabled");
  $("#add_lifetime_selection_table input").attr("disabled", "disabled");

  $("#add_lifetime_unlimited").click(function(){
    $("#add_lifetime_selection_table label").attr("disabled", "disabled");
    $("#add_lifetime_selection_table input").attr("disabled", "disabled");
    $("#add_lifetime_limited").removeAttr("checked").prop("checked", false);
  });

  $("#add_lifetime_limited").click(function() {
    $("#add_lifetime_selection_table label").removeAttr("disabled");
    $("#add_lifetime_selection_table input").removeAttr("disabled");
    $("#add_lifetime_unlimited").removeAttr("checked").prop("checked", false);
  });

  var frmadduser = $('#form_add_user');

  function resetAddUserForm() {
	$("#username_input").val("");
	$("#full_name_input").val("");
	$("#password_input").val("");
	$("#confirm_password_input").val("");
	$("#allowed_networks_input").val("0.0.0.0/0,::/0");
  }

  resetAddUserForm();

  frmadduser.submit(function () {
    /* Avoid submitting an invalid form */
    if(!$("#form_add_user")[0].checkValidity())
      return(false);

    if(!isValidPassword($("#password_input").val())) {
      add_user_alert.error("Password contains invalid chars. Please use valid ISO8859-1 (latin1) letters and numbers.");
      return(false);
    }

    if(isDefaultPassword($("#password_input").val())) {
      add_user_alert.error("Password is weak. Please choose a stronger password.");
      return(false);
    }

    if(!isValid($("#username_input").val())) {
      add_user_alert.error("Username must contain only letters and numbers");
      return(false);
    }

    if($("#username_input").val().length < 5) {
      add_user_alert.error("Username too short (5 or more characters)");
      return(false);
    }

    if($("#password_input").val().length < 5) {
      add_user_alert.error("Password too short (5 or more characters)");
      return(false);
    }

    if($("#password_input").val() !=  $("#confirm_password_input").val()) {
      add_user_alert.error("Password don't match");
      return(false);
    }

    // Don't do any escape, form contain Unicode UTF-8 encoded chars
    // ('#password_input').val(escape($('#password_input').val()))
    // $('#confirm_password_input').val(escape($('#confirm_password_input').val()))
    if($("#allowed_networks_input").val().length == 0) {
      add_user_alert.error("Network list not specified");
      return(false);
    } else {
      var arrayOfStrings = $("#allowed_networks_input").val().split(",");
      for (var i=0; i < arrayOfStrings.length; i++) {
	if(!NtopUtils.is_network_mask(arrayOfStrings[i])) {
	  add_user_alert.error("Invalid network list specified ("+arrayOfStrings[i]+")");
	  return(false);
	}
      }
    }]]


local location_href = ntop.getHttpPrefix().."/lua/admin/users.lua"

print[[
    $.getJSON(']]  print(ntop.getHttpPrefix())  print[[/lua/admin/validate_new_user.lua?username='+$("#username_input").val()+"&allowed_networks="+$("#allowed_networks_input").val(), function(data){
      if (!data.valid) {
	add_user_alert.error(data.msg);
      } else {
	$.ajax({
	  type: frmadduser.attr('method'),
	  url: frmadduser.attr('action'),
	  data: frmadduser.serialize(),
	  success: function (data) {
	  if (data.rc == 0) {
	    add_user_alert.success(data.rc_str);
	    window.location.href = ']] print(location_href) print[[';
	  } else {
	    add_user_alert.error(data.rc_str);
	  }
	  frmadduser[0].reset();
	}
      });
     }
   });
   return false;
});
</script>

</div> <!-- modal-body -->
<div class='modal-footer'>
      <button type="submit" id="add_user_submit" class="btn btn-primary btn-block">]] print(i18n("manage_users.add_new_user")) print[[</button>
</div>
</form>
</div>
</div>
</div> <!-- add_user_dialog -->

		      ]]
