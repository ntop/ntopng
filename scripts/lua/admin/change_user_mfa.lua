--
-- (C) 2013-26 - ntop.org
--
-- REST endpoint to manage TOTP/MFA settings for a user.
-- POST parameters:
--   action   = "enable" | "disable" | "generate_secret"
--   username = target username
--
-- Only an admin or the user themselves may change their own MFA settings.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local action   = _POST["action"]
local username = _POST["username"]

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

if action == "generate_secret" then
   -- Only while MFA is off: replacing the secret of an active MFA would skip the
   -- current code (required to disable it) and lock the user out if the setup
   -- is not completed. Disable MFA first.
   if ntop.isTOTPEnabled(username) then
      print(json.encode({ result = -1, message = "MFA is already enabled: disable it first" }))
      return
   end

   -- Generate a new TOTP secret and store it (does not enable MFA yet)
   local secret = ntop.generateTOTPSecret()
   if not secret then
      print(json.encode({ result = -1, message = "Failed to generate secret" }))
      return
   end
   if not ntop.setUserTOTPSecret(username, secret) then
      print(json.encode({ result = -1, message = "Failed to save secret" }))
      return
   end
   local uri = ntop.getTOTPProvisioningUri(username)
   print(json.encode({
      result = 0,
      secret = secret,
      provisioning_uri = uri or ""
   }))

elseif action == "enable" then
   -- Verify the provided TOTP code before enabling (confirm setup is correct)
   local code = _POST["totp"]
   if isEmptyString(code) then
      print(json.encode({ result = -1, message = "Missing TOTP code" }))
      return
   end
   if not ntop.validateTOTP(username, code) then
      print(json.encode({ result = -1, message = "Invalid TOTP code" }))
      return
   end
   if not ntop.setUserTOTPEnabled(username, true) then
      print(json.encode({ result = -1, message = "Failed to enable MFA" }))
      return
   end
   print(json.encode({ result = 0, message = "MFA enabled" }))

elseif action == "disable" then
   -- Admins can disable without a code; users must supply current code
   if not isAdministrator() then
      local code = _POST["totp"]
      if isEmptyString(code) or not ntop.validateTOTP(username, code) then
         print(json.encode({ result = -1, message = "Invalid TOTP code" }))
         return
      end
   end
   ntop.setUserTOTPEnabled(username, false)
   print(json.encode({ result = 0, message = "MFA disabled" }))

else
   print(json.encode({ result = -1, message = "Unknown action" }))
end
