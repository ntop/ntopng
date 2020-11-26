--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils" 
local system_config = require "system_config"
local json = require "dkjson"
local ipv4_utils = require "ipv4_utils"
local os_utils = require "os_utils"
local sys_utils = require "sys_utils"
local tz_utils = require "tz_utils"

-- ##############################################

-- Example 
-- package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
-- -- Editable
-- local appliance_config = require "appliance_config":create(true)
-- -- Readable
-- local appliance_config = require "appliance_config":create()

-- ##############################################

-- NOTE:
-- - The LAN interface in "passive" mode is the Management Interface
-- - WAN interfaces in "passive" mode are the Capture Interfaces

-- ##############################################

local appliance_config = {}

-- ##############################################

function appliance_config:create(editable)
   -- Instance of the base class
   local _system_config = system_config:create()

   -- Subclass using the base class instance
   self.key = "appliance"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _appliance_config = _system_config:create(self)

   if editable then
      _appliance_config:editable()
   else
      _appliance_config:readable()
   end

   -- Return the instance
   return _appliance_config
end

-- ##############################################

-- Returns the supported modes
function appliance_config:getSupportedModes()
  local all_modes = {
    { name = "passive", label = i18n("passive") },
    { name = "bridging", label = i18n("bridge") },
  }

  return all_modes
end

-- ##############################################

function appliance_config:getOperatingMode()
  if not self.config.globals.operating_mode then
    return "passive"
  end

  return self.config.globals.operating_mode
end

-- ##############################################

function system_config:getPassiveInterfaceName()
  if self.config.globals.available_modes["passive"] then
    return self.config.globals.available_modes["passive"]["interfaces"]["lan"]
  end

  return nil
end

-- ##############################################

-- Get the physical LAN interfaces, based on the current operating mode
-- nf_config overrides this
function appliance_config:getPhysicalLanInterfaces()
  local mode = self:getOperatingMode()
  if not mode then return {} end

  if mode == "passive" then
    return { self.config.globals.available_modes[mode].interfaces.lan, }
  elseif mode == "bridging" then
    return self.config.globals.available_modes[mode].interfaces.lan
  end
end

-- Get the physical WAN interfaces, based on the current operating mode
-- nf_config and appliance_config overrides this
function appliance_config:getPhysicalWanInterfaces()
  local mode = self:getOperatingMode()
  if not mode then return {} end

  return self.config.globals.available_modes[mode].interfaces.wan
end

-- ##############################################

local function findDnsPreset(preset_name)
  require("prefs_utils")

  for _, preset in pairs(DNS_PRESETS) do
    if preset.id == preset_name then
      return preset
    end
  end

  return nil
end

function system_config:_get_default_global_dns_preset()
  return findDnsPreset("google")
end

-- ##############################################

function appliance_config:_get_config_skeleton()
   local config = {
      ["defaults"] = {},
      ["disabled_wans"] = {},
      ["globals"] = {
         ["available_modes"] = {},
         ["lan_recovery_ip"] =  {
            ["ip"] =  "192.168.160.10",
            ["netmask"] =  "255.255.255.0",
            ["comment"] =  "Static LAN IP address used to reach the box set on the bridge interface"
         },
	 ["management_access"] = {
	    ["bind_to"] = "lan",
	 },
      },
      ["interfaces"] = {
         ["comment"]= "List of available network interfaces. Only those listed in globals.operating_mode are actually configured",
         ["configuration"] = {}
      },
      ["date_time"] = {
	 ["ntp_sync"] = {
	    ["enabled"] = true,
	 },
	 ["timezone"] = "Europe/Rome",
      }
   }

   return config
end

-- ##############################################

