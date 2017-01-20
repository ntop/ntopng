--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

username = _POST["username"]
host_role = _POST["host_role"]
networks = _POST["networks"]
allowed_interface = _POST["allowed_interface"]

-- for captive portal users
old_host_pool_id = _POST["old_host_pool_id"]
new_host_pool_id = _POST["host_pool_id"]


if(username == nil) then   
    print ("{ \"result\" : -1, \"message\" : \"Error in username\" }")
    return
end

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

if(new_host_pool_id ~= nil and old_host_pool_id ~= nil and new_host_pool_id ~= old_host_pool_id) then
   if(not ntop.changeUserHostPool(username, new_host_pool_id)) then
      print ("{ \"result\" : -1, \"message\" : \"Error in changing the host pool id\" }")
      return 
   end
end

print ("{ \"result\" : 0, \"message\" : \"Parameters Updated\" }")
