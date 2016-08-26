--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

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

	 <form role="form" data-toggle="validator" class="form-signin" action="]] print(ntop.getHttpPrefix()) print[[/authorize.html" method="POST">
	 <h2 class="form-signin-heading" style="font-weight: bold;">Welcome to ]] print(info["product"]) print [[</h2>
  <div class="form-group has-feedback">

      <input type="text" class="form-control" name="user" placeholder="Username" pattern="^[\w\.%]{1,}$" required>
      <input type="password" class="form-control" name="password" placeholder="Password" pattern="^[\w\$\\!\/\(\)=\?\^\*@_\-\u0000-\u00ff]{1,}$" required>
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
      <p>If you find ]] print(info["product"]) print [[ useful, please support us by making a small <A href=http://shop.ntop.org>donation</A>. Your funding will help to run and foster the development of this project. Thank you.
          </p>

      <p>]] print(info["copyright"]) print [[<br> ]] print(info["product"]) print [[ is released under <A HREF=http://www.gnu.org/copyleft/gpl.html>GPLv3</A>.</p>

  	      <p class="text-muted">Hint: the default user and password are admin</p>
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
