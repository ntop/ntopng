--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local info = ntop.getInfo()
local token = _GET["token"] or ""
local reason = _GET["reason"]
local http_prefix = ntop.getHttpPrefix()
-- Version of the static files: they are cached by the browsers (see ntop_cache_control() in mongoose.c)
local static_file_epoch = ntop.getStaticFileEpoch() .. ""

-- Basic token sanity check
if isEmptyString(token) then
   print('<html><head><meta http-equiv="refresh" content="0; URL=' .. http_prefix .. '/lua/login.lua?reason=session-expired"></head><body></body></html>')
   return
end

print[[
<!DOCTYPE html>
<html>
<head>
 <title>]] print(i18n("mfa.title") or "Two-Factor Authentication") print[[</title>
 <meta name="viewport" content="width=device-width, initial-scale=1">
 <link href="]] print(http_prefix) print[[/dist/third-party.css?]] print(static_file_epoch) print[[" rel="stylesheet">
 <link href="]] print(http_prefix) print[[/dist/white-mode.css?]] print(static_file_epoch) print[[" rel="stylesheet">
 <link href="]] print(http_prefix) print[[/dist/ntopng.css?]] print(static_file_epoch) print[[" rel="stylesheet">
 <style>
   html, body { height: 100vh; }
   body {
     background-color: #f5f5f5;
     display: flex;
     align-items: center;
     padding-top: 0;
     text-align: center;
   }
   .form-mfa {
     width: 100%;
     max-width: 400px;
     padding: 15px;
     margin: auto;
   }
   .totp-input {
     letter-spacing: 0.4em;
     font-size: 1.5em;
     text-align: center;
   }
 </style>
</head>
<body>
 <main class="form-mfa">
   <form id="mfa_form" role="form" method="POST"
         action="]] print(http_prefix) print[[/mfa_authorize.html"
         accept-charset="UTF-8">
     <input type="hidden" name="token" value="]] print(token) print[[">

     <h1 class="h3 mb-3 fw-normal">
       <i class="fas fa-shield-alt"></i>
       ]] print(i18n("mfa.two_factor_auth") or "Two-Factor Authentication") print[[
     </h1>
     <p class="text-muted mb-3">
       ]] print(i18n("mfa.enter_code_prompt") or "Enter the 6-digit code from your authenticator app.") print[[
     </p>

     <div class="form-group mb-3">
       <input type="text"
              id="totp_code"
              name="totp_code"
              class="form-control totp-input"
              maxlength="6"
              pattern="[0-9]{6}"
              placeholder="000000"
              autocomplete="one-time-code"
              inputmode="numeric"
              required
              autofocus>
     </div>
]]

if reason == "wrong-code" then
  print[[
     <div class="alert alert-danger" role="alert">
       ]] print(i18n("mfa.wrong_code") or "Invalid code. Please try again.") print[[
     </div>
]]
end

print[[
     <button class="w-100 btn btn-lg btn-primary mt-2" type="submit">
       ]] print(i18n("mfa.verify") or "Verify") print[[
     </button>
     <div class="mt-3">
       <a href="]] print(http_prefix) print[[/lua/login.lua">
         &larr; ]] print(i18n("mfa.back_to_login") or "Back to login") print[[
       </a>
     </div>
   </form>
 </main>
 <script type="text/javascript" src="]] print(http_prefix) print[[/dist/third-party.js?]] print(static_file_epoch) print[["></script>
 <script>
   /* Auto-submit when 6 digits are entered */
   document.getElementById('totp_code').addEventListener('input', function() {
     if (this.value.length === 6 && /^[0-9]{6}$/.test(this.value)) {
       document.getElementById('mfa_form').submit();
     }
   });
 </script>
</body>
</html>
]]
