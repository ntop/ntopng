--
-- (C) 2014-26 - ntop.org
--
-- GET /lua/rest/v2/get/ntopng/test_wazuh_connectivity.lua
--
-- Tests Wazuh credentials by hitting /security/user/authenticate?raw=true.
-- Query params:
--   url      - Wazuh base URL (required)
--   username - Wazuh username (required)
--   password - Wazuh password (required)
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local rest_utils = require "rest_utils"
local auth       = require "auth"

if not auth.has_capability(auth.capabilities.preferences) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local url      = _GET["url"]      or ""
local username = _GET["username"] or ""
local password = _GET["password"] or ""

if isEmptyString(url) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { message = i18n("prefs.wazuh_missing_url") })
   return
end

url = url:gsub("/$", "")

local auth_url = url .. "/security/user/authenticate?raw=true"
local rc = ntop.httpGet(auth_url, username, password, 8 --[[timeout]], true --[[return_content]])

if rc == nil or (type(rc) == "table" and (rc.RESPONSE_CODE == nil or rc.RESPONSE_CODE == 0)) then
   rest_utils.answer(rest_utils.consts.err.bad_content, { message = i18n("prefs.wazuh_unreachable") })
   return
end

if type(rc) == "table" and rc.RESPONSE_CODE ~= 200 then
   rest_utils.answer(rest_utils.consts.err.bad_content, { message = i18n("prefs.wazuh_auth_failed") })
   return
end

if type(rc) == "table" and isEmptyString(rc.CONTENT) then
   rest_utils.answer(rest_utils.consts.err.bad_content, { message = i18n("prefs.wazuh_connection_failed") })
   return
end

rest_utils.answer(rest_utils.consts.success.ok, { message = i18n("prefs.wazuh_connection_ok") })
