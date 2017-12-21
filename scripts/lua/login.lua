--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

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

	 <form id="form_add_user" role="form" data-toggle="validator" class="form-signin" onsubmit="return makeUsernameLowercase();" action="]] print(ntop.getHttpPrefix()) print[[/authorize.html" method="POST">
	 <h2 class="form-signin-heading" style="font-weight: bold;">]] print(i18n("login.welcome_to", {product=info["product"]})) print[[</h2>
  <div class="form-group has-feedback">
      <input type="hidden" class="form-control" name="user">
      <input type="text" class="form-control" name="_username" placeholder="]] print(i18n("login.username_ph")) print[[" pattern="^[\w\.%]{1,}$" required>
      <input type="password" class="form-control" name="password" placeholder="]] print(i18n("login.password_ph")) print[[" pattern="]] print(getPasswordInputPattern()) print[[" required>
</div>
	 <input type="hidden" class="form-control" name="referer" value="]] 

local r = _GET["referer"]

local additional_keys = {
      "host",
      "ifname",
      "ifid",
      "page"
}

for _,id in ipairs(additional_keys) do
  if(_GET[id] ~= nil) then
    r = r .. "&" .. id .. "=" .._GET[id]
  end
end

print(r)


print [[">
    <button class="btn btn-lg btn-primary btn-block" type="submit">]] print(i18n("login.login")) print[[</button>
  	<div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
        <small>
      <p>]] print(i18n("login.donation", {product=info["product"], donation_url="http://shop.ntop.org"})) print[[
          </p>

      <p>]] print(info["copyright"]) print [[<br> ]] print(i18n("login.license", {product=info["product"], license="GPLv3", license_url="http://www.gnu.org/copyleft/gpl.html"})) print[[</p>
        </small>
      </div>
    </div>
  </form>

<script>
  $("input:text:visible:first").focus();
  //$('#form_add_user').validator();

  function makeUsernameLowercase() {
    var target = $('#form_add_user input[name="user"]');
    var origin = $('#form_add_user input[name="_username"]');
    target.val(origin.val().toLowerCase());
    origin.removeAttr("name");
    return true;
  }
</script>

</div> <!-- /container -->

</body>
</html>
]]
