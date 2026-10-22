--
-- (C) 2013-26 - ntop.org
--
-- Logout: closes the session and renders the confirmation page, a small Vue
-- app (pro/http_src/vue/page-logout.vue, bundled alone in dist/logout.js
-- because without a session the page cannot use ntopng.js). The frame
-- (stylesheets, background, particles) is the one of the login page.
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- No lua_utils: rest_utils has the logout header and loads i18n (locales_utils)
local rest_utils = require "rest_utils"
local json = require "dkjson"

-- Seconds before going back to the login page
local REDIRECT_DELAY = 5

rest_utils.sendHTTPHeaderLogout('text/html')

ntop.delCache("ntopng.cache.sessions." .. _SESSION["session"])

local info = ntop.getInfo()
local http_prefix = ntop.getHttpPrefix()
local static_file_epoch = ntop.getStaticFileEpoch() .. ""
local login_url = http_prefix .. "/lua/login.lua"

-- Same favicon of the login page (custom one in pro/nEdge)
local favicon_url = http_prefix .. "/favicon.ico"
if ((ntop.isPro and ntop.isPro()) or (ntop.isnEdge and ntop.isnEdge()))
   and ntop.exists(dirs.installdir .. "/httpdocs/img/custom_favicon.ico") then
  favicon_url = http_prefix .. "/img/custom_favicon.ico"
end

-- No JS i18n without a session: the texts go translated in the context.
-- %{seconds} is kept as is and filled by the countdown in the page
local context = {
  login_url = login_url,
  redirect_delay = REDIRECT_DELAY,
  -- Rendered as text by Vue: the HTML entity must become the character
  copyright = ((info.copyright or ""):gsub("&copy;", "©")),
  i18n = {
    title = i18n("login.logged_out"),
    message = i18n("login.logged_out_message"),
    back_to_login_in = i18n("login.back_to_login_in", { seconds = "%{seconds}" }),
    login_again = i18n("login.login_again"),
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
  <title>]] .. i18n("login.logged_out") .. " - " .. info.product .. [[</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <noscript><meta http-equiv="refresh" content="]] .. REDIRECT_DELAY .. "; URL=" .. login_url .. [["></noscript>
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
      text-align: center;
    }
  </style>
</head>
<body class="body">
  <div id="particles-js"></div>
  <div id="logout-app" class="w-100"></div>
  <script type="application/json" id="logout-context">]] .. context_json .. [[</script>
  <script type="text/javascript" src="]] .. http_prefix .. "/dist/logout.js?" .. static_file_epoch .. [["></script>
</body>
</html>
]])
