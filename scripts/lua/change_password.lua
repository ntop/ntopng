--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

local error_msg

if (_POST["new_password"] ~= nil) and (_SESSION["user"] == "admin") then
  local new_password = _POST["new_password"]
  local confirm_new_password = _POST["confirm_password"]

  if new_password ~= confirm_new_password then
    error_msg = "Passwords do not match"
  elseif new_password == "admin" then
    error_msg = "Please specify a different password"
  else
    ntop.resetUserPassword(_SESSION["user"], "admin", "", unescapeHTML(new_password))
    ntop.setCache("ntopng.prefs.admin_password_changed", "1")

    print(ntop.httpRedirect(_GET["referrer"] or "/"))
    return
  end
end

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
info = ntop.getInfo()

print [[
  <div class="container-narrow">



 <style type="text/css">
      body {
        padding-top: 40px;
        padding-bottom: 40px;
        background-color: #f5f5f5;
   }

      .form-signin {
        max-width: 350px;
        padding: 9px 29px 29px;
        margin: 0 auto 20px;
        background-color: #fff;
        border: 1px solid #e5e5e5;
        -webkit-border-radius: 5px;
           -moz-border-radius: 5px;
                border-radius: 5px;
          -webkit-box-shadow: 0 1px 2px rgba(0,0,0,.05);
       -moz-box-shadow: 0 1px 2px rgba(0,0,0,.05);
      box-shadow: 0 1px 2px rgba(0,0,0,.05);
   }
      .form-signin .form-signin-heading,
      .form-signin .checkbox {
        margin-bottom: 10px;
      }
      .form-signin input[type="text"],
      .form-signin input[type="password"] {
        font-size: 16px;
        height: auto;
        margin-bottom: 15px;
        padding: 7px 9px;
      }

    </style>

<div class="container">

	 <form role="form" data-toggle="validator" class="form-signin" method="POST">
	 <h2 class="form-signin-heading" style="font-weight: bold;">Change Password</h2>
   <p>Default admin password must be changed. Please enter a new password below.</p>
]]

if error_msg ~= nil then
   print[[<div class="alert alert-danger alert-dismissable">
            <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>
            ]] print(error_msg) print[[.
          </div>]]
end

print[[
  <div class="form-group has-feedback">
      <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
      <input type="password" class="form-control" name="new_password" placeholder="Password" pattern="]] print(getPasswordInputPattern()) print[[" required>
      <input type="password" class="form-control" name="confirm_password" placeholder="Confirm Password" pattern="]] print(getPasswordInputPattern()) print[[" required>
  </div>

  ]]

print[[
    <button class="btn btn-lg btn-primary btn-block" type="submit">Change Password</button>
  	<div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
        <small>
        <p><a href="]] print(ntop.getHttpPrefix()) print[[logout.lua">Logout</a></p>
      <p>If you find ]] print(info["product"]) print [[ useful, please support us by making a small <A href="http://shop.ntop.org">donation</A>. Your funding will help to run and foster the development of this project. Thank you.
          </p>

      <p>]] print(info["copyright"]) print [[<br> ]] print(info["product"]) print [[ is released under <A HREF="http://www.gnu.org/copyleft/gpl.html">GPLv3</A>.</p>
        </small>
      </div>
    </div>
  </form>

<script>
  $("input:text:visible:first").focus();
  $('#form_add_user').validator()
</script>

</div> <!-- /container -->

</body>
</html>
]]
