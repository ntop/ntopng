require("lua_utils")
local host_pools_utils = require 'host_pools_utils'
require("prefs_utils")

local messages = {ntopng=ternary(ntop.isnEdge(), i18n("nedge.add_system_user"), i18n("login.add_web_user")), captive_portal=i18n("login.add_captive_portal_user")}

local add_user_msg = messages["ntopng"]
local captive_portal_user = false
if is_captive_portal_active then
   if _GET["captive_portal_users"] ~= nil then
      add_user_msg = messages["captive_portal"]
      captive_portal_user = true
   end
end

print [[
<div id="add_user_dialog" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="add_user_dialog_label" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
  <button type="button" class="close" data-dismiss="modal" aria-hidden="true">x</button>
  <h3 id="add_user_dialog_label">]]print(add_user_msg)print[[</h3>
</div>

<div class="modal-body">

  <div id="add_user_alert_placeholder"></div>

<script>
  add_user_alert = function() {}
  add_user_alert.error =   function(message, no_close) { $('#add_user_alert_placeholder').html('<div class="alert alert-danger">' + (no_close ? '' : '<button type="button" class="close" data-dismiss="alert">x</button>') + message + '</div>');
 }
  add_user_alert.success = function(message) { $('#add_user_alert_placeholder').html('<div class="alert alert-success"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>'); }

</script>

 <form data-toggle="validator" id="form_add_user" class="form-inline" method="post" action="add_user.lua" accept-charset="UTF-8">
			   ]]

