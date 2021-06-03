--
-- (C) 2016-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local discover = require "discover_utils"

local presets_utils = {}

presets_utils.DROP = "0"
presets_utils.ALLOW = "1"
presets_utils.DEFAULT_ACTION = presets_utils.DROP

presets_utils.policies = {}

-- Create an empty preset for a device type if it does not exist
local function createPreset(device_type_name)
   if presets_utils.policies[device_type_name] == nil then
      presets_utils.policies[device_type_name] = { client = {}, server = {} }
   end
end

-- Add policies to a device type cloning policies from an initial device type.
-- source_preset is a table
local function addPreset(device_type_name, source_preset)
   createPreset(device_type_name)
   presets_utils.policies[device_type_name].client = 
      table.merge(presets_utils.policies[device_type_name].client, source_preset.client)
   presets_utils.policies[device_type_name].server = 
      table.merge(presets_utils.policies[device_type_name].server, source_preset.server)
end

-- Add policies to a device type cloning policies from another device type.
-- source_device_type_name is the string identifying the source device type
local function addPresetFrom(device_type_name, source_device_type_name)
   addPreset(device_type_name,
      presets_utils.policies[source_device_type_name])
end

-- Add policy for a specific protocol to a device type
local function addProtocol(device_type_name, client_or_server, proto_id, action)
   createPreset(device_type_name)
   presets_utils.policies[device_type_name][client_or_server][tonumber(proto_id)] = action
end

-- Add policy for a specific protocol (by name) to a device type
local function addProtocolByName(device_type_name, client_or_server, proto_name, action)
   createPreset(device_type_name)
   local proto_id = interface.getnDPIProtoId(proto_name)

   if(proto_id == -1) then
      traceError(TRACE_WARNING, TRACE_CONSOLE, "Unknown device protocol: " .. proto_name)
   end

   presets_utils.policies[device_type_name][client_or_server][tonumber(proto_id)] = action
end

local function setAllProtocols(device_type_name, client_or_server, action)
   createPreset(device_type_name)
   local items = interface.getnDPIProtocols(nil, true)
   for proto_name,proto_id in pairs(items) do
      presets_utils.policies[device_type_name][client_or_server][tonumber(proto_id)] = action
   end
end

function presets_utils.init()
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   -- DEVICE PROTOCOL PRESETS
   -- Note: 
   -- - 'unknown' devices and all devices not listed here have 'allow all' as default
   -- - 'DHCP' and 'DNS' are always allowed in the datapath

   local basic_policy = {
      client = {
	 [  8] = presets_utils.ALLOW,  -- MDNS
	 [  9] = presets_utils.ALLOW,  -- NTP
	 [ 10] = presets_utils.ALLOW,  -- NetBIOS
	 [ 81] = presets_utils.ALLOW,  -- ICMP
	 [ 82] = presets_utils.ALLOW,  -- IGMP
	 [102] = presets_utils.ALLOW,  -- ICMPV6
	 [103] = presets_utils.ALLOW,  -- DHCPV6
	 [153] = presets_utils.ALLOW,  -- UPnP
	 [154] = presets_utils.ALLOW,  -- LLMNR
      },
      server = {
	 [ 81] = presets_utils.ALLOW,  -- ICMP
	 [102] = presets_utils.ALLOW,  -- ICMPV6
      }
   }

   -- IoT like devices
   addPreset('iot', basic_policy)
   addProtocolByName('iot', 'client', 'HTTP',      presets_utils.ALLOW)
   addProtocolByName('iot', 'server', 'HTTP',      presets_utils.ALLOW)
   addProtocolByName('iot', 'client', 'TLS',       presets_utils.ALLOW)
   addProtocolByName('iot', 'server', 'TLS',       presets_utils.ALLOW)

   addPresetFrom('video', 'iot')
   addProtocolByName('video', 'server', 'RTP',     presets_utils.ALLOW)
   addProtocolByName('video', 'server', 'RTSP',    presets_utils.ALLOW)

   -- Multimedia like devices
   addPreset('multimedia', basic_policy)
   addProtocolByName('multimedia', 'client', 'HTTP',        presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'TLS',         presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'RTP',         presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'RTSP',        presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'NetFlix',     presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'YouTube',     presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'AmazonVideo', presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'AppleiTunes', presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'Deezer',      presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'LastFM',      presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'SoundCloud',  presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'Spotify',     presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'Skype_Teams', presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'SkypeCall',   presets_utils.ALLOW)
   addProtocolByName('multimedia', 'client', 'SSDP',        presets_utils.ALLOW)

   addPresetFrom('tv', 'multimedia')

   -- NAS devices
   addPreset('nas', basic_policy)
   addProtocolByName('nas', 'server', 'HTTP',        presets_utils.ALLOW)
   addProtocolByName('nas', 'server', 'FTP_CONTROL', presets_utils.ALLOW)
   addProtocolByName('nas', 'server', 'FTP_DATA',    presets_utils.ALLOW)
   addProtocolByName('nas', 'server', 'AFP',         presets_utils.ALLOW)
   addProtocolByName('nas', 'server', 'NFS',         presets_utils.ALLOW)
   addProtocolByName('nas', 'server', 'RSYNC',       presets_utils.ALLOW)
   addProtocolByName('nas', 'server', 'TFTP',        presets_utils.ALLOW)

   -- Printer devices
   addPreset('printer', basic_policy)
   addProtocolByName('printer', 'server', 'HTTP',    presets_utils.ALLOW)
   addProtocolByName('printer', 'server', 'TLS',     presets_utils.ALLOW)
   addProtocolByName('printer', 'server', 'SNMP',    presets_utils.ALLOW)

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
end

