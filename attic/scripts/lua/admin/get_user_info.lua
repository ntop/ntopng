--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local locales_utils = require "locales_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local is_admin = isAdministrator()
local requested_user = _GET["username"]

-- Non-administrators can only read back their own profile
if not is_admin then
   requested_user = _SESSION["user"]
end

if isEmptyString(requested_user) then
   print(json.encode({}))
   return
end

do
   local users_list = ntop.getUsers()
   for key, value in pairs(users_list) do
      if(key == requested_user) then
         local rc = {}

         if value["group"] == "captive_portal" then
            rc["host_pool_id"] = value["host_pool_id"]
         else
            rc["allowed_nets"] = value["allowed_nets"]
            rc["allowed_ifname"] = value["allowed_ifname"]

            if value["allowed_ifname"] ~= "" then
               rc["allowed_if_id"] = tostring(interface.name2id(value["allowed_ifname"]))
            end

            rc["allowed_host_pools"] = value["allowed_host_pools"] or ""
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

         rc["language"] = value["language"]
         rc["allow_pcap_download"] = value["allow_pcap_download"] and true or false
         rc["allow_historical_flows"] = value["allow_historical_flows"] and true or false
         rc["allow_alerts"] = value["allow_alerts"] and true or false
         rc["api_token"] = ntop.getUserAPIToken(key) or ""
         rc["username"] = key

         if is_admin then
            rc["password"] = value["password"]
         end

         rc["full_name"] = value["full_name"]
         rc["group"] = value["group"]
         rc["totp_enabled"] = ntop.isTOTPEnabled(key) and true or false

         print(json.encode(rc))
         return
      end
   end

   print(json.encode({}))
end
