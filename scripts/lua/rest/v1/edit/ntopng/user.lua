--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local rest_utils = require("rest_utils")

--
-- Edit a ntopng user
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"username": "mario", "full_name": "Mario Rossi", "user_role": "unprivileged", "allowed_interface": "", "allowed_networks": "0.0.0.0/0,::/0", "user_language": "en"}' http://localhost:3000/lua/rest/v1/edit/ntopng/user.lua
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
local host_role = _POST["user_role"]
local host_pool_id = _POST["host_pool_id"]
local networks = _POST["allowed_networks"]
local allowed_interface = _POST["allowed_interface"]
local language = _POST["user_language"]
local allow_pcap_download = _POST["allow_pcap_download"]
local password = _POST["password"]
local confirm_password = _POST["confirm_password"]

if username == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res)
   return
end

if host_role == nil and
   networks == nil and
   allowed_interface == nil and
   allow_pcap_download == nil and 
   language == nil and
   full_name == nil and
   (password == nil or confirm_password == nil) and
   host_pool_id == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res)
   return
end

username = string.lower(username)

local all_users = ntop.getUsers()
if(all_users[username] == nil) then
   -- User doesn't exist
   rest_utils.answer(rest_utils.consts.err.user_does_not_exist, res)
   return
end

if(full_name ~= nil) then
   if(not ntop.changeUserFullName(username, full_name)) then
      rest_utils.answer(rest_utils.consts.err.edit_user_failed, res)
      return
   end
end

if(host_role ~= nil) then
   if(not ntop.changeUserRole(username, host_role)) then
      rest_utils.answer(rest_utils.consts.err.edit_user_failed, res)
      return
   end
end

if(networks ~= nil) then
   if(not ntop.changeAllowedNets(username, networks)) then
      rest_utils.answer(rest_utils.consts.err.edit_user_failed, res)
      return
   end
end

if(host_pool_id ~= nil) then
   if(not ntop.changeUserHostPool(username, host_pool_id)) then
      rest_utils.answer(rest_utils.consts.err.edit_user_failed, res)
      return
   end
end

if(allowed_interface ~= nil) then
   if(not ntop.changeAllowedIfname(username, getInterfaceName(allowed_interface))) then
      rest_utils.answer(rest_utils.consts.err.edit_user_failed, res)
      return
   end
end

if(allow_pcap_download ~= nil) then
   local allow_pcap_download_enabled = false
   if(tonumber(allow_pcap_download) == 1) then
      allow_pcap_download_enabled = true;
   end
   if(not ntop.changeUserPermission(username, allow_pcap_download_enabled)) then
      rest_utils.answer(rest_utils.consts.err.edit_user_failed, res)
      return
   end
end

if(language ~= nil) then
   if(not ntop.changeUserLanguage(username, language)) then
      rest_utils.answer(rest_utils.consts.err.edit_user_failed, res)
      return
   end
end

if(password ~= nil and confirm_password ~= nil) then
   -- Note: the old password is not required here as the admin is doing the request

   if(password ~= confirm_password) then
      rest_utils.answer(rest_utils.consts.err.password_mismatch, res)
      return
   end

   if(ntop.resetUserPassword(_SESSION["user"], username, "", password)) then
      rest_utils.answer(rest_utils.consts.err.edit_user_failed, res)
   end
end

rest_utils.answer(rc, res)
