--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")
local recording_utils = require "recording_utils"

local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if _POST then
   local ifid = tonumber(_POST["ifid"])
   local dismiss_external_providers_reminder = _POST["dismiss_external_providers_reminder"]

   if ifid ~= nil and not isEmptyString(dismiss_external_providers_reminder) then
      if dismiss_external_providers_reminder == "true" then
	 recording_utils.dismissExternalProvidersReminder(ifid)
      end
   end
end

sendHTTPContentTypeHeader('application/json')

print(json.encode({status = "OK"}))
