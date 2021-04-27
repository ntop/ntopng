--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local callback_utils = require("callback_utils")
local hosts_map_utils = require("hosts_map_utils")

local HostsMapMode = hosts_map_utils.HostsMapMode
local MODES = hosts_map_utils.MODES

local MAX_RADIUS_PX = 30
local MIN_RADIUS_PX = 3

local rc = rest_utils.consts.success.ok
local first_host_table = {}
local second_host_table = {}
local max_radius = 0

-- Note To change the label "Remote Hosts" and "Local Hosts" shown
-- into the chart, just change the value of these names
local first_table_name = "Local Hosts"
local second_table_name = "Remote Hosts"
-- Change check_condition if you want a different condition to put hosts into the tables
local check_condition
local formatHost

local bubble_mode = tonumber(_GET["bubble_mode"]) or 0
local show_remote = _GET["show_remote"] or true

-- ###################################################

local function shrinkTable(t, max_num)
   local n = 1
   local t2 = {}
   
   for i,v in pairsByField(t, 'z', rev) do
      if(n < max_num) then
        t2[n] = v
        n = n + 1
      end
   end

   return(t2)
end

-- List of the functions used to get the necessary functions
-- ###################################################

local function allFlows(hostname, host, label)
   local line
   
   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = host["active_flows.as_server"],
      y = host["active_flows.as_client"],
      z = host["bytes.sent"] + host["bytes.rcvd"]
   }      

   return line
end

-- ###################################################

local function unreachableFlows(hostname, host, label)
   local line
   
   if (host["unreachable_flows.as_server"] + host["unreachable_flows.as_client"] > 0) then
      line = {
	 meta = {
	    url_query = "host="..hostname,
	    label = label,
	 },
	 x = host["unreachable_flows.as_server"],
	 y = host["unreachable_flows.as_client"],
	 z = host["bytes.sent"] + host["bytes.rcvd"]
      }
   end
   
   return line
end

-- ###################################################

local function alertedFlows(hostname, host, label)
   local line
   
   if ((host["alerted_flows.as_server"] ~= nil) and
       (host["alerted_flows.as_client"] ~= nil) and
       (host["alerted_flows.as_server"] + host["alerted_flows.as_client"] > 0)) then

      line = {
	 meta = {
	    url_query = "host="..hostname,
	    label = label,
	 },
	 x = host["alerted_flows.as_server"],
	 y = host["alerted_flows.as_client"],
	 z = host["alerted_flows.as_server"] + host["alerted_flows.as_client"]
      }
   end

   return line
end

-- ###################################################

local function dnsQueries(hostname, host, label)
   local line
   
   if ((host["dns"] ~= nil) and
      ((host["dns"]["sent"]["num_queries"] + host["dns"]["rcvd"]["num_queries"]) > 0)) then
      local x = host["dns"]["rcvd"]["num_replies_ok"]
      local y = host["dns"]["sent"]["num_queries"]
      
      line = {
	 meta = {
	    url_query = "host="..hostname,
	    label = label,
	 }, 
	 x = x, 
	 y = y, 
	 z = x + y
      }
   end

   return line
end

-- ###################################################

local function dnsBytes(hostname, host, label)
   local line
   host = interface.getTrafficMapHostStats(hostname)
   
   if ((host ~= nil) and
       (host["dns_traffic"] ~= nil) and
      ((host["dns_traffic"]["sent"] + host["dns_traffic"]["rcvd"]) > 0)) then
      local x = host["dns_traffic"]["rcvd"]
      local y = host["dns_traffic"]["sent"]
      line = {
	 meta = {
	    url_query = "host="..hostname,
	    label = label,
	 }, 
	 x = x, 
	 y = y, 
	 z = x + y
      }
   end

   return line
end

-- ###################################################

