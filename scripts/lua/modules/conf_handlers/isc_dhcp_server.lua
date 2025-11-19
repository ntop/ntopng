--
-- (C) 2013-24 - ntop.org
--

local sys_utils = require "sys_utils"

local isc_dhcp_server = {}

-- ###############################################################

-- Writes the ISC DHCP server configuration files
-- @param dhcp_config The DHCP server configuration table
-- @param all_interfaces Table mapping interface names to roles (lan/wan)
-- @param dns_config The DNS configuration table with global and secondary DNS
-- @return true on success, false on error
function isc_dhcp_server.writeDhcpServerConfiguration(dhcp_config, all_interfaces, dns_config)
  if not dhcp_config or not all_interfaces or not dns_config then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid parameters for writeDhcpServerConfiguration")
    return false
  end

  local lan_interfaces = ""
  local count = 0

  -- Create the string for the isc-dhcp-server.
  -- It has to be like:      INTERFACES=" eno1.11 eno1.12"
  for if_name, role in pairsByKeys(all_interfaces, asc_insensitive) do
    if (role == "lan") and (dhcp_config["subnet"][if_name]) and (dhcp_config["subnet"][if_name]["enabled"] == "1") then
      -- To not place the space at the start of the string
      if count == 0 then
        lan_interfaces = if_name
        count = 1
      else
        lan_interfaces = lan_interfaces .. " " .. if_name
      end
    end
  end

  -- Write the isc-dhcp-server file
  local f = sys_utils.openFile("/etc/default/isc-dhcp-server", "w")
  if not f then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Cannot open /etc/default/isc-dhcp-server for writing")
    return false
  end
  f:write("INTERFACES=\""..lan_interfaces.."\"\n")
  f:close()

  -- Now modify the dhcpd.conf file
  f = sys_utils.openFile("/etc/dhcp/dhcpd.conf", "w")
  if not f then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Cannot open /etc/dhcp/dhcpd.conf for writing")
    return false
  end

  for _, opt in ipairs(dhcp_config.options) do
    f:write(opt .. ";\n")
  end

  local configure_option_114 = false
  local configure_option_160 = false
  for if_name, role in pairsByKeys(all_interfaces, asc_insensitive) do
    local lan_dhcp_config = dhcp_config["subnet"][if_name]
    if (role == "lan") and (lan_dhcp_config) and (dhcp_config["subnet"][if_name]["enabled"] == "1") then
      if not isEmptyString(lan_dhcp_config["option_114"]) then
        configure_option_114 = true
      end
      if not isEmptyString(lan_dhcp_config["option_160"]) then
        configure_option_160 = true
      end
    end
  end

  if configure_option_114 then
    f:write("option option-114 code 114 = text;\n")
  end
  if configure_option_160 then
    f:write("option option-160 code 160 = text;\n")
  end

  -- Each LAN interfaces needs a different DHCP, so iterate all the LAN interfaces
  -- and update the configuration from the one added in the GUI
  -- IMPORTANT NOTE: in the dhcp_config.subnet configuration ALL the interfaces are present
  --                 for this reason we need a check on the LAN here
  for if_name, role in pairsByKeys(all_interfaces, asc_insensitive) do
    local lan_dhcp_config = dhcp_config["subnet"][if_name]
    if (role == "lan") and (lan_dhcp_config) and (dhcp_config["subnet"][if_name]["enabled"] == "1") then
      f:write("\n")
      f:write("subnet ".. lan_dhcp_config["network"] .." netmask ".. lan_dhcp_config["netmask"] .." {\n")
      f:write("  range " .. lan_dhcp_config["first_ip"] .. " " .. lan_dhcp_config["last_ip"] .. ";\n")
      f:write("  option domain-name-servers " .. table.concat({
          dns_config.global,
          ternary(not isEmptyString(dns_config.secondary), dns_config.secondary, nil)
        },", ") .. ";\n")
      f:write("  option routers " .. lan_dhcp_config["gateway"] .. ";\n")
      f:write("  option subnet-mask ".. lan_dhcp_config["netmask"] ..";\n")
      f:write("  option broadcast-address " .. lan_dhcp_config["broadcast"] .. ";\n")

      -- Write all the extra options
      for _, opt in ipairs(lan_dhcp_config["options"] or {}) do
        f:write("  " .. opt .. ";\n")
      end

      if not isEmptyString(lan_dhcp_config["option_114"]) then
        f:write("  option option-114 \"" .. lan_dhcp_config["option_114"] .. "\";\n")
      end
      if not isEmptyString(lan_dhcp_config["option_160"]) then
        f:write("  option option-160 \"" .. lan_dhcp_config["option_160"] .. "\";\n")
      end

      f:write("}\n")
    end
  end

  for mac, lease in pairs(dhcp_config.leases) do
    f:write("\n")
    f:write("host " .. lease.hostname .. " {\n")
    f:write("  hardware ethernet " .. mac .. ";\n")
    f:write("  fixed-address " .. lease.ip .. ";\n")
    f:write("}\n")
  end

  f:close()
  return true
end

-- ###############################################################

return isc_dhcp_server
