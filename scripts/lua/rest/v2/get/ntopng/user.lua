--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"   -- validates _GET before it is read
require "ntop_utils"  -- isAdministrator(), isEmptyString()
local rest_utils    = require "rest_utils"
local locales_utils = require "locales_utils"

--
-- One ntopng user, for the edit dialog of the Admin > Users page. Same data
-- of the old admin/get_user_info.lua (now in attic) but never the password hash.
-- Administrators can read any user, the other users only themselves.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/ntopng/user.lua?username=admin"
--

local logged_user = _SESSION and _SESSION["user"] or ""
local username = _GET["username"]

if not isAdministrator() then
   username = logged_user
end

if isEmptyString(username) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

username = string.lower(username)

local user = (ntop.getUsers() or {})[username]

-- Captive portal users are managed by the nEdge pages
if (not user) or (user["group"] == "captive_portal") then
   rest_utils.answer(rest_utils.consts.err.user_does_not_exist)
   return
end

-- Language: the default one when unset or no longer available
local language = user["language"]
local available = false

for _, l in ipairs(locales_utils.getAvailableLocales()) do
   if l["code"] == language then
      available = true
      break
   end
end

if not available then
   language = locales_utils.default_locale
end

local allowed_ifname = user["allowed_ifname"] or ""

rest_utils.answer(rest_utils.consts.success.ok, {
   username = username,
   full_name = user["full_name"] or "",
   group = user["group"] or "",
   allowed_nets = user["allowed_nets"] or "",
   allowed_if_id = (allowed_ifname ~= "") and tostring(interface.name2id(allowed_ifname)) or "",
   allowed_host_pools = user["allowed_host_pools"] or "",
   language = language,
   allow_pcap_download = user["allow_pcap_download"] and true or false,
   allow_historical_flows = user["allow_historical_flows"] and true or false,
   allow_alerts = user["allow_alerts"] and true or false,
   -- Readable only by an administrator or by the user itself (checked above)
   api_token = ntop.getUserAPIToken(username) or "",
   totp_enabled = ntop.isTOTPEnabled(username) and true or false,
   is_self = (username == logged_user),
})
