--
-- (C) 2013-26 - ntop.org
--

local sys_utils = require "sys_utils"

local smcroute = {}

local service_name = "smcroute"
local redis_key = "ntopng.nedge.smcroute.enabled"

-- ###############################################################

-- Helper function to build interface list excluding one interface
-- @param ifaces Array of interface names
-- @param to_exclude Interface name to exclude from the list
-- @return String with space-separated interface names
local function get_iface_list(ifaces, to_exclude)
  local iface_list_string = ""

  for _,iface in ipairs(ifaces) do
    if (iface ~= to_exclude) then
      iface_list_string = iface_list_string..iface.." "
    end
  end

  return iface_list_string
end

-- ###############################################################

-- Writes the smcroute configuration file
-- Note:
-- - MDNS forwarding is implemented by ntopng
-- - Custom multicast forwarding is based on smcroute
-- @param repeaters_config The repeaters configuration table
-- @return true if custom configuration exists, false otherwise
function smcroute.writeSmcrouteConfiguration(repeaters_config)
  if not repeaters_config then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid parameters for writeSmcrouteConfiguration")
    return false
  end

  local has_custom_config = false

  -- Write smcroute config file "/etc/smcroute.conf"
  local f = sys_utils.openFile("/etc/smcroute.conf", "w")
  if not f then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Cannot open /etc/smcroute.conf for writing")
    return false
  end

  for _,r_config in ipairs(repeaters_config) do
    if (r_config.type == "custom") then
      has_custom_config = true
      local ip = r_config.ip

      local interfaces = not isEmptyString(r_config.interfaces) and split(r_config.interfaces, ",") or {}
      local restricted_interfaces = not isEmptyString(r_config.restricted_interfaces) and split(r_config.restricted_interfaces, ",") or {}
      local all_interfaces = table.merge(interfaces, restricted_interfaces, true)

      for _,iface in ipairs(interfaces) do
        f:write("\n")
        local outbound = get_iface_list(interfaces, iface)
        if not isEmptyString(outbound) then
          f:write("mgroup from "..iface.." group "..ip.."\n")
          f:write("mroute from "..iface.." group "..ip.." to "..outbound.."\n")
        end
      end

      for _,iface in ipairs(restricted_interfaces) do
        f:write("\n")
        local outbound = get_iface_list(all_interfaces, iface)
        if not isEmptyString(outbound) then
          f:write("mgroup from "..iface.." group "..ip.."\n")
          f:write("mroute from "..iface.." group "..ip.." to "..outbound.."\n")
        end
      end

    end
  end

  f:close()
  return has_custom_config
end

-- ###############################################################

-- This function is used to check if the smcroute status is up
-- and if not, restart it.
function smcroute.checkRestartSmcrouteService()
  if ntop.isnEdge and ntop.isnEdge() then
    if (ntop.getCache(redis_key) or '0') == '1' then
      if not sys_utils.isActiveService(service_name) then
        sys_utils.restartService(service_name)
      end
    end
  end
end

-- ###############################################################

-- This function is used to check if the smcroute status is up
-- and if not, restart it.
function smcroute.startSmcrouteService()
  if ntop.isnEdge and ntop.isnEdge() then
    ntop.setCache(redis_key, '1')
    sys_utils.enableService(service_name)
    sys_utils.restartService(service_name)
  end
end

-- ###############################################################

-- This function is used to check if the smcroute status is up
-- and if not, restart it.
function smcroute.stopSmcrouteService()
  if ntop.isnEdge and ntop.isnEdge() then
    ntop.setCache(redis_key, '0')
    sys_utils.disableService(service_name)
    sys_utils.stopService(service_name)
  end
end

-- ###############################################################

return smcroute
