--
-- (C) 2013-26 - ntop.org
--
-- Forced change of the default admin password (HTTPserver.cpp redirects every page here,
-- CHANGE_PASSWORD_URL, until it is changed). The form is a small Vue app
-- (pro/http_src/vue/page-change-password.vue, in dist/logout.js): until the password is
-- changed the REST APIs are redirected too, so the form posts to this page.
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- No lua_utils: rest_utils has the headers and loads i18n (locales_utils)
require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"
local locales_utils = require "locales_utils"
local json = require "dkjson"

-- Same limits of the password input pattern (getPasswordInputPattern, MAX_PASSWORD_LEN)
local MIN_PASSWORD_LEN = 5
local MAX_PASSWORD_LEN = 128

local user = _SESSION["user"]
local http_prefix = ntop.getHttpPrefix()

-- Back to the page that was asked (?referer= from HTTPserver.cpp): only a local path
local function local_referer(r)
  if type(r) ~= "string" or r:sub(1, 1) ~= "/" or r:sub(1, 2) == "//" or r:find("\\", 1, true) then
    return http_prefix .. "/"
  end
  return r
end

local error_msg

if _POST["new_password"] ~= nil or not isEmptyString(_POST["user_language"]) then
  -- validateUserLanguage: only the available locales
  if not isEmptyString(_POST["user_language"]) then
    ntop.changeUserLanguage(user, _POST["user_language"])
  end

  if _POST["new_password"] ~= nil and user == "admin" then
    require "lua_utils_gui" -- unescapeHTML
    local new_password = unescapeHTML(_POST["new_password"])
    local confirm_new_password = unescapeHTML(_POST["confirm_password"] or "")

    if new_password ~= confirm_new_password then
      error_msg = i18n("login.password_mismatch")
    elseif new_password == "admin" then
      error_msg = i18n("login.password_not_valid")
    elseif #new_password < MIN_PASSWORD_LEN or #new_password > MAX_PASSWORD_LEN then
      error_msg = i18n("login.password_length", { min = MIN_PASSWORD_LEN, max = MAX_PASSWORD_LEN })
    elseif not ntop.resetUserPassword(user, "admin", "", new_password) then
      error_msg = i18n("login.password_change_failed")
    else
      ntop.setCache("ntopng.prefs.admin_password_changed", "1")
      print(ntop.httpRedirect(local_referer(_GET["referer"])))
      return
    end
  end
end

rest_utils.sendHTTPContentTypeHeader('text/html')

local info = ntop.getInfo()
local static_file_epoch = ntop.getStaticFileEpoch() .. ""

-- Same favicon of the login page (custom one in pro/nEdge)
local favicon_url = http_prefix .. "/favicon.ico"
if ((ntop.isPro and ntop.isPro()) or (ntop.isnEdge and ntop.isnEdge()))
   and ntop.exists(dirs.installdir .. "/httpdocs/img/custom_favicon.ico") then
  favicon_url = http_prefix .. "/img/custom_favicon.ico"
end

local current_language = ntop.getPref("ntopng.user." .. (user or "") .. ".language")
local languages = {}
for _, lang in ipairs(locales_utils.getAvailableLocales()) do
  languages[#languages + 1] = { code = lang.code, label = i18n("locales." .. lang.code) }
end

-- No JS i18n without the full GUI: the texts go translated in the context
local context = {
  csrf = ntop.getRandomCSRFValue(),
  error = error_msg,
  min_length = MIN_PASSWORD_LEN,
  max_length = MAX_PASSWORD_LEN,
  languages = languages,
  language = isEmptyString(current_language) and "en" or current_language,
  logout_url = http_prefix .. "/lua/ntopng_logout.lua",
  -- Rendered as text by Vue: the HTML entity must become the character
  copyright = ((info.copyright or ""):gsub("&copy;", "©")),
  i18n = {
    title = i18n("login.change_password"),
    message = i18n("login.must_change_password"),
    password = i18n("login.password"),
    confirm_password = i18n("login.confirm_password"),
    password_hint = i18n("login.password_length", { min = MIN_PASSWORD_LEN, max = MAX_PASSWORD_LEN }),
    password_mismatch = i18n("login.password_mismatch"),
    language = i18n("language"),
    submit = i18n("login.change_password"),
    logout = i18n("login.logout"),
  },
}

-- The JSON sits in a <script> element: "<" escaped (valid in JSON strings)
-- so that a "</script>" inside a value cannot close it
local context_json = (json.encode(context):gsub("<", "\\u003c"))

print([[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>]] .. i18n("login.change_password") .. " - " .. info.product .. [[</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="]] .. http_prefix .. "/dist/third-party.css?" .. static_file_epoch .. [[" rel="stylesheet">
  <link href="]] .. http_prefix .. "/dist/white-mode.css?" .. static_file_epoch .. [[" rel="stylesheet">
  <link href="]] .. http_prefix .. "/dist/ntopng.css?" .. static_file_epoch .. [[" rel="stylesheet">
  <link href="]] .. favicon_url .. [[" rel="icon">
  <script type="text/javascript" src="]] .. http_prefix .. "/dist/login.js?" .. static_file_epoch .. [["></script>
  <style>
    /* Same frame of the login page (login.lua) */
    html, body {
      height: 100vh;
    }

    body {
      display: flex;
      align-items: center;
      background-color: #f5f5f5;
    }
  </style>
</head>
<body class="body">
  <div id="particles-js"></div>
  <div id="change-password-app" class="w-100"></div>
  <script type="application/json" id="change-password-context">]] .. context_json .. [[</script>
  <script type="text/javascript" src="]] .. http_prefix .. "/dist/logout.js?" .. static_file_epoch .. [["></script>
</body>
</html>
]])
