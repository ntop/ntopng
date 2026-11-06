--
-- (C) 2014-26 - ntop.org
--
-- GET /lua/rest/v2/get/ntopng/test_mosaic_connectivity.lua
--
-- Tests the ntop Mosaic URL and API key by classifying a known domain.
-- Query params:
--   url            - ntop Mosaic base URL (required)
--   mosaic_api_key - ntop Mosaic API key (required)
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

local url     = _GET["url"] or ""
local api_key = _GET["mosaic_api_key"] or ""

if isEmptyString(url) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { message = i18n("prefs.mosaic_missing_url") })
   return
end

if isEmptyString(api_key) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { message = i18n("prefs.mosaic_missing_api_key") })
   return
end

url = url:gsub("/+$", "")

local rc = ntop.httpGet(url .. "/classify/ntop.org", nil, nil, 8 --[[timeout]], true --[[return_content]],
                        false, false, 0, nil, api_key)

if rc == nil or type(rc) ~= "table" or rc.RESPONSE_CODE == nil or rc.RESPONSE_CODE == 0 then
   rest_utils.answer(rest_utils.consts.err.bad_content, { message = i18n("prefs.mosaic_unreachable") })
   return
end

if rc.RESPONSE_CODE == 401 or rc.RESPONSE_CODE == 403 then
   rest_utils.answer(rest_utils.consts.err.bad_content, { message = i18n("prefs.mosaic_auth_failed") })
   return
end

if rc.RESPONSE_CODE ~= 200 then
   rest_utils.answer(rest_utils.consts.err.bad_content, { message = i18n("prefs.mosaic_connection_failed") })
   return
end

rest_utils.answer(rest_utils.consts.success.ok, { message = i18n("prefs.mosaic_connection_ok") })
