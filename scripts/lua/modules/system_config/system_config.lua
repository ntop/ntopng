--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()

local json = require("dkjson")
local os_utils = require "os_utils"
local sys_utils = require "sys_utils"
local ipv4_utils = require "ipv4_utils"
local tz_utils = require "tz_utils"

-- ##############################################

local system_config = {}

-- ##############################################

-- Configuration file
local CONF_FILE = os_utils.fixPath(dirs.workingdir.."/system.config")
local CONF_FILE_EDITED = CONF_FILE..".edited"
local CONF_FILE_RELOAD = CONF_FILE..".reload" -- to force first start
local STOCK_CONF_FILE = "/etc/ntopng/system.config"

local DATA_RESET_KEY = "ntopng.prefs.data_reset"

-- ##############################################

system_config.readonly = true

-- ##############################################

function system_config:create(args)
   local this = args or {key = "base"}

   setmetatable(this, self)
   self.__index = self

   return this
end

-- ##############################################

-- @brief Writes temporary configuration
-- @param fname File name
-- @param config Configuration
-- @return true on success, false otherwise
local function dumpConfig(fname, config)
   local f = io.open(fname, "w")
   if f and config then
      f:write(json.encode(config, {indent = true}))
      f:close()
      return true
   end
   return false
end

-- ##############################################

function system_config.configChanged()
   return ntop.exists(CONF_FILE_EDITED)
end

-- ##############################################

-- Loads temporary configuration
function system_config:_load_config(fname, guess)
  local dirs = ntop.getDirs()
  local config

  local f = io.open(fname, "r")

  if f ~= nil then
    config = json.decode((f:read "*a"))

    if not config then
       traceError(TRACE_ERROR,
		  TRACE_CONSOLE,
		  "Error while parsing configuration file " .. fname)
    end
    f:close()
  elseif guess then
    -- Load stock configuration if it exists
    if ntop.exists(STOCK_CONF_FILE) then
      traceError(TRACE_WARNING, TRACE_CONSOLE, "Installing stock configuration file " .. STOCK_CONF_FILE)
      sys_utils.execShellCmd("mkdir -p " .. dirs.workingdir)
      sys_utils.execShellCmd("cp " .. STOCK_CONF_FILE .. " " .. CONF_FILE)

      return self:_load_config(fname, false)
    else
      config = self:_guess_config()

      if dumpConfig(CONF_FILE, config) then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
                "Cannot open system configuration file " .. fname .. ", populating with defaults")
      end
    end
  end

  sys_utils.setRealExec(config.globals and not config.globals.fake_exec)

  return config
end

-- ##############################################

function system_config:readable()
   self.readonly = true

   self.config = self:_load_config(CONF_FILE, true)
   self.conf_handler = self:getConfHandler()
end

-- ##############################################

function system_config:editable()
   self.readonly = false

   if ntop.exists(CONF_FILE_EDITED) then
      self.config = self:_load_config(CONF_FILE_EDITED)
   else
      self.config = self:_load_config(CONF_FILE, true)
   end

   self.conf_handler = self:getConfHandler()
end

-- ##############################################

function system_config:getConfHandler()
  package.path = dirs.installdir .. "/scripts/lua/modules/conf_handlers/?.lua;" .. package.path

  local info = ntop.getInfo(false)
  local os = info.OS
  local config_target = "network_ifaces"

  if string.find(os, "Ubuntu 18%.") ~= nil or 
     string.find(os, "Ubuntu 20%.") ~= nil then
    config_target = "netplan"
  end

  return require(config_target)
end

-- ##############################################

-- Discards the temporary config and loads the persistent one
function system_config:discard()
   if not self.readonly and isAdministrator() then
      os.remove(CONF_FILE_EDITED)
      self.config = self:_load_config(CONF_FILE, true)
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unable to discard a readonly configuration.")
   end
end

-- ##############################################