print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[

<div class="row">
    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("login.username")) print[[</label>
      <div class="input-group">
        <span class="input-group-addon"><i class="fa fa-user-circle-o" aria-hidden="true"></i></span>
        <input id="username_input" type="text" name="username" value="" class="form-control" pattern="^[\w]{1,}$" required>
      </div>
    </div>

    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("users.full_name")) print[[</label>
      <div class="input-group">
        <span class="input-group-addon"><i class="fa fa-user" aria-hidden="true"></i></span>
        <input id="full_name_input" type="text" name="full_name" value="" class="form-control">
      </div>
    </div>
</div>

<br>

<div class="row">
    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("login.password")) print[[</label>
      <div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
        <input id="password_input" type="password" name="password" value="" class="form-control"  pattern="]] print(getPasswordInputPattern()) print[[" required>
      </div>
  </div>

    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("login.confirm_password")) print[[</label>
      <div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
        <input id="confirm_password_input" type="password" name="confirm_password" value="" class="form-control" pattern="]] print(getPasswordInputPattern()) print[[" required>
      </div>
    </div>
</div>

<br>

]]

if captive_portal_user == false then
   print[[
<div class="row">
    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("manage_users.user_role")) print[[</label>
      <div class="input-group" style="width:100%;">
        <select id="host_role_select" name="user_role" class="form-control" style="width:100%;">
          <option value="unprivileged">]] print(i18n("manage_users.non_privileged_user")) print[[</option>
          <option value="administrator">]] print(i18n("manage_users.administrator")) print[[</option>
        </select>
      </div>
  </div>

    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("manage_users.allowed_interface")) print[[</label>
      <div class="input-group" style="width:100%;">
        <select name="allowed_interface" id="allowed_interface" class="form-control">
          <option value="">]] print(i18n("manage_users.any_interface")) print[[</option>
]]

   for _, interface_name in pairsByValues(interface.getIfNames(), asc) do
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
      <label class="form-label">]] print(i18n("manage_users.allowed_networks")) print[[</label>
      <div class="input-group"><span class="input-group-addon"><span class="glyphicon glyphicon-tasks"></span></span>
        <input id="allowed_networks_input" type="text" name="allowed_networks" value="" class="form-control">
      </div>
      <small>]] print(i18n("manage_users.allowed_networks_descr")) print[[: 192.168.1.0/24,172.16.0.0/16</small>
    </div>
</div>]]

else -- a captive portal user is being added
   print[[

<div class="row">
    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("host_config.host_pool")) print[[</label>
      <div class="input-group" style="width:100%;">
        <select name="host_pool_id" id="host_pool_id" class="form-control">

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
      <input id="host_role" name="user_role" type="hidden" value="captive_portal" />
      <input id="allowed_networks_input" name="allowed_networks" type="hidden" value="0.0.0.0/0,::/0" />
      <input id="allowed_interface" name="allowed_interface" type="hidden" value="]] print(tostring(getInterfaceId(ifname))) print[[" />
    </div>

    <div class="form-group col-md-6 has-feedback">
      <label class="form-label">]] print(i18n("manage_users.authentication_lifetime")) print[[</label>
      <div class="input-group">
        <label class="radio-inline"><input type="radio" id="add_lifetime_unlimited" name="lifetime_unlimited" checked>]] print(i18n("manage_users.unlimited")) print[[</label>
        <label class="radio-inline"><input type="radio" id="add_lifetime_limited" name="lifetime_limited">]] print(i18n("manage_users.expires_after")) print[[</label>
      </div>
      <!-- optionally allow to specify a certain number of days
      <input id="add_lifetime_days" name="lifetime_days" type="number" min="1" max="100" value="" class="form-control pull-right text-right" style="display: inline; width: 8em; padding-right: 1em;" disabled required>
      -->
    </div>
</div>

<div class="row">
    <div class="form-group col-md-6 has-feedback">
    </div>

    <div class="col-md-6 has-feedback text-center">

      <table class="form-group" id="add_lifetime_selection_table">
        <tr>

          <td style="vertical-align:top;">
]]
   --   require("prefs_utils")
   local res = prefsResolutionButtons("hd", 3600)
   print[[
          </td>
          <td style="padding-left: 2em;">
        <input class="form-control text-right" style="display:inline; width:5em; padding-right:1em;" name="lifetime_secs" id="add_lifetime_secs" type="number" data-min="3600" value="]] print(tostring(res)) print[[">
          </td>
        </tr>
      </table>
    </div>
</div>

<div class="row">
  <div class='col-md-6'>
    <small>]] print(i18n("manage_users.the_host_pool_associated")) print[[.</small>
  </div>
  <div class='col-md-6'>
    <small>]] print(i18n("manage_users.the_auth_can_be_perpetual")) print[[.</small>
  </div>
</div>

]]

if no_pools then
  print[[
    <script>
      $(function() {
        add_user_alert.error("]] print(i18n("manage_users.no_host_pools", {url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=pools#create"})) print[[.", true);
        $("#add_user_dialog").find("input,select,button[type='submit']").attr("disabled", "disabled");
      });
    </script>
  ]]
end

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
      <button type="submit" id="add_user_submit" class="btn btn-primary btn-block">]] print(i18n("manage_users.add_new_user")) print[[</button>
    </div>
</div>

</form>
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
]]

if captive_portal_user == false then
   -- network validation only for captive portal users
   print[[
    if($("#allowed_networks_input").val().length == 0) {
      add_user_alert.error("Network list not specified");
      return(false);
    } else {
      var arrayOfStrings = $("#allowed_networks_input").val().split(",");
      for (var i=0; i < arrayOfStrings.length; i++) {
        if(!is_network_mask(arrayOfStrings[i])) {
          add_user_alert.error("Invalid network list specified ("+arrayOfStrings[i]+")");
          return(false);
        }
      }
    }]]
end

local location_href = ntop.getHttpPrefix().."/lua/admin/users.lua"
if captive_portal_user then
   location_href = location_href.."?captive_portal_users=1"
end

print[[
    $.getJSON(']]  print(ntop.getHttpPrefix())  print[[/lua/admin/validate_new_user.lua?username='+$("#username_input").val()+"&allowed_networks="+$("#allowed_networks_input").val(), function(data){
      if (!data.valid) {
        add_user_alert.error(data.msg);
      } else {
]]

if captive_portal_user == true then
  print[[
        /* Converts expire resolution into appropriate value */
        resol_selector_finalize(frmadduser);]]
end

print[[
        $.ajax({
          type: frmadduser.attr('method'),
          url: frmadduser.attr('action'),
          data: frmadduser.serialize(),
          success: function (data) {
          var response = jQuery.parseJSON(data);
          if (response.result == 0) {
            add_user_alert.success(response.message);
            window.location.href = ']] print(location_href) print[[';
          } else {
            add_user_alert.error(response.message);
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

</div>
</div>
</div> <!-- add_user_dialog -->

		      ]]
