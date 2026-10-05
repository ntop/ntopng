--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local username  = _POST["username"]
local host_role = _POST["user_role"]
local networks  = _POST["allowed_networks"]
local allowed_interface = _POST["allowed_interface"]
local allow_pcap_download = _POST["allow_pcap_download"]
local allow_historical_flows = _POST["allow_historical_flows"]
local allow_alerts = _POST["allow_alerts"]
local language  = _POST["user_language"]
local allowed_host_pools = _POST["allowed_host_pools"]

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

local is_admin = isAdministrator()

-- Non-administrators are allowed to change a safe subset of their own
-- preferences only (currently the interface language)
if not is_admin then
   username = _SESSION["user"]

   host_role = nil
   networks = nil
   allowed_interface = nil
   allow_pcap_download = nil
   allow_historical_flows = nil
   allow_alerts = nil
   allowed_host_pools = nil
   old_host_pool_id = nil
   new_host_pool_id = nil
end

local rc

if(username == nil) then
   rc = { result = -1, message = "Error in username" }
   print(json.encode(rc))
   return
end

username = string.lower(username)

if(host_role ~= nil) then
   if(not ntop.changeUserRole(username, host_role)) then
      rc = { result = -1, message = "Error in changing host type" }
      print(json.encode(rc))
      return
   end
end

if(networks ~= nil) then
   if(not ntop.changeAllowedNets(username, networks)) then
      rc = { result = -1, message = "Error in changing allowed networks" }
      print(json.encode(rc))
      return
   end
end

if(allowed_interface ~= nil) then
   if(not ntop.changeAllowedIfname(username, getInterfaceName(allowed_interface))) then
      rc = { result = -1, message = "Error in changing the allowed interface" }
      print(json.encode(rc))
      return
   end
end

if is_admin then
   -- NOTE: these are always enforced (an unchecked switch means "revoke"), so
   -- they must not run when the request does not come from an administrator
   local allow_pcap_download_enabled = false
   if allow_pcap_download and allow_pcap_download == "1" then
      allow_pcap_download_enabled = true
   end
   if(not ntop.changePcapDownloadPermission(username, allow_pcap_download_enabled)) then
      rc = { result = -1, message = "Error in changing user permission" }
      print(json.encode(rc))
      return
   end

   local allow_historical_flows_enabled = false
   if allow_historical_flows and allow_historical_flows == "1" then
      allow_historical_flows_enabled = true
   end
   if(not ntop.changeHistoricalFlowPermission(username, allow_historical_flows_enabled)) then
      rc = { result = -1, message = "Error in changing user historical flow permission" }
      print(json.encode(rc))
      return
   end

   local allow_alerts_enabled = false
   if allow_alerts and allow_alerts == "1" then
      allow_alerts_enabled = true
   end
   if(not ntop.changeAlertsPermission(username, allow_alerts_enabled)) then
      rc = { result = -1, message = "Error in changing user alerts permission" }
      print(json.encode(rc))
      return
   end
end

if(language ~= nil) then
   if(not ntop.changeUserLanguage(username, language)) then
      rc = { result = -1, message = "Error in changing the user language" }
      print(json.encode(rc))
      return
   end
end

if(new_host_pool_id ~= nil and old_host_pool_id ~= nil and new_host_pool_id ~= old_host_pool_id) then
   if(not ntop.changeUserHostPool(username, new_host_pool_id)) then
      rc = { result = -1, message = "Error in changing the host pool id" }
      print(json.encode(rc))
      return
   end
end

if(allowed_host_pools ~= nil) then
   if(not ntop.changeAllowedHostPools(username, allowed_host_pools)) then
      rc = { result = -1, message = "Error in changing the allowed host pools" }
      print(json.encode(rc))
      return
   end
end

rc = { result = 0, message = "Parameters Updated" }
print(json.encode(rc))
