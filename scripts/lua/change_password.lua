--
-- (C) 2013-22 - ntop.org
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


page_utils.print_header(nil, true)

info = ntop.getInfo()

print [[

  <div id="particles-js"></div>
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

<div class="container input-group">

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

      <p>]] print(info["copyright"]) print [[<br> ]] print(i18n("login.license", {product=info["product"], license="GPLv3", license_url="http://www.gnu.org/copyleft/gpl.html"})) print[[</p>
        </small>
      </div>
    </div>
  </form>

<script>
particlesJS("particles-js", {"particles":{"number":{"value":20,"density":{"enable":true,"value_area":500}},"color":{"value":"#ccc"},"shape":{"type":"circle","stroke":{"width":0,"color":"#000000"},"polygon":{"nb_sides":5},"image":{"src":"img/github.svg","width":100,"height":100}},"opacity":{"value":1,"random":false,"anim":{"enable":false,"speed":1,"opacity_min":0.1,"sync":false}},"size":{"value":3,"random":true,"anim":{"enable":false,"speed":40,"size_min":0.1,"sync":false}},"line_linked":{"enable":true,"distance":150,"color":"#6e6e6e","opacity":0.4,"width":1},"move":{"enable":true,"speed":1,"direction":"none","random":false,"straight":false,"out_mode":"out","bounce":false,"attract":{"enable":false,"rotateX":600,"rotateY":1200}}},"interactivity":{"detect_on":"canvas","events":{"onhover":{"enable":false,"mode":"repulse"},"onclick":{"enable":false,"mode":"push"},"resize":true},"modes":{"grab":{"distance":400,"line_linked":{"opacity":1}},"bubble":{"distance":400,"size":40,"duration":2,"opacity":8,"speed":3},"repulse":{"distance":200,"duration":0.4},"push":{"particles_nb":4},"remove":{"particles_nb":2}}},"retina_detect":true});
/* This is done in order to be sure that jQuery is correctly loaded */
  $("input:text:visible:first").focus();
  $('#form_add_user').validator()
</script>

</div> <!-- /container -->

</body>
</html>
]]
