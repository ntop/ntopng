--
-- (C) 2016-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local discover = require "discover_utils"

interface.select(ifname)

local presets_utils = {}

presets_utils.DROP = "0"
presets_utils.ALLOW = "1"
presets_utils.DEFAULT_ACTION = presets_utils.DROP

presets_utils.policies = {}

-- Note: 'unknown' devices and all devices not listed here have 'allow all' as default

-- Create an empty preset for a device type if it does not exist
function presets_utils.createPreset(device_type_name)
   if presets_utils.policies[device_type_name] == nil then
      presets_utils.policies[device_type_name] = { client = {}, server = {} }
   end
end

-- Add client and server policies to a device type
function presets_utils.addPreset(device_type_name, source_preset)
   presets_utils.createPreset(device_type_name)
   presets_utils.policies[device_type_name].client = 
      table.merge(presets_utils.policies[device_type_name].client, source_preset.client)
   presets_utils.policies[device_type_name].server = 
      table.merge(presets_utils.policies[device_type_name].server, source_preset.server)
end

-- Add policies to a device type cloning policies from another device type
function presets_utils.addPresetFrom(device_type_name, source_device_type_name)
   presets_utils.addPreset(device_type_name,
      presets_utils.policies[source_device_type_name])
end

-- Add policy for a specific protocol to a device type
function presets_utils.addProtocol(device_type_name, client_or_server, proto_id, action)
   presets_utils.createPreset(device_type_name)
   presets_utils.policies[device_type_name][client_or_server][tonumber(proto_id)] = action
end

-- Add policy for a specific protocol (by name) to a device type
function presets_utils.addProtocolByName(device_type_name, client_or_server, proto_name, action)
   presets_utils.createPreset(device_type_name)
   local proto_id = interface.getnDPIProtoId(proto_name)
   presets_utils.policies[device_type_name][client_or_server][tonumber(proto_id)] = action
end

function presets_utils.setAllProtocols(device_type_name, client_or_server, action)
   presets_utils.createPreset(device_type_name)
   local items = interface.getnDPIProtocols(nil, true)
   for proto_name,proto_id in pairs(items) do
      presets_utils.policies[device_type_name][client_or_server][tonumber(proto_id)] = action
   end
end

-----------------------------------------------------------------------------
-- DEVICE PROTOCOL PRESETS
-----------------------------------------------------------------------------

local basic_policy = {
   client = { 
      [ 18] = presets_utils.ALLOW, -- DHCP
      [  5] = presets_utils.ALLOW  -- DNS
   }, 
   server = {}
}

presets_utils.addPreset('multimedia', basic_policy)
presets_utils.addProtocolByName('multimedia', 'client', 'HTTP', presets_utils.ALLOW)
presets_utils.addProtocolByName('multimedia', 'client', 'NetFlix', presets_utils.ALLOW)
presets_utils.addProtocolByName('multimedia', 'client', 'YouTube', presets_utils.ALLOW)

presets_utils.addPresetFrom('nas', 'multimedia')
presets_utils.addProtocolByName('nas', 'server', 'HTTP',        presets_utils.ALLOW)
presets_utils.addProtocolByName('nas', 'server', 'FTP_CONTROL', presets_utils.ALLOW)
presets_utils.addProtocolByName('nas', 'server', 'FTP_DATA',    presets_utils.ALLOW)

presets_utils.addPreset('laptop', basic_policy)
presets_utils.setAllProtocols('laptop', 'client', presets_utils.ALLOW)
presets_utils.addProtocolByName('laptop', 'client', 'Corba', presets_utils.DROP)

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------

local drop_icon = "warning"
local allow_icon = "check"
local drop_text = i18n("device_protocols.alert")
local allow_text = i18n("device_protocols.ok")
if ntop.isnEdge() then
   drop_icon = "ban"
   allow_icon = "asterisk"
   drop_text = i18n("users.shapers.drop")
   allow_text = i18n("users.shapers.default")
end

-- Constants
presets_utils.actions = {
   { name = "DROP",  id = presets_utils.DROP, text = drop_text,
     icon = '<i class="fa fa-'..drop_icon..'" aria-hidden="true"></i>'},
   { name = "ALLOW", id = presets_utils.ALLOW, text = allow_text,
     icon = '<i class="fa fa-'..allow_icon..'" aria-hidden="true"></i>'},
}

