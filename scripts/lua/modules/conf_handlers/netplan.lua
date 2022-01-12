--
-- (C) 2013-22 - ntop.org
--

local sys_utils = require("sys_utils")
local ipv4_utils = require("ipv4_utils")

local config = {}

-- ################################################################

local NEDGE_NETPLAN_CONF = "20-nedge.yaml"
local CLOUD_DIRECTORY = "/etc/cloud/cloud.cfg.d"
local CLOUD_DISABLED_FNAME = "99-disable-network-config.cfg"

local netplan_config = {}

function config._getInterfaceConfig(section, iface)
  if not netplan_config[section] then
      netplan_config[section] = {}
  end
  if not netplan_config[section][iface] then
    netplan_config[section][iface] = {}
  end
  return netplan_config[section][iface]
end

function config._setInterfaceConfig(section, iface, if_config)
  if not netplan_config[section] then
    netplan_config[section] = {}
  end
  netplan_config[section][iface] = if_config
end

function config.writeNetworkInterfaceConfig(f, iface, network_conf, dns_config, bridge_ifaces)
  local if_config
  local if_config_section
  local if_config_iface

  if iface == "lo" then
    -- nothing to do for loopback interface
    return
  end

  local vlan_raw_iface = nil
  local vlan_id = nil
  
  if string.contains(iface, "%.") then
    local parts = string.split(iface, "%.")
    vlan_raw_iface = parts[1]
    vlan_id = parts[2]
  end

  if bridge_ifaces ~= nil then
    if_config_section = "bridges"
    if_config_iface = iface
    if_config = config._getInterfaceConfig(if_config_section, if_config_iface)

  elseif string.find(iface, ":") then
    -- This is an alias
    local base_iface = split(iface, ":")[1]
    iface = base_iface

    if starts(iface, "br") then
      if_config_section = "bridges"
      if_config_iface = iface
      if_config = config._getInterfaceConfig(if_config_section, if_config_iface) 
    else
      if_config_section = "ethernets"
      if_config_iface = iface
      if_config = config._getInterfaceConfig(if_config_section, if_config_iface) 
    end

  elseif vlan_raw_iface then
    -- create an ethernet with the raw device
    if_config_section = "ethernets"
    if_config_iface = vlan_raw_iface
    if_config = config._getInterfaceConfig(if_config_section, if_config_iface)
    config._setInterfaceConfig(if_config_section, if_config_iface, if_config)
    -- create a vlan section
    if_config_section = "vlans"
    if_config_iface = iface
    if_config = config._getInterfaceConfig(if_config_section, if_config_iface)

  else
    if_config_section = "ethernets"
    if_config_iface = iface
    if_config = config._getInterfaceConfig(if_config_section, if_config_iface) 
  end

  if not if_config then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Interface configuration not selected")	  
    return
  end

  if network_conf.mode == "static" then
    cidr = ipv4_utils.netmask(network_conf.netmask)
    
    if not if_config.addresses then 
      if_config.addresses = {}
    end
    if_config.addresses[#if_config.addresses+1] = network_conf.ip .."/".. cidr

    if not isEmptyString(network_conf.gateway) then
      if_config.gateway4 = network_conf.gateway
      if not if_config.nameservers then
        if_config.nameservers = {}
      end
      if_config.nameservers[if_config.nameservers+1] = dns_config.global
      if_config.nameservers[if_config.nameservers+1] = dns_config.secondary
    end
  elseif network_conf.mode == "dhcp" then
    if_config.dhcp4 = 'true'
  end

  if vlan_raw_iface then
    if not if_config.extra_conf then
      if_config.extra_conf = {}
    end
    if_config.extra_conf['accept-ra'] = 'no'
    if_config.extra_conf['id'] = vlan_id
    if_config.extra_conf['link'] = vlan_raw_iface
  elseif bridge_ifaces ~= nil then
    if_config.interfaces = bridge_ifaces
    if not if_config.parameters then
      if_config.parameters = {}
    end
    if_config.parameters['stp'] = 'false'
    if_config.parameters['forward-delay'] = '0'
  end

  config._setInterfaceConfig(if_config_section, if_config_iface, if_config)
end

-- ################################################################

function config.openNetworkInterfacesConfigFile()
  local f = sys_utils.openFile("/etc/netplan/" .. NEDGE_NETPLAN_CONF, "w")

  netplan_config.version = 2

  return f
end

-- ################################################################

function config._writeInterfacesConfig(f, interfaces)
  for iface, if_config in pairs(interfaces) do
    f:write("    ".. iface ..":\n")

    if if_config.interfaces then
      -- Sub interfaces (e.g. bridge)
      f:write("      interfaces: [".. table.concat(if_config.interfaces, ", ") .. "]\n")
    end

    if not if_config.addresses then
      f:write("      addresses: []\n")
    else
      f:write("      addresses: [" .. table.concat(if_config.addresses, ", ") .. "]\n")
    end

    if if_config.dhcp4 then
      f:write("      dhcp4: true\n")
    end

    if if_config.gateway4 then
      f:write("      gateway4: " .. if_config.gateway4 .. "\n")
    end

    if if_config.nameservers then
      f:write("      nameservers:\n")
      f:write("        addresses: [" .. table.concat(if_config.nameservers, ", ") .. "]\n")
    end

    if if_config.parameters then
      f:write("      parameters:\n")
      for key, value in pairs(if_config.parameters) do
	f:write("        " .. key .. ": " .. value .. "\n")
      end
    end

    if if_config.extra_conf then
      for key, value in pairs(if_config.extra_conf) do
	f:write("      " .. key .. ": " .. value .. "\n")
      end
    end
  end
end

-- ################################################################

function config._writeNetworkInterfaceConfig(f)
  f:write("network:\n")
  f:write("  version: " .. netplan_config.version .. "\n")

  if netplan_config.ethernets then
    f:write("  ethernets:\n")
    config._writeInterfacesConfig(f, netplan_config.ethernets)
  end

  if netplan_config.bridges then
    f:write("  bridges:\n")
    config._writeInterfacesConfig(f, netplan_config.bridges)
  end
  
  if netplan_config.vlans then
    f:write("  vlans:\n")
    config._writeInterfacesConfig(f, netplan_config.vlans)
  end
end

-- ################################################################

function config.closeNetworkInterfacesConfigFile(f)

  config._writeNetworkInterfaceConfig(f)

  f:close()

  sys_utils.execShellCmd("netplan generate")
end

-- ################################################################

function config.backupNetworkInterfacesFiles(to_backup)
  for fname in pairs(to_backup) do
    local source = fname
    local destination = source .. ".old"
    os.rename(source, destination)
    traceError(TRACE_WARNING, TRACE_CONSOLE, source .. " has been moved to " .. destination)
  end

  local cloud_disabled_path = CLOUD_DIRECTORY .. "/" .. CLOUD_DISABLED_FNAME

  if ntop.isdir(CLOUD_DIRECTORY) and not ntop.exists(cloud_disabled_path) then
    -- disable cloud to prevent future modifications
    local f = sys_utils.openFile(cloud_disabled_path, "w")

    if f ~= nil then
      f:write("network: {config: disabled}\n")
      f:close()
    end
  end
end

-- ################################################################

-- returns true if the interface is already configured in a file which is not managed by nedge
-- In such case, it also returns the list of files which use the interface
function config.isConfiguredInterface(iface)
  local files_to_rename = {}

  for fname in pairs(ntop.readdir("/etc/netplan")) do
    if fname ~= NEDGE_NETPLAN_CONF then
      local fpath = "/etc/netplan/".. fname
      -- e.g.: "renderer: NetworkManager", "iface: enp1s0"
      local res = sys_utils.execCmd("grep \"^\\s*[^#]*\\(" .. iface .. "\\|renderer\\):\" ".. fpath .." >/dev/null 2>/dev/null")

      if not isEmptyString(res) then
        files_to_rename[fpath] = 1
      end
    end
  end

  return not table.empty(files_to_rename), files_to_rename
end

-- ################################################################

function config.dhcpInterfaceGetGateway(iface)
  -- it says "do not parse", but there is no script to get this info
  local dirs = ntop.readdir("/var/run/systemd/netif/leases/") or {}

  for ifid in pairs(dirs) do
    local name_line = sys_utils.execShellCmd('grep "NETWORK_FILE=" /run/systemd/netif/links/'.. ifid)
    if not isEmptyString(name_line) then
      local parts = split(name_line, "-")
      local name = split(parts[#parts], ".network")[1]

      if name == iface then
        local gw = sys_utils.execShellCmd('grep "ROUTER=" /var/run/systemd/netif/leases/' .. ifid .. ' | cut -f2 -d=')

        if not isEmptyString(gw) then
          gw = split(gw, "\n")[1]

          if isIPv4(gw) then
            return gw
          end
        end
      end
    end
  end

  return nil
end

-- ################################################################

return config

