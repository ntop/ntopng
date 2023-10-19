--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local endpoints = require("endpoints")
local rest_utils = require "rest_utils"
local auth = require "auth"

-- ################################################

if not auth.has_capability(auth.capabilities.notifications) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local action = _POST["action"]

sendHTTPContentTypeHeader('application/json')

local endpoint_id = _POST["endpoint_id"]
local endpoint_conf_name = _POST["endpoint_conf_name"]

local response = {}

if (action == "add") then
    local endpoint_conf_type = _POST["endpoint_conf_type"]
    response.result = endpoints.add_config(endpoint_conf_type, endpoint_conf_name, _POST)
elseif (action == "edit") then
   response.result = endpoints.edit_config(endpoint_id, endpoint_conf_name, _POST)
elseif (action == "remove") then
    response.result = endpoints.delete_config(endpoint_id)
end

print(json.encode(response))
