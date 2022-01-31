--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local captive_portal_utils = require("captive_portal_utils")

if not ntop.isnEdge() then
   return
end

captive_portal_utils.print_header()

local info = ntop.getInfo()

print [[
  <form id="form_del_user" role="form" data-bs-toggle="validator" class="form-signin" action="]] print(ntop.getHttpPrefix()) print[[/lua/logout.lua]] print[[" method="POST">
    <input type="hidden" class="form-control" name="action" value="logout" />

    <h2 class="form-signin-heading" style="font-weight: bold;">]] print(info["product"]) print [[ Access Portal</h2>
]]

local remote_addr = _SERVER["REMOTE_ADDR"]
local is_logged = captive_portal_utils.is_logged(remote_addr)

if _POST["action"] == "logout" or not is_logged then

  if is_logged then
     captive_portal_utils.logout(remote_addr)
  end

  print[[
    <div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
    ]] print(i18n("login.logged_out")) print[[
      </div>
      <div >&nbsp;</div>
    </div>
    <div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
        <small>
          <p>]] print(info["copyright"]) print [[
        </small>
      </div>
    </div>
  ]]

else
  print[[
    <div class="row">
      <div class="col-lg-12">
    ]] print(i18n("login.logout_message")) print[[
      </div>
      <div >&nbsp;</div>
    </div>
    <button class="w-100 btn btn-lg btn-primary" type="submit">]] print(i18n("login.logout")) print[[</button>
    <div class="row">
      <div >&nbsp;</div>
      <div class="col-lg-12">
        <small>
          <p>]] print(info["copyright"]) print [[
        </small>
      </div>
    </div>
  ]]
end

print [[
  </form>
]]

captive_portal_utils.print_footer()

