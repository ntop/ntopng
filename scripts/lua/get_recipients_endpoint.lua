--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
local notification_recipients = require("notification_recipients")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

if (not isAdministrator()) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "The user doesn't have the privileges to get notification endpoint recipients!")
    reportError("The user doesn't have the privileges to get notification endpoint recipients!")
end

local recipients = notification_recipients.get_recipients()

print(json.encode(recipients))
