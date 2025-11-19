--
-- (C) 2013-24 - ntop.org
--

require "ntop_utils"
local sys_utils = require "sys_utils"

local dhcp_enabled_key = "ntopng.nedge.dhcp.kea.enabled"

local dhcp_server_utils = {}

-- ###############################################################

-- Cached module (check once)
local cached_module = nil

-- ###############################################################

-- @brief Check if a systemd service exists
-- @param service_name The name of the systemd service
-- @return true if the service exists, false otherwise
local function serviceExists(service_name)
  local cmd = "systemctl list-unit-files " .. service_name .. ".service 2>/dev/null | grep -q " .. service_name
  local result = sys_utils.execShellCmd(cmd .. " && echo 'exists'")
  return not isEmptyString(result)
end

-- ###############################################################

-- Detect which DHCP server is available on the system and return
-- the appropriate DHCP server module (kea_dhcp_server or isc_dhcp_server)
function dhcp_server_utils.getDhcpServerHandler()
  if cached_module then
    return cached_module
  end

  local kea_service = "kea-dhcp4-server"
  local kea_service_alias "isc-kea-dhcp4-server"
  local isc_service = "isc-dhcp-server"

  -- Check if kea-dhcp4-server systemd service exists
  local kea_exists = serviceExists(kea_service)

  if not kea_exists then
    -- Try with the service alias (this depends on version)
    kea_service = kea_service_alias
    kea_exists = serviceExists(kea_service)
  end

  if kea_exists then
    traceError(TRACE_INFO, TRACE_CONSOLE, "Using Kea DHCP server")
    cached_module = require "conf_handlers.kea_dhcp_server"
    cached_module.service_name = kea_service
  else
    traceError(TRACE_INFO, TRACE_CONSOLE, "Using ISC DHCP server")
    cached_module = require "conf_handlers.isc_dhcp_server"
    cached_module.service_name = isc_service
  end

  return cached_module
end

-- ###############################################################

function dhcp_server_utils.getDhcpServerName()
  local dhcp_handler = dhcp_server_utils.getDhcpServerHandler()
  return dhcp_handler.service_name
end

-- ###############################################################

-- This function is used to check if the DHCP server status is up
-- and if not, restart it.
function dhcp_server_utils.checkRestartDHCPService()
  if ntop.isnEdge() then
    local dhcp_handler = dhcp_server_utils.getDhcpServerHandler()
    if (ntop.getCache(dhcp_enabled_key) or '0') == '1' then
      if not sys_utils.isActiveService(dhcp_handler.service_name) then
        sys_utils.restartService(dhcp_handler.service_name)
      end
    end
  end
end

-- ###############################################################

-- This function is used to start the DHCP server
function dhcp_server_utils.startDHCPService()
  if ntop.isnEdge() then
    local dhcp_handler = dhcp_server_utils.getDhcpServerHandler()
    ntop.setCache(dhcp_enabled_key, '1')
    sys_utils.enableService(dhcp_handler.service_name)
    sys_utils.restartService(dhcp_handler.service_name)
  end
end

-- ###############################################################

-- This function is used to stop the DHCP server
function dhcp_server_utils.stopDHCPService()
  if ntop.isnEdge() then
    local dhcp_handler = dhcp_server_utils.getDhcpServerHandler()
    ntop.setCache(dhcp_enabled_key, '0')
    sys_utils.disableService(dhcp_handler.service_name)
    sys_utils.stopService(dhcp_handler.service_name)
  end
end

-- ###############################################################

-- @brief Write DHCP server configuration
-- @param dhcp_config The DHCP server configuration table
-- @param all_interfaces Table mapping interface names to roles (lan/wan)
-- @param dns_config The DNS configuration table with global and secondary DNS
-- @return true on success, false on error
function dhcp_server_utils.writeDhcpServerConfiguration(dhcp_config, all_interfaces, dns_config)
  local dhcp_handler = dhcp_server_utils.getDhcpServerHandler()
  return dhcp_handler.writeDhcpServerConfiguration(dhcp_config, all_interfaces, dns_config)
end

-- ###############################################################

return dhcp_server_utils