function system_config:_apply_operating_mode_settings(config)
   if config.globals.operating_mode == "bridging" then
      -- We currently force DHCP off on bridge mode
      if config.dhcp_server then
         config.dhcp_server.enabled = false
      end
   end
end

-- ##############################################

-- Set the current interface mode. mode is one of:
--  routing
--  bridging
--  single_port_router
--
function system_config:setOperatingMode(mode)
   if not self.config.globals.available_modes[mode] then
     return false
   end

   self.config.globals.operating_mode = mode
   self:_apply_operating_mode_settings(self.config)

   -- Set DHCP on nedge
   if self.config.dhcp_server then
      self:setDhcpFromLan()
   end

   return true
end

-- ##############################################

-- Returns the available modes
function system_config:getAvailableModes()
  return self.config.globals.available_modes
end

-- ##############################################

-- Returns the current operating mode
-- nf_config and appliance_config override this
function system_config:getOperatingMode()
  return self.config.globals.operating_mode
end

-- ##############################################

-- NOTE: do not use this, use the getOperatingMode instead
function system_config:_getConfiguredOperatingMode()
  return self.config.globals.operating_mode
end

-- ##############################################

function system_config:getManagementAccessConfig()
   local default_config = {bind_to = "lan"}

   if self:isBridgeOverVLANTrunkEnabled() then
      -- on VLAN trunk mode, there is no LAN interface, so we bind to "any"
      return {bind_to = "any"}
   end

   if not self.config.globals.management_access then
      return default_config
   else
      return self.config.globals.management_access
   end
end

function system_config:setManagementAccessConfig(management_access)
   self.config.globals.management_access = management_access
end

-- ##############################################

function system_config.isFirstStart()
  return ntop.exists(CONF_FILE_RELOAD) or ntop.getPref("ntopng.prefs.nedge_start") ~= "1"
end

function system_config.setFirstStart(first_start)
  ntop.setPref("ntopng.prefs.nedge_start", ternary(first_start, "0", "1"))
  if not first_start and ntop.exists(CONF_FILE_RELOAD) then
    os.remove(CONF_FILE_RELOAD)
  end
end

-- ##############################################

-- Gets the date and time configuration
function system_config:getDateTimeConfig()
  return self.config.date_time
end

-- Setup the date and time configuration
function system_config:setDateTimeConfig(config)
  self.config.date_time = config
end

-- ##############################################

function system_config:getUnusedInterfaces()
  local mode = self:getOperatingMode()
  if mode then
    return self.config.globals.available_modes[mode].interfaces.unused or {}
  else
    return {}
  end
end

-- Get the LAN interface, based on the current operating mode
function system_config:getLanInterface()
  local mode = self:getOperatingMode()

  if mode == "bridging" then
    return self.config.globals.available_modes.bridging.name
  else
    return self.config.globals.available_modes[mode].interfaces.lan
  end
end

-- You should only call this in single port routing mode
function system_config:getWanInterface()
  local mode = self:getOperatingMode()

  if mode == "single_port_router" then
    return self.config.globals.available_modes.single_port_router.interfaces.wan
  end

  return nil
end

-- Get all the interfaces, along with their roles
function system_config:getAllInterfaces()
  local ifaces = {}

  for _, iface in pairs(self:getPhysicalLanInterfaces()) do
    ifaces[iface] = "lan"
  end

  for _, iface in pairs(self:getPhysicalWanInterfaces()) do
    ifaces[iface] = "wan"
  end

  for _, iface in pairs(self:getUnusedInterfaces()) do
    ifaces[iface] = "unused"
  end

  return ifaces
end

function system_config:getBridgeInterfaceName()
  if self.config.globals.available_modes["bridging"] then
    return self.config.globals.available_modes["bridging"].name
  end

  return nil
end

