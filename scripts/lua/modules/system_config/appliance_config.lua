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

function appliance_config:_get_config_skeleton()
   local config = {}
   local defaults = { }
   local default_global_dns = self:_get_default_global_dns_preset()

   local config = {
      ["defaults"] = defaults,
      ["disabled_wans"] = {},
      ["globals"] = {
         ["available_modes"] = {},
         ["dns"] =  {
            ["global_preset"] = default_global_dns.id,
            ["global"] =  default_global_dns.primary_dns,
            ["secondary"] =  default_global_dns.secondary_dns,
            ["forge_global"] = false
         },
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
      ["gateways"] = {
      },
      ["static_routes"] = {
      },
      ["date_time"] = {
	 ["ntp_sync"] = {
	    ["enabled"] = true,
	 },
	 ["timezone"] = "Europe/Rome",
      },
      ["dhcp_server"] = {
         ["enabled"] = false,
         ["options"] = {
            "ddns-update-style none",
            "log-facility local7",
            "authoritative"
         },
         ["subnet"] = {
            ["network"] = "192.168.1.0",
            ["netmask"] = "255.255.255.0",
            ["first_ip"] = "192.168.1.10",
            ["last_ip"] = "192.168.1.200",
            ["gateway"] = "192.168.1.1",
            ["broadcast"] = "192.168.1.255",
            ["options"] = {
               "option domain-name \"ntop.local\"",
               "default-lease-time 600",
               "max-lease-time 7200"
            }
         },
         ["leases"] = {}
      }
   }
   return config
end

-- ##############################################

function appliance_config:_guess_config()
   local config = self:_get_config_skeleton()
   local devs   = { }
   local wifi   = { }
   local bridge = { }
   local wired  = { }
   local dhcp_ifaces = {}
   local wired_default = nil
   local wifi_default = nil
   local ip_devs   = system_config._split_dev_names('ip addr | awk \'$1 == "inet" && $7 { split( $2, addr, "/" ); print $7, addr[1] }\'', " ")
   local devs      = system_config._split_dev_names('cat /proc/net/dev', ":")
   local wifi_devs = system_config._split_dev_names('cat /proc/net/wireless', ":")
   local lan_iface
   local wan_iface = nil

   -- set the timezone to the current system timezone

   if not isEmptyString(tz_utils.TimeZone()) then
      config["date_time"]["timezone"] = tz_utils.TimeZone()
   end

   -- Necessary for inactive wifi devices
   for dev in pairs(devs) do
      local rv = sys_utils.execShellCmd("iwconfig 2>/dev/null | grep \"" .. dev .. "\" | grep \"IEEE 802.11\"")
      if not isEmptyString(rv) then
         wifi_devs[dev] = 1
      end
   end

   -- Find DHCP interface
   local res = sys_utils.execShellCmd('ps aux | grep dhclient')
   if not isEmptyString(res) then
      for _, line in pairs(split(res, "\n")) do
         local name = line:gmatch(".([^.]+).leases")()

         if devs[name] ~= nil then
            dhcp_ifaces[name] = 1
         end
      end 
   end

   -- Find the wan interface
   local rv = sys_utils.execShellCmd("ip route show | grep \"default via\" | awk '{printf \"%s\", $5}'")
   if not isEmptyString(rv) and devs[rv] ~= nil then
      wan_iface = rv
   end

   local some_wired = nil
   local static_wired = nil

   -- Identify the type of the devices in the system
   -- NOTE: we use pairsByKeys to impose an order across multiple guesses
   for name, _ in pairsByKeys(devs) do
      local addr = ip_devs[name]

      -- Not TUN/dummy/lo interface
      if((name ~= "lo") and (not starts(name, "dummy")) and not(ntop.exists('/sys/class/net/'.. name ..'/tun_flags')) and not string.contains(name, ":")) then
         if(ntop.exists('/sys/class/net/'.. name ..'/bridge')) then
            local devs = system_config._split_dev_names('ls /sys/class/net/'.. name ..'/brif/', nil)

            bridge[name] = { ["ports"] = devs }
            if(addr ~= nil) then bridge[name]["ip"] = addr end
         elseif(wifi_devs[name] ~= nil) then
            wifi[name]   = { }
            if(addr ~= nil) then wifi[name]["ip"] = addr end
            if(wifi_default == nil) then wifi_default = name end
         else
            -- Add per-interface gateway
            config.gateways[name] = {interface=name, ping_address="8.8.8.8"}

            wired[name] = { }
            if(some_wired == nil) then some_wired = name end
	    if((name ~= wan_iface) and (dhcp_ifaces[name] == nil) and (static_wired == nil)) then static_wired = name end

            if(addr ~= nil) then
               wired[name]["ip"] = addr
            end
         end
      end
   end

   wired_default = static_wired or some_wired

   -- TODO modify this after supporting the other modes:
   -- e.g. for bridge interface the lan should be br0
   lan_iface = wired_default

   -- ###################
   -- Passive

   local passive = {}

   if(wired_default ~= nil) then
      passive["interfaces"] = {}
      passive["interfaces"]["unused"] = {}
      passive["interfaces"]["lan"] = wired_default
      passive["comment"] = "Passive monitoring appliance"

      for a, b in pairsByKeys(wired) do
         if a ~= wired_default then
            table.insert(passive["interfaces"]["unused"], a)
         end
      end

      config["globals"]["available_modes"]["passive"] = passive
      operating_mode = "passive"
   end

   -- ###################
   -- Bridge interfaces

   local bridging = {}
   local operating_mode = nil
   local bridging_defined = false
   local bridge_ifname = nil

   -- If we currently have a bridge interface, use its configuration
   if table.len(bridge) > 0 then
      local used_ifaces = {}

      for a,b in pairsByKeys(bridge) do
         if table.len(b.ports) > 1 then
            bridge_ifname = a
            bridging["name"] = a
            bridging["interfaces"] = {unused={}}
            bridging["comment"] = "Transparent bridge"

            bridging["interfaces"]["lan"] = {}
            bridging["interfaces"]["wan"] = {}

            for n,c in pairsByKeys(b.ports) do
               if(n == 1) then
                  table.insert(bridging["interfaces"]["lan"], c)
               else
                  table.insert(bridging["interfaces"]["wan"], c)
               end
               used_ifaces[c] = true
            end

            operating_mode = "bridging"
            bridging_defined = true
            break
         end
      end

      if bridging_defined then
         -- add other interfaces to the unused ones
         for iface,_ in pairsByKeys(wired) do
            if used_ifaces[iface] == nil then
               table.insert(bridging["interfaces"]["unused"], iface)
            end
         end
      end
   end

   -- If we do not have a bridge interface but have enough interfaces
   if((not bridging_defined) and(table.len(wired) > 1)) then
      local n = 0
      bridge_ifname = "br0"

      bridging["name"] = bridge_ifname
      bridging["interfaces"] = {unused={}}
      bridging["comment"] = "Transparent bridge"

      for a,b in pairsByKeys(wired) do
         if(n == 0) then
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

   if(bridging_defined) then
      config["globals"]["available_modes"]["bridging"] = bridging
   end

   -- ###################

   if(operating_mode ~= nil) then
      config["globals"]["operating_mode"] = operating_mode
   end

   -- ###################
   -- Network configuration

   for a,b in pairs(wired) do
      local speed = (interface.getMaxIfSpeed(a) or 10) * 1000 -- Mbps to Kbps that are more tc-friendly :)

      config["interfaces"]["configuration"][a] = {
         ["family"] = "wired", ["masquerade"] = true, ["network"] = {  },
         ["speed"] = {["upload"] = speed, ["download"] = speed} }

      -- Note: we force static on the wired_default if not in bridging mode
      if dhcp_ifaces[a] and ((a ~= wired_default) or (operating_mode == "bridging")) then
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

   if(wired_default ~= nil) then
      -- Add the aliased interface to the configuration
       config["interfaces"]["configuration"][wired_default..":1"] = { ["family"] = "wired", ["network"]={},
          ["speed"] = {["upload"]= speed, ["download"] = speed}  }
      config["interfaces"]["configuration"][wired_default..":1"]["network"]["mode"] = "static"
      config["interfaces"]["configuration"][wired_default..":1"]["network"]["ip"] = "192.168.10.1"
      config["interfaces"]["configuration"][wired_default..":1"]["network"]["netmask"] = "255.255.255.0"
   end

   if(bridge_ifname ~= nil) then
      local speed = 100 * 1000 -- Kbps, not really important here

      -- Add the bridge interface to the configuration
      config["interfaces"]["configuration"][bridge_ifname] = { ["family"] = "bridge", ["network"]={},
          ["speed"] = {["upload"]= speed, ["download"] = speed}  }
      config["interfaces"]["configuration"][bridge_ifname]["network"]["mode"] = "dhcp"
      config["interfaces"]["configuration"][bridge_ifname]["network"]["ip"] = "192.168.20.1"
      config["interfaces"]["configuration"][bridge_ifname]["network"]["netmask"] = "255.255.255.0"
   end

   -- Not supported right now
   --for a,b in pairs(wifi) do
      --config["interfaces"]["configuration"][a] = { ["family"] = "wireless", ["network"] = { ["mode"] = "dhcp" } }
   --end

   -- Make sure we have a valid DHCP range
   self:_fix_dhcp_from_lan(config, lan_iface)

   -- Make sure to apply the mode specific settings
   self:_apply_operating_mode_settings(config)

   return config
end

-- ##############################################

return appliance_config
