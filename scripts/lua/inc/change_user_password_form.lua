print [[

 <style type='text/css'>
.largegroup {
    width:500px
}
</style>
<div id="password_dialog" tabindex="-1" >
<h3 id="password_dialog_label">Change ]] print(_SESSION["user"]) print [[ Password <span id="password_dialog_title"></span></h3>

  <div id="password_alert_placeholder"></div>

<script>
  password_alert = function() {}
  password_alert.error =   function(message) { $('#password_alert_placeholder').html('<div class="alert alert-danger"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>');
 }
  password_alert.success = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-success"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>'); }
</script>

  <form id="form_password_reset" class="form-horizontal" method="post" action="]]  print(ntop.getHttpPrefix())  print[[/lua/admin/password_reset.lua" accept-charset="UTF-8">
			   ]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

local user = ""
if (_SESSION["user"] ~= nil) then
  user = _SESSION["user"]
end
print('<input id="password_dialog_username" type="hidden" name="username" value="' ..user.. '" />')

print [[
<div class="input-group">
<div class="input-group">
<label for="" class="control-label">Old Password</label>
<div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>  
  <input id="old_password_input" type="password" name="old_password" value="" class="form-control"  pattern="]] print(getPasswordInputPattern()) print[[" required>
</div>
</div>

<div class="input-group">
  <label for="" class="control-label">New Password</label>
<div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>  
  <input id="new_password_input" type="password" name="new_password" value="" class="form-control"  pattern="]] print(getPasswordInputPattern()) print[[" required>
</div>
</div>

<div class="input-group">
  <label for="" class="control-label">Confirm New Password</label>
<div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>  
  <input id="confirm_new_password_input" type="password" name="confirm_password" value="" class="form-control"  pattern="]] print(getPasswordInputPattern()) print[[" required>
</div>
</div>

<div class="input-group">&nbsp;</div>
  <button id="password_reset_submit" class="btn btn-primary btn-block">Change Password</button>
</div>

  </form>

]]

print [[<script>
  password_alert = function() {}
  password_alert.error   = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-danger"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>');  }
  password_alert.success = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-success"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>'); }
  var frmpassreset = $('#form_password_reset');
  frmpassreset.submit(function () {
    if(!isValidPassword($("#new_password_input").val())) {
      password_alert.error("Password contains invalid chars. Please use valid ISO8859-1 (latin1) letters and numbers"); return(false);
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
    // $('#new_password_input').val(escape($('#new_password_input').val()))
    // $('#confirm_new_password_input').val(escape($('#confirm_new_password_input').val()))

    $.ajax({
      type: frmpassreset.attr('method'),
      url: frmpassreset.attr('action'),
      data: frmpassreset.serialize(),
      success: function (data) {
        var response = jQuery.parseJSON(data);
        if (response.result == 0) {
          password_alert.success(response.message);
        }
        else {
          password_alert.error(response.message);
        }
        $("old_password_input").text("");
        $("new_password_input").text("");
        $("confirm_new_password_input").text("");
      }
    });

    return false;
  });

</script>

</div>
</div> <!-- personal password_dialog -->

			    ]]