local drop_icon = "exclamation-triangle"
local allow_icon = "check"
local drop_text = i18n("device_protocols.alert")
local allow_text = i18n("device_protocols.ok")
local is_nedge = ntop.isnEdge()

if is_nedge then
   drop_icon = "ban"
   allow_icon = "asterisk"
   drop_text = i18n("users.shapers.drop")
   allow_text = i18n("users.shapers.default")
end

-- Constants
presets_utils.actions = {
   { name = "DROP",  id = presets_utils.DROP, text = drop_text,
     icon = '<i class="fas fa-'..drop_icon..'" aria-hidden="true"></i>'},
   { name = "ALLOW", id = presets_utils.ALLOW, text = allow_text,
     icon = '<i class="fas fa-'..allow_icon..'" aria-hidden="true"></i>'},
}

-- Action ID to action name
function presets_utils.actionIDToAction(action_id)
   for _, action in pairs(presets_utils.actions) do
      if action.id == tostring(action_id) then
	 return action
      end
   end
end

-- Check if a protocol is allowed by the default presets
local function isProtoAllowedByPresets(device_type, client_or_server, proto_id)
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

-- Return device policies redis key
local function getDevicePoliciesKey(device_type, client_or_server)
   return "ntopng.prefs.device_policies."..client_or_server.."." .. device_type
end

-- Check if the device policy for a protocol is set on redis
local function isCustomDeviceProtoPolicySet(device_type, client_or_server, proto_id)
   local key = getDevicePoliciesKey(device_type, client_or_server)

   local action_id = ntop.getHashCache(key, proto_id)

   if not isEmptyString(action_id) then
      return true
   end

   return false
end

-- Return device policy for a protocol from redis
local function getCustomDeviceProtoPolicy(device_type, client_or_server, proto_id)
   local key = getDevicePoliciesKey(device_type, client_or_server)

   local action_id = ntop.getHashCache(key, proto_id)

   if not isEmptyString(action_id) then
      return action_id
   end

   return presets_utils.DEFAULT_ACTION
end

-- Store the device policy for a protocol on redis
local function setCustomDeviceProtoPolicy(device_type, client_or_server, proto_id, action_id)
   local key = getDevicePoliciesKey(device_type, client_or_server)
   ntop.setHashCache(key, proto_id, action_id)
end

-- Update the device policy for a protocol on redis
function presets_utils.updateDeviceProto(device_type, client_or_server, proto_id, action_id)
   local proto_name = interface.getnDPIProtoName(tonumber(proto_id))

   if isCustomDeviceProtoPolicySet(device_type, client_or_server, proto_id) then
      -- the user changed this policy, storing the change on redis
      setCustomDeviceProtoPolicy(device_type, client_or_server, proto_id, action_id)
   elseif action_id == presets_utils.ALLOW and isProtoAllowedByPresets(device_type, client_or_server, proto_id) then
      -- it seems this has not been changed by the user, nothing to do
   else
      -- preset changed by the user, seting custom user-defined action on redis
      setCustomDeviceProtoPolicy(device_type, client_or_server, proto_id, action_id)
   end
end

