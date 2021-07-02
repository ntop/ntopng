--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local rest_utils = require("rest_utils")
local tracker = require("tracker")

--
-- Add a new ntopng user
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"username": "mario", "full_name": "Super Mario", "password": "strongpwd", "confirm_password": "strongpwd", "user_role": "unprivileged", "allowed_interface": "", "allowed_networks": "0.0.0.0/0,::/0", "user_language": "en"}' http://localhost:3000/lua/rest/v1/add/ntopng/user.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted, res)
   return
end

local username = _POST["username"]
local full_name = _POST["full_name"]
local password = _POST["password"]
local confirm_password = _POST["confirm_password"]
local host_role = _POST["user_role"]
local networks = _POST["allowed_networks"]
local allowed_interface = _POST["allowed_interface"]
local language = _POST["user_language"]
local allow_pcap_download = _POST["allow_pcap_download"]
local host_pool_id = _POST["host_pool_id"]

if username == nil or full_name == nil or password == nil or
   confirm_password == nil or host_role == nil or networks == nil or
   allowed_interface == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res)
   return
end

if(password ~= confirm_password) then
   -- "Passwords do not match: typo?"
   rest_utils.answer(rest_utils.consts.err.password_mismatch, res)
   return
end

username = string.lower(username)

local all_users = ntop.getUsers()

if(all_users[username] ~= nil) then
   -- User already existing
   rest_utils.answer(rest_utils.consts.err.user_already_existing, res)
   return
end


local allow_pcap_download_enabled = false
if _POST["allow_pcap_download"] and _POST["allow_pcap_download"] == "1" then
   allow_pcap_download_enabled = true
end

if not ntop.addUser(username, full_name, password, host_role, networks, 
		    getInterfaceName(allowed_interface), host_pool_id, language, allow_pcap_download_enabled) then
   rest_utils.answer(rest_utils.consts.err.add_user_failed, res)
   return
end

rest_utils.answer(rc, res)
   
-- TRACKER HOOK
-- Note: already tracked by ntop.addUser
-- tracker.log('add_ntopng_user', { username = username })

