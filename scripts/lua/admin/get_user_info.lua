--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

if(isAdministratorOrPrintErr()) then
   print("{\n")

   local users_list = ntop.getUsers()
   for key, value in pairs(users_list) do
      if(key == _GET["username"]) then

	 if value["group"] == "captive_portal" then
	    print(' "host_pool_id": "'..value["host_pool_id"]..'",\n')
	 else
	    print(' "allowed_nets": "'..value["allowed_nets"]..'",\n')
	    print(' "allowed_ifname": "'..value["allowed_ifname"]..'",\n')

	    if(value["allowed_ifname"] ~= "") then
	       local iface_id = interface.name2id(value["allowed_ifname"])
	       print(' "allowed_if_id": "'..iface_id..'",\n')
	    end
	 end

	 -- handle the user language
	 if isEmptyString(value["language"]) then
	    value["language"] = locales_utils.default_locale
	 else
	    local available_locale = false

	    for _, l in ipairs(locales_utils.getAvailableLocales()) do
	       if l["code"] == value["language"] then
		  available_locale = true
		  break
	       end
	    end

	    if not available_locale then
	       value["language"] = locales_utils.default_locale
	    end
	 end
	 print(' "language": "'..value["language"]..'",\n')
         if value["allow_pcap_download"] then
           print(' "allow_pcap_download": true,\n')
         end
		
	local api_token = ntop.getUserAPIToken(key) or ""

	 print(' "username": "'..key..'",\n')
	 print(' "api_token": "' ..api_token.. '",\n')
	 print(' "password": "'..value["password"]..'",\n')
	 print(' "full_name": "'..value["full_name"]..'",\n')
	 print(' "group": "'..value["group"]..'"\n')

      end
   end

   print("}")
end
