--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local token = _GET["token"] or ""
local reason = _GET["reason"]
local http_prefix = ntop.getHttpPrefix()
-- Version of the static files: they are cached by the browsers (see ntop_cache_control() in mongoose.c)
local static_file_epoch = ntop.getStaticFileEpoch() .. ""

if isEmptyString(token) then
   print('<html><head><meta http-equiv="refresh" content="0; URL=' .. http_prefix .. '/lua/login.lua?reason=session-expired"></head><body></body></html>')
   return
end

local token_info = ntop.getWebAuthnPendingToken(token)
if not token_info then
   print('<html><head><meta http-equiv="refresh" content="0; URL=' .. http_prefix .. '/lua/login.lua?reason=session-expired"></head><body></body></html>')
   return
end

local challenge = token_info.challenge
local username = token_info.username

-- Get user's registered credentials (for allowCredentials list)
local creds_json = ntop.getWebAuthnCredentials(username)

print([[
<!DOCTYPE html>
<html>
<head>
 <title>Passkey Verification</title>
 <meta name="viewport" content="width=device-width, initial-scale=1">
 <link href="]] .. http_prefix .. [[/dist/third-party.css?]] .. static_file_epoch .. [[" rel="stylesheet">
 <link href="]] .. http_prefix .. [[/dist/white-mode.css?]] .. static_file_epoch .. [[" rel="stylesheet">
 <link href="]] .. http_prefix .. [[/dist/ntopng.css?]] .. static_file_epoch .. [[" rel="stylesheet">
 <style>
   html, body { height: 100vh; }
   body {
     background-color: #f5f5f5;
     display: flex;
     align-items: center;
     padding-top: 0;
     text-align: center;
   }
   .form-webauthn {
     width: 100%;
     max-width: 420px;
     padding: 15px;
     margin: auto;
   }
   .passkey-icon { font-size: 3rem; color: #0d6efd; margin-bottom: 1rem; }
 </style>
</head>
<body>
 <main class="form-webauthn">
   <div class="passkey-icon"><i class="fas fa-fingerprint"></i></div>
   <h1 class="h3 mb-3 fw-normal">Passkey Verification</h1>
   <p class="text-muted mb-4">Use your passkey (fingerprint, face, or security key) to verify your identity.</p>
]])

if reason == "invalid-key" then
   print([[
   <div class="alert alert-danger" role="alert">
     Passkey verification failed. Please try again.
   </div>
]])
end

print([[
   <div id="webauthn-status" class="mb-3 text-muted" style="display:none">
     <div class="spinner-border spinner-border-sm me-2" role="status"></div>
     Waiting for your passkey...
   </div>
   <button id="btn-passkey" class="w-100 btn btn-lg btn-primary mb-3">
     <i class="fas fa-fingerprint me-2"></i>Authenticate with Passkey
   </button>
   <div class="mt-2">
     <a href="]] .. http_prefix .. [[/lua/login.lua">
       &larr; Back to login
     </a>
   </div>

   <!-- Hidden form to POST assertion -->
   <form id="webauthn_form" method="POST" action="]] .. http_prefix .. [[/webauthn_authorize.html">
     <input type="hidden" name="token" value="]] .. token .. [[">
     <input type="hidden" name="cred_id" id="f_cred_id">
     <input type="hidden" name="client_data" id="f_client_data">
     <input type="hidden" name="auth_data" id="f_auth_data">
     <input type="hidden" name="signature" id="f_signature">
   </form>
 </main>

 <script type="text/javascript" src="]] .. http_prefix .. [[/dist/third-party.js?]] .. static_file_epoch .. [["></script>
 <script>
(function() {
  var CHALLENGE_B64URL = ']] .. challenge .. [[';
  var CREDS_JSON = ]] .. creds_json .. [[;

  function b64url_decode(str) {
    str = str.replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) str += '=';
    var bin = atob(str);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes.buffer;
  }

  function b64url_encode(buf) {
    var bytes = new Uint8Array(buf);
    var str = '';
    for (var i = 0; i < bytes.length; i++) str += String.fromCharCode(bytes[i]);
    return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }

  async function doWebAuthn() {
    if (!window.PublicKeyCredential) {
      alert('WebAuthn is not supported in this browser.');
      return;
    }

    var allowCreds = CREDS_JSON.map(function(c) {
      return { type: 'public-key', id: b64url_decode(c.id) };
    });

    document.getElementById('webauthn-status').style.display = '';
    document.getElementById('btn-passkey').disabled = true;

    try {
      var assertion = await navigator.credentials.get({
        publicKey: {
          challenge: b64url_decode(CHALLENGE_B64URL),
          allowCredentials: allowCreds,
          rpId: window.location.hostname,
          userVerification: 'preferred',
          timeout: 60000
        }
      });

      document.getElementById('f_cred_id').value     = b64url_encode(assertion.rawId);
      document.getElementById('f_client_data').value = b64url_encode(assertion.response.clientDataJSON);
      document.getElementById('f_auth_data').value   = b64url_encode(assertion.response.authenticatorData);
      document.getElementById('f_signature').value   = b64url_encode(assertion.response.signature);
      document.getElementById('webauthn_form').submit();
    } catch(e) {
      document.getElementById('webauthn-status').style.display = 'none';
      document.getElementById('btn-passkey').disabled = false;
      if (e.name !== 'NotAllowedError') {
        alert('Passkey error: ' + e.message);
      }
    }
  }

  document.getElementById('btn-passkey').addEventListener('click', doWebAuthn);

  /* Auto-trigger on page load for better UX */
  window.addEventListener('load', function() {
    setTimeout(doWebAuthn, 500);
  });
})();
 </script>
</body>
</html>
]])
