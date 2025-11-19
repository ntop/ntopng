--
-- (C) 2013-24 - ntop.org
--

local sys_utils = require "sys_utils"
local json = require "dkjson"

local KEA_CONF_PATH = "/etc/kea/kea-dhcp4.conf"
local KEA_CONF_EXT_PATH = "/etc/ntopng/kea-dhcp4-ext.conf"

local kea_dhcp_server = {}

-- ###############################################################

-- Convert netmask to CIDR notation (e.g. 24)
-- @param netmask The netmask (e.g. 255.255.255.0)
-- @return The CIDR prefix length
local function netmask2cidr(netmask)
  if not netmask then
    return 32
  end

  local cidr = 0
  for octet in string.gmatch(netmask, "%d+") do
    local num = tonumber(octet)
    for i = 7, 0, -1 do
      if (num & (1 << i)) ~= 0 then
        cidr = cidr + 1
      else
        return cidr
      end
    end
  end

  return cidr
end

-- ###############################################################

-- Writes the Kea DHCP4 server configuration file in JSON format
-- @param dhcp_config The DHCP server configuration table
-- @param all_interfaces Table mapping interface names to roles (lan/wan)
-- @param dns_config The DNS configuration table with global and secondary DNS
-- @return true on success, false on error
function kea_dhcp_server.writeDhcpServerConfiguration(dhcp_config, all_interfaces, dns_config)
  if not dhcp_config or not all_interfaces or not dns_config then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid parameters for writeDhcpServerConfiguration")
    return false
  end

  local lan_interfaces = {}
  local subnet4_configs = {}
  local reservations = {}

  -- Build the list of LAN interfaces and subnet configurations
  for if_name, role in pairsByKeys(all_interfaces, asc_insensitive) do
    if (role == "lan") and (dhcp_config["subnet"][if_name]) and (dhcp_config["subnet"][if_name]["enabled"] == "1") then
      table.insert(lan_interfaces, if_name)

      local lan_dhcp_config = dhcp_config["subnet"][if_name]

      -- Build DNS servers list
      local dns_servers = {dns_config.global}
      if not isEmptyString(dns_config.secondary) then
        table.insert(dns_servers, dns_config.secondary)
      end

      -- Build subnet configuration
      local subnet_config = {
        subnet = lan_dhcp_config["network"] .. "/" .. netmask2cidr(lan_dhcp_config["netmask"]),
        pools = {
          {
            pool = lan_dhcp_config["first_ip"] .. " - " .. lan_dhcp_config["last_ip"]
          }
        },
        ["option-data"] = {
          {
            name = "routers",
            data = lan_dhcp_config["gateway"]
          },
          {
            name = "subnet-mask",
            data = lan_dhcp_config["netmask"]
          },
          {
            name = "broadcast-address",
            data = lan_dhcp_config["broadcast"]
          },
          {
            name = "domain-name-servers",
            data = table.concat(dns_servers, ", ")
          }
        },
        interface = if_name
      }

      -- Add custom options if present
      if not isEmptyString(lan_dhcp_config["option_114"]) then
        table.insert(subnet_config["option-data"], {
          name = "url",  -- Option 114 (DHCPv4)
          code = 114,
          data = lan_dhcp_config["option_114"]
        })
      end

      if not isEmptyString(lan_dhcp_config["option_160"]) then
        table.insert(subnet_config["option-data"], {
          name = "option-160",
          code = 160,
          data = lan_dhcp_config["option_160"]
        })
      end

      -- Add any extra options from the configuration
      if lan_dhcp_config["options"] then
        for _, opt in ipairs(lan_dhcp_config["options"]) do
          -- Options here are ISC specific, no need add add them here
          -- we will support a custom configuration file to be merged with 
          -- the one generated here to handle custom options.
        end
      end

      table.insert(subnet4_configs, subnet_config)
    end
  end

  -- Build host reservations (static leases)
  for mac, lease in pairs(dhcp_config.leases or {}) do
    table.insert(reservations, {
      ["hw-address"] = mac,
      ["ip-address"] = lease.ip,
      hostname = lease.hostname
    })
  end

  -- Build the complete Kea DHCP4 configuration
  local kea_config = {
    ["Dhcp4"] = {
      ["interfaces-config"] = {
        interfaces = lan_interfaces,
        ["dhcp-socket-type"] = "raw"
      },
      ["valid-lifetime"] = 4000,
      ["renew-timer"] = 1000,
      ["rebind-timer"] = 2000,
      ["lease-database"] = {
        type = "memfile",
        ["persist"] = true,
        name = "/var/lib/kea/dhcp4.leases"
      },
      ["expired-leases-processing"] = {
        ["reclaim-timer-wait-time"] = 10,
        ["flush-reclaimed-timer-wait-time"] = 25,
        ["hold-reclaimed-time"] = 3600,
        ["max-reclaim-leases"] = 100,
        ["max-reclaim-time"] = 250,
        ["unwarned-reclaim-cycles"] = 5
      },
      subnet4 = subnet4_configs,
      reservations = reservations,
      ["loggers"] = {
        {
          name = "kea-dhcp4",
          ["output_options"] = {
            {
              output = "/var/log/kea-dhcp4.log",
              maxsize = 10485760,
              maxver = 8,
              flush = true
            }
          },
          severity = "INFO",
          ["debuglevel"] = 0
        }
      }
    }
  }

  -- Apply global DHCP options if present
  if dhcp_config.options then
    local global_options = {}
    for _, opt in ipairs(dhcp_config.options) do
      -- Parse and convert ISC format options to Kea JSON format
      -- This is a simplified version and may need enhancement
      -- depending on the specific option format used
    end
  end

  -- Check for external configuration file and merge if present
  local ext_config_f = sys_utils.openFile(KEA_CONF_EXT_PATH, "r")
  if ext_config_f then
    local ext_config_json = ext_config_f:read("*all")
    ext_config_f:close()

    if not isEmptyString(ext_config_json) then
      local ext_config, pos, err = json.decode(ext_config_json)
      if ext_config then
        -- Merge external configuration with generated configuration
        kea_config = table.merge(kea_config, ext_config)
      else
        traceError(TRACE_WARNING, TRACE_CONSOLE, "Failed to parse " .. KEA_CONF_EXT_PATH .. ": " .. (err or "unknown error"))
      end
    end
  end

  -- Create backup of existing configuration if it doesn't exist
  local KEA_CONF_BKP_PATH = KEA_CONF_PATH .. ".bkp"
  if ntop.exists(KEA_CONF_PATH) and not ntop.exists(KEA_CONF_BKP_PATH) then
    os.execute("cp " .. KEA_CONF_PATH .. " " .. KEA_CONF_BKP_PATH)
  end

  local json_str = json.encode(kea_config, { indent = true })
  if not json_str then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Failed to encode Kea configuration to JSON")
    return false
  end

  -- Write the Kea DHCP4 configuration file in JSON format
  local f = sys_utils.openFile(KEA_CONF_PATH, "w")
  if not f then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Cannot open " .. KEA_CONF_PATH .. " for writing")
    return false
  end

  f:write(json_str)

  f:close()

  return true
end

-- ###############################################################

return kea_dhcp_server