-- Set all the interfaces roles
function system_config:setLanWanIfaces(lan_ifaces, wan_ifaces)
  local mode = self:getOperatingMode()
  local unused = self:getAllInterfaces()

  for _, iface in pairs(lan_ifaces) do
    unused[iface] = nil
  end

  for _, iface in pairs(wan_ifaces) do
    unused[iface] = nil
  end

  local unused_ifaces = {}
  for iface, _ in pairs(unused) do
    unused_ifaces[#unused_ifaces + 1] = iface
  end

  if mode == "bridging" then
    self.config.globals.available_modes.bridging.interfaces.lan = lan_ifaces
  else
    self.config.globals.available_modes[mode].interfaces.lan = lan_ifaces[1]
  end

  self.config.globals.available_modes[mode].interfaces.wan = wan_ifaces
  self.config.globals.available_modes[mode].interfaces.unused = unused_ifaces
end

local function isInterfaceUp(ifname)
  local res = sys_utils.execShellCmd("ip link show dev ".. ifname .." | grep ' state UP '")
  return not isEmptyString(res)
end

-- returns all the IP addresses associated to one interface
local function getAllInterfaceAddresses(ifname)
  local res = sys_utils.execShellCmd("ip addr show ".. ifname .." | grep -Po 'inet \\K[\\d.]+/[\\d]+'")
  local rv = {}

  if not isEmptyString(res) then
    local lines = string.split(res, "\n")

    for _, line in ipairs(lines) do
      local ip, netmask = ipv4_utils.cidr_2_addr(line)

      if (ip ~= nil) and (netmask ~= nil) then
        rv[#rv + 1] = {ip=ip, netmask=netmask}
      end
    end
  end

  return rv
end

-- returns a single IP address of an interface.
-- Since an interface can have multiple IPs, this returns the first
-- available excluding the recovery IP
function system_config:getInterfaceAddress(ifname)
  local recovery_conf = self:getLanRecoveryIpConfig()
  local addresses = getAllInterfaceAddresses(ifname)

  for _, addr in ipairs(addresses) do
    if addr.ip ~= recovery_conf.ip then
      return addr.ip, addr.netmask
    end
  end

  return nil
end

-- Get the LAN address, based on the current operating mode
function system_config:getLocalIpv4Address()
  local lan_iface = self:getLanInterface()
  local lan_address = self:getInterfaceAddress(lan_iface)

  if isEmptyString(lan_address) then
    if not self:isBridgeOverVLANTrunkEnabled() then
      traceError(TRACE_WARNING, TRACE_CONSOLE, "Cannot get LAN interface " .. lan_iface .. " address")
    end
    -- This is possibly wrong (e.g. in transparent bridge)
    lan_address = self.config.interfaces.configuration[lan_iface].network.ip or "192.168.1.1"
  end

  return lan_address
end

-- ##############################################

-- Get the physical LAN interfaces, based on the current operating mode
-- nf_config and appliance_config override this
function system_config:getPhysicalLanInterfaces()
  local interfaces = {}
  return interfaces
end

-- Get the physical WAN interfaces, based on the current operating mode
-- nf_config and appliance_config override this
function system_config:getPhysicalWanInterfaces()
  local interfaces = {}
  return interfaces
end

-- ##############################################

local function configDiffers(a_conf, b_conf)
  return not table.compare(a_conf, b_conf)
end

-- ##############################################

function system_config:_get_changed_sections(new_config, force_all_changes)
  local orig_config = self:_load_config(CONF_FILE, false)
  local changed = {}

  -- Check for new / changed sections
  for section in pairs(new_config) do
    if force_all_changes or (orig_config[section] == nil) or configDiffers(new_config[section], orig_config[section]) then
      changed[section] = 1
    end
  end

  -- Check for removed sections
  for section in pairs(orig_config) do
    if new_config[section] == nil then
      changed[section] = 1
    end
  end

  return changed
end

-- ##############################################

local function isRebootRequired(changed_sections)
   -- Always reboot on first start
   if system_config.isFirstStart() then
      return true
   end

   local non_reboot_sections = {
      dhcp_server = 1,
      date_time = 1,
      gateways = 1,
      static_routes = 1,
      routing = 1,
      disabled_wans = 1,
      shapers = 1,
      port_forwarding = 1,
   }

   for section in pairs(changed_sections) do
      if non_reboot_sections[section] == nil then
	 return true
      end
   end

   return false
end

-- ##############################################

function system_config:needsReboot()
  return isRebootRequired(self:_get_changed_sections(self.config))
end

-- ##############################################

local function isSelfRestartRequired(changed_sections)
   local self_restart_sections = {
      static_routes = 1,
   }

   for section in pairs(changed_sections) do
      if self_restart_sections[section] then
	 return true
      end
   end

   return false
end

-- ##############################################

function system_config:needsSelfRestart()
  return isSelfRestartRequired(self:_get_changed_sections(self.config))
end

-- ##############################################

-- Save the configuration changes as a temporary config
function system_config:save()
   if not self.readonly and isAdministrator() then
      local orig_config = self:_load_config(CONF_FILE, false)

      if configDiffers(self.config, orig_config) then
         dumpConfig(CONF_FILE_EDITED, self.config)
      else
         os.remove(CONF_FILE_EDITED)
      end
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unable to save a readonly configuration.")
   end
end

-- Save the current temporary config as persistent
function system_config:makePermanent(force_write)
   if (not self.readonly or force_write) and isAdministrator() then
      dumpConfig(CONF_FILE, self.config)
      os.remove(CONF_FILE_EDITED)
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unable to make a readonly configuration permanent.")
   end
end

-- ##############################################

-- This functions handles configuration changes which do not need a reboot
function system_config:_handleChangedCommonSections(changed_sections, is_rebooting)
  if changed_sections["date_time"] then
     -- drift accounts for the time between the user clicked 'save' and when it actually clicked 'apply'
     -- only when it is requested to set a custom date
     -- drift calculation must go before timezone/ntp changes as they will change the time making it invalid
     local drift
     if self.config.date_time.custom_date_set_req then
	drift = os.time(os.date("!*t", os.time())) - (self.config.date_time.custom_date_set_req or 0)
	self.config.date_time.custom_date_set_req = nil
     end

     if self.config.date_time.timezone then
	local system_timezone = tz_utils.TimeZone()
	if self.config.date_time.timezone ~= system_timezone then
	   sys_utils.execCmd("timedatectl set-timezone "..self.config.date_time.timezone)
	   ntop.tzset()
	end
     end
     if self.config.date_time.ntp_sync.enabled then
	sys_utils.execCmd("timedatectl set-ntp yes")
     else
	sys_utils.execCmd("timedatectl set-ntp no")

	if self.config.date_time.custom_date then
	   -- do not specify any timezone here as it is safe to take the one set for the system
	   local custom_epoch = makeTimeStamp(self.config.date_time.custom_date)
	   if drift then
	      custom_epoch = custom_epoch + drift
	   end
	   -- use a format that timedatectl likes
	   local timedatectl_fmt = os.date("%y-%m-%d %X", tonumber(custom_epoch))
	   if timedatectl_fmt then
	      sys_utils.execCmd('timedatectl set-time "'..timedatectl_fmt..'"')
	   end
	end
	self.config.date_time.custom_date = nil
     end
  end
end

function system_config:_handleChangedSections(changed_sections, is_rebooting) 
  self:_handleChangedCommonSections(changed_sections, is_rebooting)
end

function system_config:applyChanges()
  local changed_sections   = self:_get_changed_sections(self.config, system_config.isFirstStart())
  local is_rebooting       = isRebootRequired(changed_sections)
  local is_self_restarting = isSelfRestartRequired(changed_sections)

  self:_handleChangedSections(changed_sections, is_rebooting)

  self:makePermanent()

  if is_rebooting then
    self:writeSystemFiles()
    sys_utils.rebootSystem()
  elseif is_self_restarting then
    sys_utils.restartSelf()
  end
end

-- ##############################################

function system_config:_writeNetworkInterfaceConfig(f, iface, network_conf, bridge_ifaces)
  local dns_config = self:getDnsConfig()
  self.conf_handler.writeNetworkInterfaceConfig(f, iface, network_conf, dns_config, bridge_ifaces)
end

function system_config:_writePassiveModeNetworkConfig(f)
  local network_config = self.config.interfaces.configuration
  local mode_config = self.config.globals.available_modes["passive"]
  local lan_config = network_config[mode_config.interfaces.lan]

  -- Lan interface
  self:_writeNetworkInterfaceConfig(f, mode_config.interfaces.lan, lan_config.network)
end

function system_config:_writeBridgeModeNetworkConfig(f)
  local network_config = self.config.interfaces.configuration
  local mode_config = self.config.globals.available_modes["bridging"]

  if ntop.isIoTBridge() then
    package.path = dirs.installdir .. "/scripts/lua/modules/conf_handlers/?.lua;" .. package.path
    local wireless = require("wireless")
    -- Bridge mode on IoT bridge, setting up Wireless
    if (self.config.wireless.enabled) then
      -- WiFi Access Point (creates a br0)
      wireless.configureWiFiAccessPoint(f,
        self.config.wireless.ssid,
        self.config.wireless.passphrase)
    else
      wireless.disableWiFi()
    end

  else
    local bridge_ifaces = {}

    -- Lan interfaces
    for _, iface in ipairs(mode_config.interfaces.lan) do
      self:_writeNetworkInterfaceConfig(f, iface, { mode="manual" })
      bridge_ifaces[#bridge_ifaces + 1] = iface
    end

    -- Wan interfaces
    for _, iface in ipairs(mode_config.interfaces.wan) do
      self:_writeNetworkInterfaceConfig(f, iface, { mode="manual" })
      bridge_ifaces[#bridge_ifaces + 1] = iface
    end

    -- Bridge interface
    local br_name = mode_config.name
    local br_config = network_config[br_name]
    self:_writeNetworkInterfaceConfig(f, br_name, br_config.network, bridge_ifaces)
  end
end

function system_config:_writeRoutingModeNetworkConfig(f)
  local network_config = self.config.interfaces.configuration
  local mode_config = self.config.globals.available_modes["routing"].interfaces

  -- Lan interface
  self:_writeNetworkInterfaceConfig(f, mode_config.lan, network_config[mode_config.lan].network)

  -- Wan interfaces
  for _, iface in ipairs(mode_config.wan) do
    self:_writeNetworkInterfaceConfig(f, iface, network_config[iface].network)
  end
end

function system_config:_writeSinglePortModeInterfaces(f)
  local network_config = self.config.interfaces.configuration
  local mode_config = self.config.globals.available_modes["single_port_router"]
  local lan_iface = self:getLanInterface()
  local wan_iface = self:getWanInterface()

  -- Lan interface
  self:_writeNetworkInterfaceConfig(f, lan_iface, network_config[lan_iface].network)

  -- Wan interface
  self:_writeNetworkInterfaceConfig(f, wan_iface, network_config[wan_iface].network)
end

function system_config:_writeNetworkInterfaces()
  local mode = self:getOperatingMode()
  local f = self.conf_handler.openNetworkInterfacesConfigFile()

  local recovery_conf = self:getLanRecoveryIpConfig()
  local recovery_iface = self:getLanInterface() .. ":2"
  local is_configured, fnames = self.conf_handler.isConfiguredInterface("lo")

  if not is_configured then
    self:_writeNetworkInterfaceConfig(f, "lo", {mode="loopback"})
  end

  -- Configure interfaces depending on working mode
  if mode == "passive" then
    self:_writePassiveModeNetworkConfig(f)
  elseif mode == "bridging" then
    self:_writeBridgeModeNetworkConfig(f)
  elseif mode == "routing" then
    self:_writeRoutingModeNetworkConfig(f)
  elseif mode == "single_port_router" then
    self:_writeSinglePortModeInterfaces(f)
  end

  -- Configure backup interface
  if not ntop.isIoTBridge() then
    self:_writeNetworkInterfaceConfig(f, recovery_iface, { mode="static", ip=recovery_conf.ip, netmask=recovery_conf.netmask })
  end

  self.conf_handler.closeNetworkInterfacesConfigFile(f)
end

function system_config:writeSystemFiles()
  if system_config.isFirstStart() then
    self:verifyNetworkInterfaces()
  end

  self:_writeNetworkInterfaces()
  system_config.setFirstStart(false)
end

-- ##############################################

function system_config:isBridgeOverVLANTrunkEnabled()
  local mode = self:getOperatingMode()

  if mode == "bridging" then
     local bridge = self.config.globals.available_modes.bridging.name
     if self:getInterfaceMode(bridge) == "vlan_trunk" then
	return true
     end
  end

  return false
end

-- ##############################################

local function gatewayGetInterface(gateway)
  -- Useful to find the interface which would route traffic to some address
  local res = sys_utils.execShellCmd("ip route get " .. gateway)

  if not isEmptyString(res) then
    return res:gmatch(" dev ([^ ]*)")()
  end
end

-- TODO use more reliable information
local function ifaceGetNetwork(iface)
  local res = sys_utils.execShellCmd("ip route show | grep \"scope link\" | grep \"proto kernel\" | grep \"" .. iface .. "\"")

  if not isEmptyString(res) then
    return split(res, " ")[1]
  end
end

-- ##############################################

function system_config:getStaticLanNetwork()
  local lan_iface = self:getLanInterface()
  local lan_config = self.config.interfaces.configuration[lan_iface].network
  local lan_network = ipv4_utils.addressToNetwork(lan_config.ip, lan_config.netmask)

  return {
    iface = lan_iface,
    network = lan_network,
    cidr = lan_network,
    ip = lan_config.ip,
    netmask = lan_config.netmask,
  }
end

-- Returns true if the interface is currently up and running
local function isInterfaceLinkUp(ifname)
  local opstatus = sys_utils.execShellCmd("cat /sys/class/net/" .. ifname .. "/operstate 2>/dev/null")
  return starts(opstatus, "up")
end

-- ##############################################

function system_config:getDisabledWans(check_wans_with_linkdown)
  if check_wans_with_linkdown == nil then check_wans_with_linkdown = false end

  -- table.clone needed to modify some parameters while keeping the original unchanged
  local disabled = table.clone(self.config.disabled_wans)

  if check_wans_with_linkdown then
    local roles = self:getAllInterfaces()

    for iface, role in pairs(roles) do
      if role == "wan" then
        if (disabled[iface] ~= true) and (not isInterfaceLinkUp(iface)) then
          disabled[iface] = true
        end
      end
    end
  end

  return disabled
end

function system_config:setDisabledWans(disabled_wans)
  self.config.disabled_wans = disabled_wans
end

-- ##############################################

function system_config:_checkDisabledInterfaces()
  local ifaces = self:getAllInterfaces()
  local disabled_wans = self.config.disabled_wans

  for iface, role in pairs(ifaces) do
    if role == "wan" then
      local is_disabled = (disabled_wans[iface] == true)
      local currently_disabled = not isInterfaceUp(iface)

      if is_disabled ~= currently_disabled then
        if is_disabled then
          traceError(TRACE_NORMAL, TRACE_CONSOLE, "Disable interface " .. iface)
          sys_utils.execCmd("ip link set dev " .. iface .. " down")
        else
          traceError(TRACE_NORMAL, TRACE_CONSOLE, "Enable interface " .. iface)
          sys_utils.execCmd("ip link set dev " .. iface .. " up")
        end
      end
    end
  end
end

-- ##############################################

function system_config:getInterfacesConfiguration()
  return self.config.interfaces.configuration or {}
end

function system_config:setInterfacesConfiguration(config)
  self.config.interfaces.configuration = config
end

-- ##############################################

function system_config:setInterfaceMode(iface, mode)
  local net_config = self.config.interfaces.configuration[iface]

  if net_config ~= nil then
    net_config.network.mode = mode

    if mode == "static" and (isEmptyString(net_config.network.ip) or isEmptyString(net_config.network.netmask)) then
      net_config.network.ip = "192.168.1.1"
      net_config.network.netmask = "255.255.255.0"
    end
    return true
  end

  return false
end

function system_config:getInterfaceMode(iface)
  local net_config = self.config.interfaces.configuration[iface]

  if net_config ~= nil and net_config.network then
    return net_config.network.mode
  end
end

-- ##############################################

function system_config:_enableDisableDhcpService()
  if self:isDhcpServerEnabled() then
    sys_utils.enableService("isc-dhcp-server")
  else
    sys_utils.disableService("isc-dhcp-server")
  end
end

-- ##############################################

function system_config:getDnsConfig()
  return self.config.globals.dns
end

function system_config:setDnsConfig(config)
  self.config.globals.dns = config
end

-- ##############################################

function system_config:isGlobalDnsForgingEnabled()
  return self.config.globals.dns.forge_global
end

function system_config:setGlobalDnsForgingEnabled(enabled)
  self.config.globals.dns.forge_global = ternary(enabled, true, false)
end

-- ##############################################

function system_config:getLanRecoveryIpConfig()
  return self.config.globals.lan_recovery_ip
end

function system_config:setLanRecoveryIpConfig(config)
  self.config.globals.lan_recovery_ip = config
end

-- ##############################################

-- NOTE: can't rely on the main routing table when having multiple gateways!
function system_config._interface_get_default_gateway(iface)
  local res = sys_utils.execShellCmd("ip route show | grep \"^default via\" | grep \"" .. iface .. "\"")

  if not isEmptyString(res) then
    return split(res, " ")[3]
  end
end

-- ##############################################

local allowed_interfaces

-- @brief Use the logic in ntopng to list available interfaces
--        and avoid interface name with characters that could
--        lead to injections
local function allowedDevName(devname)
   if isEmptyString(devname) then
      return false
   end

   -- Do some caching
   if not allowed_interfaces then
      allowed_interfaces = ntop.listInterfaces()
   end

   -- Interface is allowed if it appears in the list retrieved from C
   return allowed_interfaces[devname]
end

-- ##############################################

function system_config._split_dev_names(c, delimiter)
   local ret = {}
   local cmd = sys_utils.execShellCmd(c)

   if((cmd ~= "") and (cmd ~= nil)) then

      local devs = split(cmd, "\n")

      if(delimiter == nil) then
	 local rv = {}
         for idx, dev in pairs(devs) do
	   if not isEmptyString(dev) and allowedDevName(dev) then
	      rv[#rv + 1] = dev
           end
         end

         return rv
      end

      for _,a in pairs(devs) do
	 local p = split(a, delimiter)

	 if(p ~= nil) then
	    local name = p[1]
	    local addr = p[2]

	    if(addr and name) then
	       name = trimSpace(name)
	       addr = trimSpace(addr)

	       if allowedDevName(name) then
		  ret[name] = addr:gsub("%s+", "")
	       end
	    end
	 end
      end
   end

   return ret
end

-- ##############################################

-- Check TUN/dummy/lo interface
function system_config.is_virtual_interface(name)
   return (name == "lo" or 
           starts(name, "dummy") or 
           ntop.exists('/sys/class/net/'.. name ..'/tun_flags') or 
           string.contains(name, ":"))
end

-- ##############################################

-- Find all interfaces
function system_config.get_all_interfaces()
   local devs = system_config._split_dev_names('cat /proc/net/dev', ":")
   return devs
end

-- ##############################################

-- Find all bridge interfaces
function system_config.get_bridge_interfaces()
   local devs = system_config.get_all_interfaces()
   local bridge_devs = {}

   for name, _ in pairsByKeys(devs) do
      if not system_config.is_virtual_interface(name) then
         if(ntop.exists('/sys/class/net/'.. name ..'/bridge')) then
            local devs = system_config._split_dev_names('ls /sys/class/net/'.. name ..'/brif/', nil)
            bridge_devs[name] = { ["ports"] = devs }
         end
      end
   end

   return bridge_devs
end

-- ##############################################

-- Find WiFi interfaces
function system_config.get_wifi_interfaces()
   local wifi_devs = system_config._split_dev_names('cat /proc/net/wireless', ":")
   
   -- Necessary for inactive wifi devices
   local devs = system_config.get_all_interfaces()
   for dev in pairs(devs) do
      local rv = sys_utils.execShellCmd("iwconfig 2>/dev/null | grep \"" .. dev .. "\" | grep \"IEEE 802.11\"")
      if not isEmptyString(rv) then
         wifi_devs[dev] = {}
      end
   end

   return wifi_devs
end

-- ##############################################

-- Find interfaces with IP configured
 function system_config.get_ip_interfaces()
  local ip_devs = system_config._split_dev_names('ip addr | awk \'$1 == "inet" && $7 { split( $2, addr, "/" ); print $7, addr[1] }\'', " ")
  return ip_devs
end

-- ##############################################

-- Find DHCP interface
function system_config.get_dhcp_interfaces()
   local dhcp_ifaces = {}

   local res = sys_utils.execShellCmd('ps aux | grep dhclient')
   if not isEmptyString(res) then
      local devs = system_config.get_all_interfaces()
      for _, line in pairs(split(res, "\n")) do
         local name = line:gmatch(".([^.]+).leases")()

         if devs[name] ~= nil then
            dhcp_ifaces[name] = {}
         end
      end 
   end

   return dhcp_ifaces
end

-- ##############################################

-- Find the wan interface reading the default gw
function system_config.get_default_gw_interface()
   local dev = sys_utils.execShellCmd("ip route show | grep \"default via\" | awk '{printf \"%s\", $5}'")
   if not isEmptyString(dev) then
      return dev
   end

   return nil
end

-- ##############################################

-- nf_config and appliance_config override this
function system_config:_guess_config()
   local config = {}
   return config
end

-- ##############################################

-- Verify that we are the only to manage the network interfaces
function system_config:verifyNetworkInterfaces()
  local lan_ifaces = self:getPhysicalLanInterfaces()
  local wan_ifaces = self:getPhysicalWanInterfaces()
  local lan_iface = self:getLanInterface()
  local ifaces = {[lan_iface] = 1}

  for _, iface in pairs(lan_ifaces) do
    ifaces[iface] = 1
  end
  for _, iface in pairs(wan_ifaces) do
    ifaces[iface] = 1
  end

  local has_error = false
  local to_backup = {}

  for iface in pairs(ifaces) do
    local is_configured, conf_files = self.conf_handler.isConfiguredInterface(iface)

    if is_configured then
      traceError(TRACE_WARNING, TRACE_CONSOLE, "Network interface " .. iface .. " must be managed by ntopng")
      has_error = true

      if conf_files ~= nil then
        to_backup = table.merge(to_backup, conf_files)
      end
    end
  end

  if has_error then
    self.conf_handler.backupNetworkInterfacesFiles(to_backup)
    return true
  end

  return true
end

-- ##############################################

return system_config