-- Action ID to action name
function presets_utils.actionIDToAction(action_id)
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

-- Check if a protocol is allowed by the default presets
function presets_utils.isProtoAllowedByPresets(device_type, client_or_server, proto_id)
   local device_type_name = discover.id2devtype(tonumber(device_type))
   if presets_utils.policies[device_type_name] == nil or
      presets_utils.policies[device_type_name][client_or_server] == nil then
      return true -- no preset: allowed
   end

   if presets_utils.policies[device_type_name][client_or_server][proto_id] == presets_utils.ALLOW then
      return true
   end

   return false
end

-- Check if the device policy for a protocol is set on redis
function presets_utils.isDeviceProtoPolicySet(device_type, client_or_server, proto_id)
   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)

   local action_id = ntop.getHashCache(key, proto_id)

   if not isEmptyString(action_id) then
      return true
   end

   return false
end

-- Return device policy for a protocol from redis
function presets_utils.getDeviceProtoPolicy(device_type, client_or_server, proto_id)
   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)

   local action_id = ntop.getHashCache(key, proto_id)

   if not isEmptyString(action_id) then
      return action_id
   end

   return presets_utils.DEFAULT_ACTION
end

-- Delete the device policy for a protocol from redis
function presets_utils.deleteDeviceProto(device_type, client_or_server, proto_id)
   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)
   ntop.delHashCache(key, proto_id)
end

-- Store the device policy for a protocol on redis
function presets_utils.setDeviceProtoAction(device_type, client_or_server, proto_id, action_id)
   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)
   ntop.setHashCache(key, proto_id, action_id)
end

-- Update the device policy for a protocol on redis
function presets_utils.updateDeviceProto(device_type, client_or_server, proto_id, action_id)
   local proto_name = interface.getnDPIProtoName(tonumber(proto_id))

   if presets_utils.isDeviceProtoPolicySet(device_type, client_or_server, proto_id) then
      -- the user changed this policy, storing the change on redis
      presets_utils.setDeviceProtoAction(device_type, client_or_server, proto_id, action_id)

   elseif action_id == presets_utils.ALLOW and presets_utils.isProtoAllowedByPresets(device_type, client_or_server, proto_id) then
      -- it seems this has not been changed by the user, nothing to do

   else
      -- preset changed by the user, seting custom user-defined action on redis
      presets_utils.setDeviceProtoAction(device_type, client_or_server, proto_id, action_id)
   end
end

-- Return the list of user-defined policies (allow and drop) for 'client' or 'server' from redis
function presets_utils.getCustomDevicePoliciesByDir(device_type, client_or_server)
   local custom_policies = {}

   local key = presets_utils.getDevicePoliciesKey(device_type, client_or_server)
   local proto_ids = ntop.getHashKeysCache(key) or {}

   for proto_id,_ in pairs(proto_ids) do
      local proto_name = interface.getnDPIProtoName(tonumber(proto_id))
      local p = { protoId=proto_id, protoName=proto_name }
      p.actionId = presets_utils.getDeviceProtoPolicy(device_type, client_or_server, proto_id)
      -- tprint("Custom policy for device "..device_type.." protocol "..proto_name.." action is "..p.actionId)
      custom_policies[tonumber(proto_id)] = p
   end

   return custom_policies
end

