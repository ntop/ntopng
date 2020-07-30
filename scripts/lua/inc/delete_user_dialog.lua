print [[
<div id="delete_user_dialog" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="delete_user_dialog_label" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h3 id="delete_user_dialog_label">]] print(i18n("users.delete_user")) print[[</h3>
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">x</button>
      </div>

<div class="modal-body">

  <div id="delete_user_alert_placeholder"></div>

<script>
  delete_user_alert = function() {}
  delete_user_alert.error =   function(message) { $('#delete_user_alert_placeholder').html('<div class="alert alert-danger"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>');
 }
  delete_user_alert.success = function(message) { $('#delete_user_alert_placeholder').html('<div class="alert alert-success"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>'); }
  delete_user_alert.warning = function(message) { $('#delete_user_alert_placeholder').html('<div class="alert alert-warning">' + message + '</div>'); }
</script>

  <form id="form_delete_user" class="form-horizontal" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/rest/v1/delete/ntopng/user.lua">
			      ]]
print('<input name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

local location_href = ntop.getHttpPrefix().."/lua/admin/users.lua"

print [[
    <input id="delete_dialog_username" type="hidden" name="username" value="" />
  </form>

<script>
  var frmdeluser = $('#form_delete_user');
  frmdeluser.submit(function () {
    $.ajax({
      type: frmdeluser.attr('method'),
      url: frmdeluser.attr('action'),
      data: frmdeluser.serialize(),
      success: function (data) {
        if (data.rc == 0) {
          delete_user_alert.success(data.rc_str); 
          window.location.href = ']] print(location_href) print[[';
        } else {
          delete_user_alert.error(data.rc_str);
        }
      }, error: function (data) {
        delete_user_alert.error("]] print(i18n("users.delete_user_error")) print[[");
      }
    });
    return false;
  });
</script>

</div> <!-- modal-body -->

<div class="modal-footer">
  <button class="btn btn-secondary btn-sm" data-dismiss="modal" aria-hidden="true">]] print(i18n("close")) print[[</button>
  <button id="delete_user_submit" class="btn btn-danger btn-sm">]] print(i18n("delete")) print[[</button>
</div>

<script>
$('#delete_user_submit').click(function() {
  $('#form_delete_user').submit();
});
</script>

</div>
</div>
</div> <!-- delete_user_dialog -->

			 ]]