local function ntpPkts(hostname, host, label)
   local line
   host = interface.getTrafficMapHostStats(hostname)

   if ((host ~= nil) and
       (host["ntp_traffic"] ~= nil) and
      ((host["ntp_traffic"]["sent"] + host["ntp_traffic"]["rcvd"]) > 0)) then
      local x = host["ntp_traffic"]["rcvd"]
      local y = host["ntp_traffic"]["sent"]
      
      line = {
	 meta = {
	    url_query = "host="..hostname,
	    label = label,
	 }, 
	 x = x, 
	 y = y, 
	 z = x + y
      }
   end

   return line
end

-- ###################################################

local function synDistribution(hostname, host, label)
   local line
   local stats = interface.getHostInfo(host["ip"], host["vlan"])
   
   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = stats["pktStats.sent"]["tcp_flags"]["syn"],
      y = stats["pktStats.recv"]["tcp_flags"]["syn"],
      z = host["active_flows.as_client"] + host["active_flows.as_server"]
   }

   return line
end

-- ###################################################

local function synVsRst(hostname, host, label)
   local line
   local stats = interface.getHostInfo(host["ip"], host["vlan"])
   
   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = stats["pktStats.sent"]["tcp_flags"]["syn"],
      y = stats["pktStats.recv"]["tcp_flags"]["rst"],
      z = host["active_flows.as_client"] + host["active_flows.as_server"]
   }

   return line
end

-- ###################################################

local function synVsSynack(hostname, host, label)
   local line
   local stats = interface.getHostInfo(host["ip"], host["vlan"])
   
   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = stats["pktStats.sent"]["tcp_flags"]["syn"],
      y = stats["pktStats.recv"]["tcp_flags"]["synack"],
      z = host["active_flows.as_client"] + host["active_flows.as_server"]
   }

   return line
end

-- ###################################################

local function tcpPktsSentVsRcvd(hostname, host, label)
   local line
   local stats = interface.getHostInfo(host["ip"], host["vlan"])
   
   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = stats["tcp.packets.sent"],
      y = stats["tcp.packets.rcvd"],
      z = stats["tcp.bytes.sent"] + stats["tcp.bytes.rcvd"]
   }

   return line
end

-- ###################################################

local function tcpBytesSentVsRcvd(hostname, host, label)
   local line
   local stats = interface.getHostInfo(host["ip"], host["vlan"])

   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = stats["tcp.bytes.sent"],
      y = stats["tcp.bytes.rcvd"],
      z = stats["tcp.bytes.sent"] + stats["tcp.bytes.rcvd"]
   }
   
   return line
end

-- ###################################################

local function activeAlertFlows(hostname, host, label)
   local line

   if (host["active_alerted_flows"] > 0) then
      line = {
	 meta = {
	    url_query = "host="..hostname,
	    label = label,
	 },
	 x = host["active_flows.as_server"],
	 y = host["active_flows.as_client"],
	 z = host["active_alerted_flows"]
      }
   end

   return line
end

-- ###################################################

local function trafficRatio(hostname, host, label)
   local line

   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = host["bytes_ratio"],
      y = host["pkts_ratio"],
      z = host["bytes.sent"] + host["bytes.rcvd"]
   }
   
   return line
end

-- ###################################################

local function score(hostname, host, label)
   local line

   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = host["score.as_client"],
      y = host["score.as_server"],
      z = host["score.as_client"] + host["score.as_server"]
   }
   
   return line
end

-- ###################################################

local function blacklistedFlowsHosts(hostname, host, label)
   local line

   line = {
      meta = {
	 url_query = "host="..hostname,
	 label = label,
      },
      x = host.num_blacklisted_flows.as_client,
      y = host.num_blacklisted_flows.as_server,
      z = host.num_blacklisted_flows.as_client + host.num_blacklisted_flows.as_server
   }
   
   return line
end

-- ###################################################

local function processHost(hostname, host)
    local line
    local label = host.name

    check_condition = (host.localhost ~= nil) and (host.localhost == true)

    -- starts is defined inside the lua_utils module
    if ((label == nil) or (string.len(label) == 0) or starts(label, "@")) then
        label = hostname
    end

    line = nil

    line = formatHost(hostname, host, label)

    if (line ~= nil) then        
       if (line.z > max_radius) then
	  max_radius = line.z
       end

       if(check_condition) then
	  table.insert(first_host_table, line)
       else
	  table.insert(second_host_table, line)
       end
    end
