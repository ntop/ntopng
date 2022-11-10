--
-- (C) 2013-22 - ntop.org
--

local sys_utils = require "sys_utils"
local service_name = "isc-dhcp-server"

local redis_key = "ntopng.nedge.dhcp.enabled"

local dhcp_service_utils = {}

-- This function is used to check if the DHCP server status is up 
-- and if not, restart it.
function dhcp_service_utils.checkRestartDHCPService()
  if ntop.isnEdge() then
    if (ntop.getCache(redis_key) or '0') == '1' then
      if not sys_utils.isActiveService(service_name) then
        sys_utils.restartService(service_name)
      end
    end
  end
end

-- ###############################################################

-- This function is used to check if the DHCP server status is up 
-- and if not, restart it.
function dhcp_service_utils.startDHCPService()
  if ntop.isnEdge() then
    ntop.setCache(redis_key, '1')
    sys_utils.enableService(service_name)
    sys_utils.restartService(service_name)
  end
end

-- ###############################################################

-- This function is used to check if the DHCP server status is up 
-- and if not, restart it.
function dhcp_service_utils.stopDHCPService()
  if ntop.isnEdge() then
    ntop.setCache(redis_key, '0')
    sys_utils.disableService(service_name)
    sys_utils.stopService(service_name)
  end
end

return dhcp_service_utils
