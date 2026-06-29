--
-- (C) 2014-26 - ntop.org
--
-- GET /lua/rest/v2/get/ntopng/test_url_connectivity.lua
--
-- Tests whether a URL is reachable from ntopng.
-- Used by the Vue preferences page for Wazuh, LLM provider URLs, etc.
--
-- Query params:
--   url  - the URL to test (required)
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

local url = _GET["url"] or ""

if isEmptyString(url) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { message = i18n("prefs.missing_url") })
   return
end

-- Strip trailing slash for cleaner display
url = url:gsub("/$", "")

local rc = ntop.httpGet(url, nil, nil, 5 --[[timeout secs]], true --[[return_content]])

if rc == nil then
   rest_utils.answer(rest_utils.consts.err.bad_content, {
      message = i18n("prefs.wazuh_unreachable") or
         "Unable to reach the server. Check the URL and network connectivity, or start ntopng with --insecure for unsafe TLS certificates."
   })
   return
end

rest_utils.answer(rest_utils.consts.success.ok, { message = i18n("prefs.wazuh_connection_ok") or "Connection successful" })
