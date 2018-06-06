--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header-minimal.inc")
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
        max-width: 400px;
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

	 <form id="form_add_user" role="form" data-toggle="validator" class="form-signin" action="]] print(ntop.getHttpPrefix()) print[[/lua/authorize_captive.lua" method="GET">
	 <h2 class="form-signin-heading" style="font-weight: bold; text-align: center;">]] print(info["product"]) print [[<br>Access Portal</h2>

<br>
<br>

<div class="form-group">
  <div class="form-check">
    <label class="form-check-label" style="font-weight: normal;">
      <input id="tos" class="form-check-input" type="checkbox" value="">
]] print(i18n("login.informative_captive_portal_tos", {url="https://en.wikipedia.org/wiki/General_Data_Protection_Regulation"})) print[[
    </label>
  </div>
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
    <button id="submit" disabled="" class="btn btn-lg btn-primary btn-block" type="submit">]] print(i18n("login.informative_captive_join")) print[[</button>
  	<div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
        <small>
          <p align=center>]] print(info["copyright"]) print [[
        </small>
      </div>
    </div>
  </form>

<script>
  $("input:text:visible:first").focus();

  $('#tos').change(function() {
    if($(this).prop('checked')) {
      $("#submit").prop("disabled", false);
    } else {
      $("#submit").prop("disabled", true);
    }
  });

</script>

</div> <!-- /container -->

</body>
</html>
]]
