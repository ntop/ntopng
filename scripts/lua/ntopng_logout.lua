--
-- (C) 2013-26 - ntop.org
--
-- Logout: closes the session and renders the confirmation page in the frame of the
-- login page (auth_page), then goes back to the login page (countdown in dist/auth.js).
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- No lua_utils: rest_utils has the logout header and loads i18n (locales_utils)
local rest_utils = require "rest_utils"
local auth_page = require "auth_page"

-- Seconds before going back to the login page
local REDIRECT_DELAY = 5

rest_utils.sendHTTPHeaderLogout('text/html')

ntop.delCache("ntopng.cache.sessions." .. _SESSION["session"])

local login_url = ntop.getHttpPrefix() .. "/lua/login.lua"

-- No JS i18n without a session: the text goes translated in the context.
-- %{seconds} is kept as is and filled by the countdown
auth_page.print_begin(i18n("login.logged_out"), {
  redirect_url = login_url,
  redirect_delay = REDIRECT_DELAY,
  countdown_text = i18n("login.back_to_login_in", { seconds = "%{seconds}" }),
})

print([[
        <i class="fas fa-check-circle text-success fs-1 mb-3 d-block" aria-hidden="true"></i>
        <h2 class="h3 mb-1">]] .. i18n("login.logged_out") .. [[</h2>
        <p class="text-muted mb-4">]] .. i18n("login.logged_out_message") .. [[</p>
        <a class="w-100 btn btn-lg btn-primary" href="]] .. login_url .. [[">]] .. i18n("login.login_again") .. [[</a>
        <div class="auth-countdown" style="animation-duration:]] .. REDIRECT_DELAY .. [[s"></div>
        <p class="small text-muted text-center mt-2 mb-0" id="auth-countdown-text"></p>
]])

auth_page.print_end()
