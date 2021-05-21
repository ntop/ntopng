--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"
local page_utils = require("page_utils")
local template = require("template_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.print_header_minimal()

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

	 <form id="form_add_user" role="form" data-bs-toggle="validator" class="form-signin" action="]] print(ntop.getHttpPrefix()) print[[/lua/authorize_captive.lua" method="GET">
	 <h2 class="form-signin-heading" style="font-weight: bold; text-align: center;">]] print(info["product"]) print [[<br>Access Portal</h2>

<br>
<br>

<div class="form-group mb-3">
  <div class="form-check">]]

print(template.gen("on_off_switch.html", {
   id = "accept_tos",
}))

print(i18n("login.informative_captive_portal_tos", {url="https://en.wikipedia.org/wiki/General_Data_Protection_Regulation"})) print[[
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
    <button id="submit" disabled="" class="w-100 btn btn-lg btn-primary" type="submit">]] print(i18n("login.informative_captive_join")) print[[</button>
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

  $('#accept_tos').change(function() {
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
