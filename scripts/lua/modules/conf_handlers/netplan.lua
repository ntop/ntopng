--
-- (C) 2013-20 - ntop.org
--

local sys_utils = require("sys_utils")
local ipv4_utils = require("ipv4_utils")

local config = {}

-- ################################################################

local NEDGE_NETPLAN_CONF = "20-nedge.yaml"
local CLOUD_DIRECTORY = "/etc/cloud/cloud.cfg.d"
local CLOUD_DISABLED_FNAME = "99-disable-network-config.cfg"

local start_ethernet_section = true

function config.writeNetworkInterfaceConfig(f, iface, network_conf, dns_config, bridge_ifaces)
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
    f:write("  bridges:\n")
  elseif string.find(iface, ":") then
    -- This is an alias
    local base_iface = split(iface, ":")[1]

    if starts(iface, "br") then
      -- bridge iface
      f:write("  bridges:\n")
    else
      f:write("  ethernets:\n")
    end

    iface = base_iface
  elseif start_ethernet_section then
    f:write("  ethernets:\n")
    start_ethernet_section = false
  end

  if vlan_raw_iface then
    -- inside ethernet section, write the raw device
    f:write("    ".. vlan_raw_iface ..":\n")
    f:write("      addresses: []\n")
    -- start a vlan section
    f:write("  vlans:\n")
  end

  f:write("    ".. iface ..":\n")

  if network_conf.mode == "static" then
    cidr = ipv4_utils.netmask(network_conf.netmask)
    f:write("      addresses: [" .. network_conf.ip .."/".. cidr .."]\n")

    if not isEmptyString(network_conf.gateway) then
      f:write("      gateway4: " .. network_conf.gateway .. "\n")
      f:write("      nameservers:\n")
      f:write("        addresses: [" .. table.concat({dns_config.global, dns_config.secondary}, ", ") .. "]\n")
    end
  elseif (network_conf.mode == "dhcp") then
    f:write("      addresses: []\n")
    f:write("      dhcp4: true\n")
  else
    -- e.g. vlan-trunk
    f:write("      addresses: []\n")
  end

  if vlan_raw_iface then
      f:write("      accept-ra: no\n")
      f:write("      id: " .. vlan_id .. "\n")
      f:write("      link: " .. vlan_raw_iface .. "\n")
      -- end VLAN section and start again the ethernet section
      start_ethernet_section = true
  elseif bridge_ifaces ~= nil then
    f:write("      interfaces: [".. table.concat(bridge_ifaces, ", ") .."]\n")
    f:write("      parameters:\n")
    f:write("        stp: false\n")
    f:write("        forward-delay: 0\n")
  end
end

-- ################################################################

function config.openNetworkInterfacesConfigFile()
  local f = sys_utils.openFile("/etc/netplan/" .. NEDGE_NETPLAN_CONF, "w")

  f:write("network:\n  version: 2\n")
  start_ethernet_section = true

  return f
end

-- ################################################################

function config.closeNetworkInterfacesConfigFile(f)
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

