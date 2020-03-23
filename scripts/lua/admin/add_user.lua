--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

if(haveAdminPrivileges()) then
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
   local limited_lifetime = _POST["lifetime_limited"]
   local lifetime_secs = tonumber((_POST["lifetime_secs"] or -1))

   if(username == nil or full_name == nil or password == nil or confirm_password == nil or host_role == nil or networks == nil or allowed_interface == nil) then
      print ("{ \"result\" : -1, \"message\" : \"Invalid parameters\" }")
      return
   end

   if(password ~= confirm_password) then
      print ("{ \"result\" : -1, \"message\" : \"Passwords do not match: typo?\" }")
      return
   end

   local ret = false
   username = string.lower(username)

   local allow_pcap_download_enabled = false
   if _POST["allow_pcap_download"] and _POST["allow_pcap_download"] == "1" then
     allow_pcap_download_enabled = true
   end

   if(ntop.addUser(username, full_name, password, host_role, networks, getInterfaceName(allowed_interface), host_pool_id, language, allow_pcap_download_enabled)) then
      ret = true

      if limited_lifetime and not ntop.addUserLifetime(username, lifetime_secs) then
	 ret = false
      end

   end

   if ret then
      print ("{ \"result\" : 0, \"message\" : \"User added successfully\" }")
   else
      print ("{ \"result\" : -1, \"message\" : \"Error while adding new user\" }")
   end
end