function appliance_config:_guess_config()
   local config = self:_get_config_skeleton()
   local default_global_dns = self:_get_default_global_dns_preset()
   local wired_default = nil
   local devs = system_config.get_all_interfaces()
   local wired_devs  = {}
   local wifi_devs = system_config.get_wifi_interfaces()
   local ip_devs = system_config.get_ip_interfaces()
   local dhcp_ifaces = system_config.get_dhcp_interfaces() 
   local bridge_devs = system_config.get_bridge_interfaces()
   local wan_iface = system_config.get_default_gw_interface()

   -- set the timezone to the current system timezone
   if not isEmptyString(tz_utils.TimeZone()) then
      config["date_time"]["timezone"] = tz_utils.TimeZone()
   end

   if wan_iface and not devs[wan_iface] then
      wan_iface = nil -- safety check
   end

   local first_wired = nil
   local static_wired = nil

   -- NOTE: we use pairsByKeys to impose an order across multiple guesses
   for name, _ in pairsByKeys(devs) do
      local addr = ip_devs[name]

      -- Bridge
      if bridge_devs[name] then
         if addr then
            bridge_devs[name]["ip"] = addr
         end

      -- WiFi
      elseif wifi_devs[name] then
         if addr then
            wifi_devs[name]["ip"] = addr
         end

      -- Wired
      else
         if not system_config.is_virtual_interface(name) then
            wired_devs[name] = {}

            if first_wired == nil then
               first_wired = name
            end

            if name ~= wan_iface and dhcp_ifaces[name] == nil and static_wired == nil then
               static_wired = name
            end

            if addr then
               wired_devs[name]["ip"] = addr
            end
         end
      end
   end

   -- Set wired_default to the first interface, possibly not the wan or dhcp
   wired_default = static_wired or first_wired

   local operating_mode = nil

   -- ###################
   -- Passive

   local passive = {}

   local management = nil
   if wan_iface then
      management = wan_iface
   elseif table.len(wired_devs) > 1 then
      management = first_wired
   end
   if management ~= nil then
      passive["interfaces"] = {}
      passive["interfaces"]["lan"] = management
      passive["interfaces"]["wan"] = {}
      passive["interfaces"]["unused"] = {}
      passive["comment"] = "Passive monitoring appliance"

      for a, b in pairsByKeys(wired_devs) do
         if a ~= passive["interfaces"]["lan"] then
            -- table.insert(passive["interfaces"]["unused"], a)
            table.insert(passive["interfaces"]["wan"], a)
         end
      end

      config["globals"]["available_modes"]["passive"] = passive

      if operating_mode == nil then
         operating_mode = "passive"
      end
   end

   -- ###################
   -- Bridge interfaces

   local bridging = {}
   local bridging_defined = false
   local bridge_ifname = nil

   -- If we currently have a bridge interface, use its configuration
   if table.len(bridge_devs) > 0 then
      local used_ifaces = {}

      for a,b in pairsByKeys(bridge_devs) do
         if table.len(b.ports) > 1 then
            bridge_ifname = a
            bridging["name"] = a
            bridging["interfaces"] = {unused={}}
            bridging["comment"] = "Transparent bridge"

            bridging["interfaces"]["lan"] = {}
            bridging["interfaces"]["wan"] = {}

            for n,c in pairsByKeys(b.ports) do
               if n == 1 then
                  table.insert(bridging["interfaces"]["lan"], c)
               else
                  table.insert(bridging["interfaces"]["wan"], c)
               end
               used_ifaces[c] = true
            end

            bridging_defined = true

            if operating_mode == nil then
               operating_mode = "bridging"
            end
            break
         end
      end

      if bridging_defined then
         -- add other interfaces to the unused ones
         for iface,_ in pairsByKeys(wired_devs) do
            if used_ifaces[iface] == nil then
               table.insert(bridging["interfaces"]["unused"], iface)
            end
         end
      end
   end

   -- If we do not have a bridge interface but have enough interfaces
   if (not bridging_defined) and (table.len(wired_devs) > 1) then
      local n = 0
      bridge_ifname = "br0"

      bridging["name"] = bridge_ifname
      bridging["interfaces"] = { unused = {} }
      bridging["comment"] = "Transparent bridge"

      for a,b in pairsByKeys(wired_devs) do
         if n == 0 then
            bridging["interfaces"]["lan"] = { a }
         elseif(n == 1) then
            bridging["interfaces"]["wan"] = { a }
         else
            table.insert(bridging["interfaces"]["unused"], a)
         end

         n = n + 1
      end

      bridging_defined = true
   end

   if bridging_defined then
      config["globals"]["available_modes"]["bridging"] = bridging
   end

   -- ###################

   if operating_mode ~= nil then
      config["globals"]["operating_mode"] = operating_mode
   end

   -- ###################
   -- Network configuration

   for a,b in pairs(wired_devs) do

      config["interfaces"]["configuration"][a] = {
         ["family"] = "wired",
         ["network"] = {
            ["primary_dns"] =  default_global_dns.primary_dns,
            ["secondary_dns"] =  default_global_dns.secondary_dns
         }
      }

      -- Note: we force static on the wired_default if not in bridging mode
      if dhcp_ifaces[a] and (a ~= wired_default or operating_mode == "bridging") then
         config["interfaces"]["configuration"][a]["network"]["mode"] = "dhcp"
         config["interfaces"]["configuration"][a]["network"]["ip"] = "192.168.10.1"
         config["interfaces"]["configuration"][a]["network"]["netmask"] = "255.255.255.0"
         config["interfaces"]["configuration"][a]["network"]["gateway"] = "0.0.0.0"
      else
         -- non DHCP interface / wired_default
         config["interfaces"]["configuration"][a]["network"]["mode"] = "static"

         local netmask

         if (ip_devs[a] == nil) then
            -- e.g. on the wired_default
            ip_devs[a] = "192.168.1.1"
            netmask = "255.255.255.0"
         else
            -- The device has an IP address
            local addresses = getAllInterfaceAddresses(a)
            for _, addr in pairs(addresses) do
               if addr.ip == ip_devs[a] then
                  netmask = addr.netmask
               end
            end

            if isEmptyString(netmask) then netmask = "255.255.255.0" end
         end

         local gateway = system_config._interface_get_default_gateway(a)
         config["interfaces"]["configuration"][a]["network"]["ip"] = ip_devs[a]
         config["interfaces"]["configuration"][a]["network"]["netmask"] = netmask

         if not isEmptyString(gateway) then
            config["interfaces"]["configuration"][a]["network"]["gateway"] = gateway
         end
      end
   end

   if wired_default ~= nil then
      -- Add the aliased interface to the configuration
      config["interfaces"]["configuration"][wired_default..":1"] = { 
        ["family"] = "wired",
        ["network"] = {}
      }
      config["interfaces"]["configuration"][wired_default..":1"]["network"]["mode"] = "static"
      config["interfaces"]["configuration"][wired_default..":1"]["network"]["ip"] = "192.168.10.1"
      config["interfaces"]["configuration"][wired_default..":1"]["network"]["netmask"] = "255.255.255.0"
   end

   if bridge_ifname ~= nil then
      -- Add the bridge interface to the configuration
      config["interfaces"]["configuration"][bridge_ifname] = {
         ["family"] = "bridge",
         ["network"] = {
            ["primary_dns"] =  default_global_dns.primary_dns,
            ["secondary_dns"] =  default_global_dns.secondary_dns
         }
      }
      config["interfaces"]["configuration"][bridge_ifname]["network"]["mode"] = "dhcp"
      config["interfaces"]["configuration"][bridge_ifname]["network"]["ip"] = "192.168.20.1"
      config["interfaces"]["configuration"][bridge_ifname]["network"]["netmask"] = "255.255.255.0"
   end

   -- Not supported right now
   -- for a,b in pairs(wifi_devs) do
   --     config["interfaces"]["configuration"][a] = { ["family"] = "wireless", ["network"] = { ["mode"] = "dhcp" } }
   -- end

   -- Make sure to apply the mode specific settings
   self:_apply_operating_mode_settings(config)

   return config
end

-- ##############################################

return appliance_config
