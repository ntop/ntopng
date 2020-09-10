--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
local recipients = require "recipients"
local recipients_instance = recipients:create()
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

if not haveAdminPrivileges(true) then
    return
end

local recipients = recipients_instance:get_all_recipients()
print(json.encode(recipients))
