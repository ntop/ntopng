--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")

require "lua_utils"

local captive_portal_utils = require("captive_portal_utils")

if not ntop.isnEdge() then
   return
end

local remote_addr = _SERVER["REMOTE_ADDR"]
local is_logged = captive_portal_utils.is_logged(remote_addr)

if is_logged then
   captive_portal_utils.logout(remote_addr)
end

captive_portal_utils.print_header()

print [[
	 <form id="form_add_user" role="form" data-bs-toggle="validator" class="form-signin" onsubmit="return makeUsernameLowercase();" action="]] print(ntop.getHttpPrefix()) print[[/lua/authorize_captive.lua]]

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

if not isEmptyString(r) then
   print("?referer="..r)
end

local info = ntop.getInfo()

print[[" method="POST">
	 <h2 class="form-signin-heading" style="font-weight: bold;">]] print(info["product"]) print [[ Access Portal</h2>
  <div class="form-group mb-3 has-feedback">
      <input type="hidden" class="form-control" name="username">
      <input type="text" class="form-control" name="_username" placeholder="]] print(i18n("login.username")) print[[" pattern="^[\w\.%]{1,}$" required>
      <input type="password" class="form-control" name="password" placeholder="]] print(i18n("login.password")) print[[" pattern="]] print(getPasswordInputPattern()) print[[" required>
      <input type="text" class="form-control" name="label" placeholder="]] print(i18n("login.device_label")) print[[" pattern="^[ \w\.%]{1,}$" required>
</div>
    <button class="w-100 btn btn-lg btn-primary" type="submit">]] print(i18n("login.login")) print[[</button>
  	<div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
        <small>
      <p>]] print(i18n("login.enter_credentials")) print[[
          </p>

      <p>]] print(info["copyright"]) print [[

        </small>
      </div>
    </div>
  </form>

<script>
  $("input:text:visible:first").focus();
  //$('#form_add_user').validator();

  function makeUsernameLowercase() {
    var target = $('#form_add_user input[name="username"]');
    var origin = $('#form_add_user input[name="_username"]');
    target.val(origin.val().toLowerCase());
    origin.removeAttr("name");
    return true;
  }
</script>

]]

captive_portal_utils.print_footer()