end

-- ###################################################

-- Switch case used to know which function to format the hosts needs to be used
if (bubble_mode == HostsMapMode.ALL_FLOWS) then
   formatHost = allFlows
elseif (bubble_mode == HostsMapMode.UNREACHABLE_FLOWS) then
   formatHost = unreachableFlows    
elseif (bubble_mode == HostsMapMode.ALERTED_FLOWS) then
   formatHost = alertedFlows
elseif (bubble_mode == HostsMapMode.DNS_QUERIES) then
   formatHost = dnsQueries
elseif (bubble_mode == HostsMapMode.DNS_BYTES) then
   formatHost = dnsBytes    
elseif (bubble_mode == HostsMapMode.NTP_PACKETS) then
   formatHost = ntpPkts
elseif (bubble_mode == HostsMapMode.SYN_DISTRIBUTION) then
   formatHost = synDistribution
elseif (bubble_mode == HostsMapMode.SYN_VS_RST) then
   formatHost = synVsRst    
elseif (bubble_mode == HostsMapMode.SYN_VS_SYNACK) then
   formatHost = synVsSynack    
elseif (bubble_mode == HostsMapMode.TCP_PKTS_SENT_VS_RCVD) then
   formatHost = tcpPktsSentVsRcvd    
elseif (bubble_mode == HostsMapMode.TCP_BYTES_SENT_VS_RCVD) then
   formatHost = tcpBytesSentVsRcvd
elseif (bubble_mode == HostsMapMode.ACTIVE_ALERT_FLOWS) then
   formatHost = activeAlertFlows
elseif (bubble_mode == HostsMapMode.TRAFFIC_RATIO) then
   formatHost = trafficRatio    
elseif (bubble_mode == HostsMapMode.SCORE) then
   formatHost = score
elseif (bubble_mode == HostsMapMode.BLACKLISTED_FLOWS_HOSTS) then
   formatHost = blacklistedFlowsHosts
end

-- Callback cycle
if (show_remote) then
    callback_utils.foreachHost(ifname, processHost)
else
    callback_utils.foreachLocalHost(ifname, processHost)
end

-- Reduce the number of hosts to a reasonable value (< max_num)
local max_num = 999
first_host_table  = shrinkTable(first_host_table, max_num)
second_host_table = shrinkTable(second_host_table, max_num)

-- Normalize values
local ratio = max_radius / MAX_RADIUS_PX
for i,v in pairs(first_host_table) do 
    first_host_table[i].z = math.floor(MIN_RADIUS_PX + first_host_table[i].z / ratio) 
end

if (show_remote) then
    for i,v in pairs(second_host_table) do 
        second_host_table[i].z = math.floor(MIN_RADIUS_PX + second_host_table[i].z / ratio) 
    end
end

local base_url = ntop.getHttpPrefix() .. "/lua/host_details.lua"

-- Formatting Answer
rest_utils.answer(rc, {
    series = {
       {data = first_host_table, name = first_table_name, base_url = base_url},
       {data = second_host_table, name = second_table_name, base_url = base_url},
    },
    chart = {
        zoom = {
            autoScaleYaxis = true
        }
    },
    grid = {
        padding = {
            left = 6
        },
    },
    colors = {"rgba(153, 102, 255, 0.45)", "rgba(255, 159, 64, 0.45)"},
    xaxis = {
        type = 'numeric',
        title = {
            text = MODES[bubble_mode + 1].x_label,
        },
        labels = {
            ntop_utils_formatter = MODES[bubble_mode + 1].x_formatter or 'fnone',
        }
    },
    yaxis = {
        type = 'numeric',
        forceNiceScale = true,
        title = {
            text = MODES[bubble_mode + 1].y_label,
            offsetX = 6
        },
        labels = {
            ntop_utils_formatter = MODES[bubble_mode + 1].y_formatter or 'fnone',           
        }
    },
    dataLabels = {
       enabled = false
    },
    tooltip = {
       widget_tooltips_formatter = "showXY"
    }
})
