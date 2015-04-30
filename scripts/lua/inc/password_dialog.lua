
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
  <button type="button" class="close" data-dismiss="modal" aria-hidden="true">x</button>
  <h3 id="password_dialog_label">Manage User <span id="password_dialog_title"></span></h3>
</div>

<div class="modal-body">
  <div id="password_alert_placeholder"></div>

<script>
  password_alert = function() {}
  password_alert.error   = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-danger"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>');  }
  password_alert.success = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-success"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>'); }
</script>

  <form id="form_password_reset" class="form-horizontal" method="get" action="password_reset.lua">
]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[
    <input id="password_dialog_username" type="hidden" name="username" value="" />

<div class="control-group">

   ]]

user_group = ntop.getUserGroup()
if(user_group ~= "administrator") then
print [[
<div class="control-group">
<label for="" class="control-label">Old User Password</label>
<div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
  <input id="old_password_input" type="password" name="old_password" value="" class="form-control">
</div>
</div>
   ]]
end

print [[
<div class="control-group">
  <label for="" class="control-label">New User Password</label>
<div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
  <input id="new_password_input" type="password" name="new_password" value="" class="form-control">
</div>
</div>

<div class="control-group">
  <label for="" class="control-label">Confirm New User Password</label>
<div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
  <input id="confirm_new_password_input" type="password" name="confirm_new_password" value="" class="form-control">
</div>
</div>

<div class="control-group">&nbsp;</div>
  <button id="password_reset_submit" class="btn btn-primary btn-block">Change User Password</button>
</div>

  </form>

]]

if(user_group=="administrator") then

print [[
<div id="pref_part_separator"><hr/></div>
<form id="form_pref_change" class="form-horizontal" method="get" action="change_user_prefs.lua" role="form">
  <input id="pref_dialog_username" type="hidden" name="username" value="" />
<div class="control-group">

  <div class="control-group">
    <label class="input-label">User Role</label>
    <div class="controls">
      <select id="host_role_select" name="host_role" class="form-control">
                <option value="standard">Non Privileged User</option>
                <option value="administrator">Administrator</option>
      </select>
    </div>
  </div>


  <div class="control-group">
    <label class="control-label">Allowed Networks</label>
<div class="input-group"><span class="input-group-addon"><span class="glyphicon glyphicon-tasks"></span></span>
     <input id="networks_input" type="text" name="networks" value="" class="form-control">
    </div>
     <small>Comma separated list of networks this user can view. Example: 192.168.1.0/24,172.16.0.0/16</small>
  </div>

<div class="control-group">&nbsp;</div>

  <button id="pref_change" class="btn btn-primary btn-block">Change User Preferences</button>

</div>
  </form>
]]
end

print [[<script>
  var frmpassreset = $('#form_password_reset');

  frmpassreset.submit(function () {
    if($("#new_password_input").val().length < 5) { password_alert.error("Password too short (< 5 characters)"); return(false); }
    if($("#new_password_input").val() != $("#confirm_new_password_input").val()) { password_alert.error("Passwords don't match"); return(false); }

    $.ajax({
      type: frmpassreset.attr('method'),
      url: frmpassreset.attr('action'),
      data: frmpassreset.serialize(),
      success: function (data) {
        var response = jQuery.parseJSON(data);
        if(response.result == 0) {
          password_alert.success(response.message);
   	  window.location.href = 'users.lua';
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

  if(ok) {
    $.ajax({
      type: frmprefchange.attr('method'),
      url: frmprefchange.attr('action'),
      data: frmprefchange.serialize(),
      success: function (response) {
        if(response.result == 0) {
          password_alert.success(response.message);
   	  window.location.href = 'users.lua';
       } else
          password_alert.error(response.message);
      }
    });
   }

    return false;   
   });
</script>

</div> <!-- modal-body -->

<div class="modal-footer">
  <button class="btn btn-default btn-sm" data-dismiss="modal" aria-hidden="true">Close</button>
</div>

<script>

function reset_pwd_dialog(user) {
      $.getJSON('get_user_info.lua?user='+user, function(data) {
      $('#password_dialog_title').text(data.username);
      $('#password_dialog_username').val(data.username);
      $('#pref_dialog_username').val(data.username);
      $('#old_password_input').val('');
      $('#new_password_input').val('');
      $('#confirm_password_input').val('');
      $('#host_role_select option[value = '+data.group+']').attr('selected','selected');
      $('#networks_input').val(data.allowed_nets);

      $('#form_pref_change').show();
      $('#pref_part_separator').show();
      $('#password_alert_placeholder').html('');
      $('#add_user_alert_placeholder').html('');
    });

      return(true);
}

$('#password_reset_submit').click(function() {
  $('#form_password_reset').submit();
});
</script>

</div>
</div>
</div> <!-- password_dialog -->

			    ]]

