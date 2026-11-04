--
-- (C) 2013-26 - ntop.org
--
-- REST endpoint for WebAuthn/Passkey credential management.
-- Actions:
--   get_registration_options  -> generate challenge for registration
--   complete_registration     -> verify and store a new credential
--   delete                    -> remove a credential
--   list                      -> list credentials
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local action   = _POST["action"] or _GET["action"]
local username = _POST["username"] or _GET["username"]

if isEmptyString(username) then
   print(json.encode({ result = -1, message = "Missing username" }))
   return
end

username = string.lower(username)

-- Authorization: admin or the logged-in user themselves
local curr_user = _SESSION and _SESSION["user"] or ""
if (not isAdministrator()) and (curr_user ~= username) then
   print(json.encode({ result = -1, message = "Not authorized" }))
   return
end

-- A passkey takes precedence over TOTP at login: registering one while MFA is
-- enabled would replace the second factor without the current TOTP code
if (action == "get_registration_options" or action == "complete_registration")
   and ntop.isTOTPEnabled(username) then
   print(json.encode({ result = -1, message = "Passkey cannot be registered while MFA is enabled" }))
   return
end

if action == "get_registration_options" then
   local opts = ntop.generateWebAuthnRegistrationOptions(username)
   if not opts then
      print(json.encode({ result = -1, message = "Failed to generate challenge" }))
      return
   end
   -- Return options for navigator.credentials.create()
   -- rp.id is intentionally empty here; the client fills it with window.location.hostname
   print(json.encode({
      result    = 0,
      challenge = opts.challenge,
      rp        = { name = "ntopng", id = "" },
      user      = { id = username, name = username, displayName = username },
      pubKeyCredParams = {{ type = "public-key", alg = -7 }},
      authenticatorSelection = { userVerification = "preferred", residentKey = "preferred" },
      attestation = "none",
      timeout   = 60000
   }))

elseif action == "complete_registration" then
   local cred_name   = _POST["cred_name"] or "Passkey"
   local cred_id     = _POST["cred_id"]
   local client_data = _POST["client_data"]
   local att_obj     = _POST["att_obj"]
   local challenge   = _POST["challenge"]
   local origin      = _POST["origin"]
   local rp_id       = _POST["rp_id"]

   if isEmptyString(cred_id) or isEmptyString(client_data) or
      isEmptyString(att_obj) or isEmptyString(challenge) or
      isEmptyString(origin) or isEmptyString(rp_id) then
      print(json.encode({ result = -1, message = "Missing registration data" }))
      return
   end

   local ok = ntop.completeWebAuthnRegistration(
      username, cred_name, cred_id, client_data, att_obj, challenge, origin, rp_id
   )
   if ok then
      print(json.encode({ result = 0, message = "Passkey registered successfully" }))
   else
      print(json.encode({ result = -1, message = "Registration verification failed" }))
   end

elseif action == "delete" then
   local cred_id = _POST["cred_id"]
   if isEmptyString(cred_id) then
      print(json.encode({ result = -1, message = "Missing credential ID" }))
      return
   end
   local ok = ntop.deleteWebAuthnCredential(username, cred_id)
   if ok then
      print(json.encode({ result = 0, message = "Passkey removed" }))
   else
      print(json.encode({ result = -1, message = "Credential not found" }))
   end

elseif action == "list" then
   local creds_json = ntop.getWebAuthnCredentials(username)
   -- Parse and re-encode to ensure valid JSON output
   local creds = json.decode(creds_json) or {}
   print(json.encode({ result = 0, credentials = creds }))

else
   print(json.encode({ result = -1, message = "Unknown action" }))
end
