--
-- (C) 2016-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local discover = require "discover_utils"

local presets_utils = {}

presets_utils.DROP = "0"
presets_utils.ALLOW = "1"
presets_utils.DEFAULT_ACTION = presets_utils.DROP

-- Default presets
-- Note: 'unknown' is also used for device types with no preset defined here
presets_utils.client_allowed = {
   ['unknown'] = {
     18,   -- DHCP
      5,   -- DNS
      7,   -- HTTP
   },
   ['nas'] = { 
     18,   -- DHCP
      5,   -- DNS
      7,   -- HTTP
   },
}
presets_utils.server_allowed = {
   ['unknown'] = {
     18,   -- DHCP
      5,   -- DNS
   },
   ['nas'] = { 
      7,   -- HTTP
      1,   -- FTP_CONTROL
      175, -- FTP_DATA
   },
}

local drop_icon = "warning"
local allow_icon = "check"
local drop_text = i18n("device_protocols.alert")
local allow_text = i18n("device_protocols.ok")
if ntop.isnEdge() then
   drop_icon = "ban"
   allow_icon = "asterisk"
   drop_text = i18n("users.shapers.drop")
   allow_text = i18n("users.shapers.drop")
end

-- Constants
presets_utils.actions = {
   { name = "DROP",  id = presets_utils.DROP, text = drop_text,
     icon = '<i class="fa fa-'..drop_icon..'" aria-hidden="true"></i>'},
   { name = "ALLOW", id = presets_utils.ALLOW, text = allow_text,
     icon = '<i class="fa fa-'..allow_icon..'" aria-hidden="true"></i>'},
  }

interface.select(ifname)

-- Action ID to action name
function presets_utils.nedge_action_id_to_action(action_id)
   for _, action in pairs(presets_utils.actions) do
      if action.id == tostring(action_id) then
	 return action
      end
   end
end

-- Return device policies redis key
function presets_utils.getDevicePoliciesKey(device_type, client_or_server)
   return "ntopng.prefs.device_policies."..client_or_server.."." .. device_type
end

-- Return device policies 'initialized' redis key
function presets_utils.getDevicePoliciesInitializedKey(device_type)
   return "ntopng.prefs.device_policies." .. device_type .. ".initialized"
end

-- Return device policy for a protocol
function presets_utils.getDeviceProtoPolicy(device_type, client_or_server, proto_id)
   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)

   local action_id = ntop.getHashCache(key, proto_id)

   if not isEmptyString(action_id) then
      return action_id
   end

   return presets_utils.DEFAULT_ACTION
end

function presets_utils.deleteDeviceProto(device_type, client_or_server, proto_id)
   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)
   ntop.delHashCache(key, proto_id)
end

function presets_utils.setDeviceProtoAction(device_type, client_or_server, proto_id, action_id)
   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)
   ntop.setHashCache(key, proto_id, action_id)
end

function presets_utils.updateDeviceProto(device_type, client_or_server, proto, action_id)
   -- debug
   -- tprint("Setting "..client_or_server.." device "..device_type.." proto "..proto.." to ".. presets_utils.nedge_action_id_to_action(action_id).name)

   if action_id == presets_utils.DEFAULT_ACTION then
      presets_utils.deleteDeviceProto(device_type, client_or_server, proto)
   else
      presets_utils.setDeviceProtoAction(device_type, client_or_server, proto, action_id)
   end
end

-- Checks if device policies have been initialised for a device type 
function presets_utils.devicePoliciesInitialized(device_type)
   local key = presets_utils.getDevicePoliciesInitializedKey(device_type)
   local v = ntop.getCache(key)
   if not isEmptyString(v) then
      return true
   end
   return false
end

function presets_utils.setDevicePoliciesInitialized(device_type)
   local key = presets_utils.getDevicePoliciesInitializedKey(device_type)
   ntop.setCache(key, "1")
end

-- Reload policies in the datapath
function presets_utils.reloadDevicePolicies(device_type)
   ntop.reloadDevicePresets(tonumber(device_type))
end

-- Init device policies (initialise redis from presets if not initialised for a device type)
function presets_utils.initPolicies()
   for device_type, info in discover.sortedDeviceTypeLabels() do
      local type_name = info[1]
      local label = info[2]
      if not presets_utils.devicePoliciesInitialized(device_type) then
         local device_type_name = discover.id2devtype(device_type)
         local presets = presets_utils.client_allowed[device_type_name]
         if presets == nil then
            traceError(TRACE_WARNING, TRACE_CONSOLE, "No default presets found for '" .. device_type_name .. "' devices as client, using presets of 'unknown' devices")
            presets = presets_utils.client_allowed["unknown"]
         end
         for k,v in pairs(presets) do
            presets_utils.updateDeviceProto(device_type, "client", v, presets_utils.ALLOW)
         end
         presets = presets_utils.server_allowed[device_type_name]
         if presets == nil then
            traceError(TRACE_WARNING, TRACE_CONSOLE, "No default presets found for '" .. device_type_name .. "' devices as server, using presets of 'unknown' devices")
            presets = presets_utils.server_allowed["unknown"]
         end
         for k,v in pairs(presets) do
            presets_utils.updateDeviceProto(device_type, "server", v, presets_utils.ALLOW)
         end
         presets_utils.setDevicePoliciesInitialized(device_type)
      end
      presets_utils.reloadDevicePolicies(device_type)
   end
end

-- Return a list of policy for 'client' or 'server'
function presets_utils.getDevicePoliciesByDir(device_type, client_or_server)
   local device_proto_presets = {}

   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)
   local proto_ids = ntop.getHashKeysCache(key) or {}

   for proto_id,_ in pairs(proto_ids) do
      local protoName = interface.getnDPIProtoName(tonumber(proto_id))
      local p = { protoId=proto_id }
      p.actionId = presets_utils.getDeviceProtoPolicy(device_type, client_or_server, proto_id)
      device_proto_presets[protoName] = p
   end

   return device_proto_presets
end

-- Return a list of policy
function presets_utils.getDevicePolicies(device_type)
   local device_proto_presets = {}

   local client_device_proto_presets = presets_utils.getDevicePoliciesByDir(device_type, "client")
   local server_device_proto_presets = presets_utils.getDevicePoliciesByDir(device_type, "server")

   for k,v in pairs(client_device_proto_presets) do 
      local p = { protoId=v.proto_id }
      p.clientActionId=v.actionId
      device_proto_presets[k] = p
   end   

   for k,v in pairs(server_device_proto_presets) do
      local p = device_proto_presets[k]
      if p == nil then
         p = { protoId=v.proto_id }
      end
      p.serverActionId=v.actionId
      device_proto_presets[k] = p
   end   

   return device_proto_presets
end

--------------------------------------------------------------------------------

return presets_utils
