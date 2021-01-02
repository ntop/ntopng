--
-- (C) 2013-21 - ntop.org
--

local sys_utils = require("sys_utils")
local config = {}

-- ################################################################

function config.writeNetworkInterfaceConfig(f, iface, network_conf, dns_config, bridge_ifaces)
  f:write("\nauto " .. iface .. "\n")

  if network_conf.mode == "static" then
    f:write("iface " .. iface .. " inet static\n")
    f:write("\taddress " .. network_conf.ip .. "\n")
    f:write("\tnetmask " .. network_conf.netmask .. "\n")

    if not isEmptyString(network_conf.gateway) then
      f:write("\tgateway " .. network_conf.gateway .. "\n")

      if network_conf.primary_dns and network_conf.secondary_dns then
        f:write("\tdns-nameservers " .. table.concat({network_conf.primary_dns, network_conf.secondary_dns}, " ") .. "\n")
      elseif dns_config then
        f:write("\tdns-nameservers " .. table.concat({dns_config.global, dns_config.secondary}, " ") .. "\n")
      end
    end

  elseif network_conf.mode == "vlan_trunk" then
    -- nothing to configure for a vlan-trunk bridge interface 
    f:write("iface " .. iface .. " inet manual\n")
  else
    f:write("iface " .. iface .. " inet " .. network_conf.mode .. "\n")

    if ntop.isnEdge() and network_conf.mode == "dhcp" then
      f:write("\tpre-up /bin/rm -f /var/lib/dhcp/dhclient.".. iface ..".leases\n")
    end
  end

  if string.contains(iface, ".") then
    -- VLAN interface
    local parts = split(iface, "%.")

    if #parts == 2 then
      f:write("\tvlan-raw-device " .. parts[1])
    end
  end

  if bridge_ifaces ~= nil then
    f:write("\tbridge_ports ".. table.concat(bridge_ifaces, " ") .. "\n")
    f:write("\tbridge_stp off\n")
  end
end

-- ################################################################

function config.openNetworkInterfacesConfigFile()
  local network_conf_file = "ntop.conf"
  local network_custom_conf_file = "ntop_mgmt.conf"

  if ntop.isnEdge() then
    network_conf_file = "nedge.conf"
    network_custom_conf_file = "nedge_mgmt.conf"
  end

  -- verify that the file is actually included
  for _, source in ipairs({network_conf_file, network_custom_conf_file}) do
    local source_line = "source /etc/network/interfaces.d/"..source
    local res = sys_utils.execShellCmd("grep \"^" .. source_line .. "\" /etc/network/interfaces 2>/dev/null")

    if isEmptyString(res) then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "Adding missing '" .. source_line .. "'")

      local f = sys_utils.openFile("/etc/network/interfaces", "a")
      f:write("\n" .. source_line .. "\n")
      f:close()
    end
  end

  return sys_utils.openFile("/etc/network/interfaces.d/"..network_conf_file, "w")
end

-- ################################################################

function config.closeNetworkInterfacesConfigFile(f)
  f:close()
end

-- ################################################################

function config.backupNetworkInterfacesFiles(to_backup)
  os.rename("/etc/network/interfaces", "/etc/network/interfaces.old")
  traceError(TRACE_WARNING, TRACE_CONSOLE, "/etc/network/interfaces has been moved to /etc/network/interfaces.old")
end

-- ################################################################

function config.isConfiguredInterface(iface)
  local res = sys_utils.execShellCmd("grep \"^\\s*[^#]*" .. iface .. "\" /etc/network/interfaces")
  return not isEmptyString(res)
end

-- ################################################################

function config.dhcpInterfaceGetGateway(iface)
  local res = sys_utils.execShellCmd("grep \"option routers\" /var/lib/dhcp/dhclient." .. iface .. ".leases 2>/dev/null | tail -n 1")

  if not isEmptyString(res) then
    return res:gmatch("routers ([^;]+)")()
  end

  return res
end

-- ################################################################

return config
