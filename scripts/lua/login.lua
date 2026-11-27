--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local auth_page = require "auth_page"

local info = ntop.getInfo()
local referer = _GET["referer"]
local reason = _GET["reason"]
local http_prefix = ntop.getHttpPrefix()
local login_disabled = ternary(ntop.isLoginBlacklisted(), " disabled", "")

auth_page.print_begin(i18n("login.login"))

print[[
        <form id="form_add_user" action="]] print(http_prefix) print[[/authorize.html" method="POST" accept-charset="UTF-8">
          <input type="hidden" name="user">
          <input type="hidden" name="referer" value="]] print(safeHtml(referer)) print[[">

          <h2 class="h3 mb-1">]] print(i18n("login.welcome_to", {product=info["product"]})) print[[</h2>
          <p class="text-muted mb-4">]] print(i18n("login.enter_credentials")) print[[</p>

          <div class="form-floating mb-3">
            <input placeholder="admin" id="input-username" type="text" class="form-control" name="_username" autofocus required]] print(login_disabled) print[[>
            <label for="input-username">]] print(i18n("login.username")) print[[</label>
          </div>
          <div class="form-floating mb-3">
            <input placeholder="admin" id="input-password" type="password" autocomplete="off" class="form-control" name="password" pattern="]] print(getPasswordInputPattern()) print[[" required]] print(login_disabled) print[[>
            <label for="input-password">]] print(i18n("login.password")) print[[</label>
          </div>
]]

if ntop.isLoginBlacklisted() then
  print[[<p class="text-danger">]] print(i18n("login.blacklisted_ip_notice")) print[[</p>]]
end

if not isEmptyString(reason) then
  print[[<p class="text-danger">]] print(i18n("login."..reason)) print[[</p>]]
end

print[[
          <button class="w-100 btn btn-lg btn-primary" type="submit">]] print(i18n("login.login")) print[[</button>
]]

-- SSO login button (shown only when OIDC is enabled, Pro license required)
local oidc_enabled = ntop.isPro and ntop.isPro() and (ntop.getPref("ntopng.prefs.oidc.enabled") == "1")
if oidc_enabled then
  -- URL-encode the referer so embedded '?' and '&' don't break the query string
  local oidc_referer = string.gsub(referer or "", "([^%w%-%.%_%~/])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  -- After a failed SSO the IdP may still have a valid session and redirect
  -- back immediately (without showing any login UI), causing an invisible
  -- loop. Adding prompt=login forces the IdP to ask for credentials again.
  local prompt_param = (reason == "oidc-error") and "&prompt=login" or ""
  print([[<a href="]] .. http_prefix .. [[/oidc_start?referer=]] .. oidc_referer .. prompt_param .. [["
     class="w-100 btn btn-lg btn-outline-secondary mt-2">
    ]] .. i18n("login.sso_login") .. [[
  </a>
]])
end

print[[
        </form>
        <p class="small text-muted text-center mt-4 mb-0"><a target="_blank" href="https://www.ntop.org/guides/ntopng/faq.html?utm_source=ntopng#cannot-login-into-the-gui">]] print(i18n("login.unable_to_login")) print[[</a> | ]] print(i18n("login.mfa_passkey")) print[[</p>
]]

if not info.oem then
  if info["product"] == "ntopng" then
    print[[<p class="small text-muted text-center mt-4 mb-0">]] print(i18n("login.links", {product=info["product"], donation_url="http://shop.ntop.org?utm_source=ntopng"})) print[[</p>
<p class="small text-muted text-center mt-4 mb-0">]] print(info["copyright"]) print[[<br>]] print(i18n("login.license", {product=info["product"], license="GPLv3", license_url="http://www.gnu.org/copyleft/gpl.html"})) print[[</p>]]
  else
    print[[<p class="small text-muted text-center mt-4 mb-0">]] print(info["copyright"]) print[[</p>]]
  end
end

auth_page.print_end()