-- Return the list of policies (allow only) for 'client' or 'server' merging preset policies with user-defined policies
function presets_utils.getDevicePoliciesByDir(device_type, client_or_server)
   local device_type_name = discover.id2devtype(tonumber(device_type))
   local device_policies = {}

   -- read custom user-defined policies from redis

   local custom_policies = presets_utils.getCustomDevicePoliciesByDir(device_type, client_or_server) 

   -- init protocols from presets

   if presets_utils.policies[device_type_name] ~= nil and 
      presets_utils.policies[device_type_name][client_or_server] ~= nil then
      for proto_id,action_id in pairs(presets_utils.policies[device_type_name][client_or_server]) do
         -- add allowed protocol, unless the user set it to not allow
         if custom_policies[proto_id] == nil or not custom_policies[proto_id].actionId == presets_utils.DROP then
            if action_id == presets_utils.ALLOW then
               local proto_name = interface.getnDPIProtoName(tonumber(proto_id))
               local p = { protoId=proto_id, protoName=proto_name, actionId=action_id }
            -- tprint("Preset policy for device "..device_type.." protocol "..proto_name.." action is "..p.actionId)
               device_policies[tonumber(proto_id)] = p
            end
         end
      end
   else
      -- device with no preset (including 'unknown') - allow all by default 
      local items = interface.getnDPIProtocols(nil, true)
      for proto_name,proto_id in pairs(items) do
         -- add allowed protocol, unless the user set it to not allow
         if custom_policies[proto_id] == nil or not custom_policies[proto_id].actionId == presets_utils.DROP then
            local p = { protoId=proto_id, protoName=proto_name, actionId=presets_utils.ALLOW }
            -- tprint("Using 'Unknown' policy for device "..device_type.." protocol "..proto_name.." action is "..p.actionId)
            device_policies[tonumber(proto_id)] = p
         end
      end
   end

   -- set allowed user-defined protocols

   for k,v in pairs(custom_policies) do 
      if v.actionId == presets_utils.ALLOW then
         device_policies[tonumber(v.protoId)] = v
         -- tprint("Custom policy for device "..device_type.." protocol "..v.protoName.." action is "..v.actionId)
      end
   end   

   return device_policies
end

-- Check if a protocol is allowed
function presets_utils.isProtoAllowed(device_type, client_or_server, proto_id)
   local device_type_name = discover.id2devtype(tonumber(device_type))

   local device_policies = presets_utils.getDevicePoliciesByDir(device_type, client_or_server)
   local policy = device_policies[tonumber(proto_id)]
   if policy ~= nil and policy.actionId == presets_utils.ALLOW then
      return true
   end   

   return false
end

-- Reload client or server device policies in the datapath
function presets_utils.reloadDevicePoliciesByDir(device_type, client_or_server)
   local device_type_name = discover.id2devtype(tonumber(device_type))
   local allowed_protocols = {}

   local device_policies = presets_utils.getDevicePoliciesByDir(device_type, client_or_server)
   for k,v in pairs(device_policies) do 
      if v.actionId == presets_utils.ALLOW then
         allowed_protocols[tonumber(v.protoId)] = tonumber(presets_utils.ALLOW)
      end
   end   

   ntop.reloadDeviceProtocols(tonumber(device_type), client_or_server, allowed_protocols)
end

-- Reload device policies in the datapath
function presets_utils.reloadDevicePolicies(device_type)
   presets_utils.reloadDevicePoliciesByDir(device_type, "client")
   presets_utils.reloadDevicePoliciesByDir(device_type, "server")
end

-- Init protocol policies for all devices
function presets_utils.initPolicies()
   for device_type, info in discover.sortedDeviceTypeLabels() do
      presets_utils.reloadDevicePolicies(device_type)
   end
end

-- Return a list of policy for a device (both client and server)
function presets_utils.getDevicePolicies(device_type)
   local device_policies = {}

   local client_device_policies = presets_utils.getDevicePoliciesByDir(device_type, "client")
   local server_device_policies = presets_utils.getDevicePoliciesByDir(device_type, "server")

   for k,v in pairs(client_device_policies) do 
      local p = { protoId=v.proto_id }
      p.clientActionId=v.actionId
      device_policies[k] = p
   end   

   for k,v in pairs(server_device_policies) do
      local p = device_policies[k]
      if p == nil then
         p = { protoId=v.proto_id }
      end
      p.serverActionId=v.actionId
      device_policies[k] = p
   end   

   return device_policies
end


function presets_utils.resetDevicePoliciesFromPresets(device_type)
   local key_client = presets_utils.getDevicePoliciesKey(device_type, "client")
   local key_server = presets_utils.getDevicePoliciesKey(device_type, "server")

   ntop.delCache(key_client)
   ntop.delCache(key_server)
end

--------------------------------------------------------------------------------

return presets_utils