-- Return the list of user-defined policies (allow and drop) for 'client' or 'server' from redis
local function getCustomDevicePoliciesByDir(device_type, client_or_server)
   local custom_policies = {}

   local key = getDevicePoliciesKey(device_type, client_or_server)
   local proto_ids = ntop.getHashKeysCache(key) or {}

   for proto_id,_ in pairs(proto_ids) do
      local proto_name = interface.getnDPIProtoName(tonumber(proto_id))
      local p = { protoId=proto_id, protoName=proto_name }
      p.actionId = getCustomDeviceProtoPolicy(device_type, client_or_server, proto_id)
      custom_policies[tonumber(proto_id)] = p
   end

   return custom_policies
end

-- Return the list of policies (allow only) for 'client' or 'server' merging preset policies with user-defined policies
local function getDevicePoliciesByDir(device_type, client_or_server)
   local device_type_name = discover.id2devtype(tonumber(device_type))
   local device_policies = {}
   local default_action = presets_utils.ALLOW -- allow by default if no preset for the device

   if presets_utils.policies[device_type_name] ~= nil and 
      presets_utils.policies[device_type_name][client_or_server] ~= nil then
      -- device with preset, deny by default
      default_action = presets_utils.DROP
   end

   -- init
   local items = interface.getnDPIProtocols(nil, true)

   for proto_name,proto_id in pairs(items) do
      local p = { protoId=proto_id, protoName=proto_name, actionId=default_action }
      device_policies[tonumber(proto_id)] = p
   end

   -- protocols from presets
   if presets_utils.policies[device_type_name] ~= nil and 
      presets_utils.policies[device_type_name][client_or_server] ~= nil then
      for proto_id,action_id in pairs(presets_utils.policies[device_type_name][client_or_server]) do
         local proto_name = interface.getnDPIProtoName(tonumber(proto_id))
         local p = { protoId=proto_id, protoName=proto_name, actionId=action_id }
         device_policies[tonumber(proto_id)] = p
      end
   else
   end

   -- custom user-defined policies from redis
   local custom_policies = getCustomDevicePoliciesByDir(device_type, client_or_server) 
   for k,v in pairs(custom_policies) do 
      device_policies[tonumber(v.protoId)] = v
   end   

   return device_policies
end

-- Check if a protocol is allowed
function presets_utils.isProtoAllowed(device_type, client_or_server, proto_id)
   local device_type_name = discover.id2devtype(tonumber(device_type))

   local device_policies = getDevicePoliciesByDir(device_type, client_or_server)
   local policy = device_policies[tonumber(proto_id)]
   if policy ~= nil and policy.actionId == presets_utils.ALLOW then
      return true
   end   

   return false
end

-- Reload client or server device policies in the datapath
local function reloadDevicePoliciesByDir(device_type, client_or_server)
   local device_type_name = discover.id2devtype(tonumber(device_type))
   local allowed_protocols = {}

   local device_policies = getDevicePoliciesByDir(device_type, client_or_server)
   for k,v in pairs(device_policies) do 
      if v.actionId == presets_utils.ALLOW then
	 v.protoId = tonumber(v.protoId)

	 if(v.protoId ~= -1) then
	    allowed_protocols[v.protoId] = tonumber(presets_utils.ALLOW)
	 end
      end
   end   

   ntop.reloadDeviceProtocols(tonumber(device_type), client_or_server, allowed_protocols)
end

-- Reload device policies in the datapath
function presets_utils.reloadDevicePolicies(device_type)
   reloadDevicePoliciesByDir(device_type, "client")
   reloadDevicePoliciesByDir(device_type, "server")

   if is_nedge then
     -- reload the new policy on active flows
     interface.updateFlowsShapers()
   end
end

-- Reload device policies for all devices in the datapath
function presets_utils.reloadAllDevicePolicies()
   for device_type, info in discover.sortedDeviceTypeLabels() do
      presets_utils.reloadDevicePolicies(device_type)
   end
end

-- Return a list of policy for a device (both client and server)
function presets_utils.getDevicePolicies(device_type)
   local device_policies = {}

   local client_device_policies = getDevicePoliciesByDir(device_type, "client")
   local server_device_policies = getDevicePoliciesByDir(device_type, "server")

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
   local key_client = getDevicePoliciesKey(device_type, "client")
   local key_server = getDevicePoliciesKey(device_type, "server")

   ntop.delCache(key_client)
   ntop.delCache(key_server)
end

--------------------------------------------------------------------------------

return presets_utils
