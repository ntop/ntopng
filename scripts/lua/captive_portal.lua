--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

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

	 <form role="form" data-toggle="validator" class="form-signin" action="]] print(ntop.getHttpPrefix()) print[[/lua/authorize_captive.lua" method="GET">
	 <h2 class="form-signin-heading" style="font-weight: bold;">]] print(info["product"]) print [[ Access Portal</h2>
  <div class="form-group has-feedback">

      <input type="text" class="form-control" name="username" placeholder="Username" pattern="^[\w\.%]{1,}$" required>
      <input type="password" class="form-control" name="password" placeholder="Password" pattern="]] print(getPasswordInputPattern()) print[[" required>
      <input type="text" class="form-control" name="label" placeholder="Device Label" pattern="^[ \w\.%]{1,}$" required>
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
    <button class="btn btn-lg btn-primary btn-block" type="submit">Login</button>
  	<div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
        <small>
      <p>Please enter your credentials for accessing this network.
          </p>

      <p>]] print(info["copyright"]) print [[

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
