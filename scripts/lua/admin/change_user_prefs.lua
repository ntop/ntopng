--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

local username  = _POST["username"]
local host_role = _POST["user_role"]
local networks  = _POST["allowed_networks"]
local allowed_interface = _POST["allowed_interface"]
local allow_pcap_download = _POST["allow_pcap_download"]
local language  = _POST["user_language"]

-- for captive portal users
local old_host_pool_id = _POST["old_host_pool_id"]
local new_host_pool_id = _POST["host_pool_id"]

if(false) then
   io.write("\n")
   for k,v in pairs(_POST) do
      local s = k.."="..v.."\n"
      io.write(s)
   end
end

if(username == nil) then
    print ("{ \"result\" : -1, \"message\" : \"Error in username\" }")
    return
end

username = string.lower(username)

if(host_role ~= nil) then
  if(not ntop.changeUserRole(username, host_role)) then
    print ("{ \"result\" : -1, \"message\" : \"Error in changing host type\" }")
    return
  end
end

if(networks ~= nil) then
  if(not ntop.changeAllowedNets(username, networks)) then
    print ("{ \"result\" : -1, \"message\" : \"Error in changing allowed networks\" }")
    return
  end
end

if(allowed_interface ~= nil) then
   if(not ntop.changeAllowedIfname(username, getInterfaceName(allowed_interface))) then
     print ("{ \"result\" : -1, \"message\" : \"Error in changing the allowed interface\" }")
     return
   end
end

local allow_pcap_download_enabled = false
if allow_pcap_download and allow_pcap_download == "1" then
  allow_pcap_download_enabled = true;
end
if(not ntop.changeUserPermission(username, allow_pcap_download_enabled)) then
   print ("{ \"result\" : -1, \"message\" : \"Error in changing user permission\" }")
   return
end

if(language ~= nil) then
   if(not ntop.changeUserLanguage(username, language)) then
      print ("{ \"result\" : -1, \"message\" : \"Error in changing the user language\" }")
      return
   end
end

if(new_host_pool_id ~= nil and old_host_pool_id ~= nil and new_host_pool_id ~= old_host_pool_id) then
   if(not ntop.changeUserHostPool(username, new_host_pool_id)) then
      print ("{ \"result\" : -1, \"message\" : \"Error in changing the host pool id\" }")
      return
   end
end

print ("{ \"result\" : 0, \"message\" : \"Parameters Updated\" }")
