--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

local page_utils = require("page_utils")

local error_msg

if not isEmptyString(_POST["user_language"]) then
  ntop.changeUserLanguage(_SESSION["user"], _POST["user_language"])
end

if (_POST["new_password"] ~= nil) and (_SESSION["user"] == "admin") then
  local new_password = _POST["new_password"]
  local confirm_new_password = _POST["confirm_password"]

  if new_password ~= confirm_new_password then
    error_msg = i18n("login.password_mismatch")
  elseif new_password == "admin" then
    error_msg = i18n("login.password_not_valid")
  else
    ntop.resetUserPassword(_SESSION["user"], "admin", "", unescapeHTML(new_password))
    ntop.setCache("ntopng.prefs.admin_password_changed", "1")

    print(ntop.httpRedirect(_GET["referrer"] or "/"))
    return
  end
end

sendHTTPContentTypeHeader('text/html')


page_utils.print_header()

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

	 <form role="form" data-bs-toggle="validator" class="form-signin" method="POST">
	 <h2 class="form-signin-heading" style="font-weight: bold;">]] print(i18n("login.change_password")) print[[</h2>
   <p>]] print(i18n("login.must_change_password")) print[[</p>
]]

if error_msg ~= nil then
   print[[<div class="alert alert-danger alert-dismissable">
            ]] print(error_msg) print[[.
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
          </div>]]
end

print[[
  <div class="form-group mb-3 has-feedback">
      <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
      <input type="password" class="form-control" name="new_password" placeholder="]] print(i18n("login.password")) print[[" pattern="]] print(getPasswordInputPattern()) print[[" required>
      <input type="password" class="form-control" name="confirm_password" placeholder="]] print(i18n("login.confirm_password")) print[[" pattern="]] print(getPasswordInputPattern()) print[[" required>
  </div>

  ]]

print[[
    <label class='form-label' for="user_language">]] print(i18n("language")) print[[</label>
    <div class="input-group mb-6">
	<span class="input-group-text"><i class="fas fa-language" aria-hidden="true"></i></span>
      <select id="user_language" name="user_language" class="form-select">]]

for _, lang in ipairs(locales_utils.getAvailableLocales()) do
   print('<option value="'..lang["code"]..'">'..i18n("locales." .. lang["code"])..'</option>')
end

print[[
      </select>
    </div>
]]

print[[
        <br>
        <div class="d-grid gap-2">
          <button class="btn btn-lg btn-primary disabled btn-block" type="submit">]] print(i18n("login.change_password")) print[[</button>
        </div>
  	<div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
        <small>
        <p><a href="]] print(ntop.getHttpPrefix()) print[[logout.lua">]] print(i18n("login.logout")) print[[</a></p>
      <p>]] print(i18n("login.donation", {product=info["product"], donation_url="http://shop.ntop.org"})) print[[
          </p>

      <p>]] print(info["copyright"]) print [[<br> ]] print(i18n("login.license", {product=info["product"], license="GPLv3", license_url="http://www.gnu.org/copyleft/gpl.html"})) print[[</p>
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
