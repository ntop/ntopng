--
-- ###################################################################################
-- nst_export_flows_data.lua (v1.05)
--
-- NST - 2017, 2020:
--    Export selective Flow Data as an array of JSON objects.
--
-- Usage Example:
--   curl --insecure  --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_flows_data.lua?perPage=30&sortColumn=column_thpt&sortOrder=desc";
--
-- Usage Example (Silent):
--   curl --silent --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_flows_data.lua?perPage=30&sortColumn=column_thpt&sortOrder=desc";
--
-- Usage Example (Send to 'jq'):
--   curl --silent --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_export_flows_data.lua?perPage=30&sortColumn=column_thpt&sortOrder=desc&p_nstifnamelist=fw0,netmon0" | jq .;
-- 
--    Where:
--              perPage - Number of flows to be provided in result.
--
--           sortColumn - Name of flow column to sort on. Can be one of:
--                        "column_client", "column_server", "column_bytes",
--                        "column_vlan", "column_info", "column_ndpi",
--                        "column_duration", "column_thpt" or "column_proto_l4".
--
--            sortOrder - Sort order: "desc" - Descending or "asc" - Ascending.
--
--      p_nstifnamelist - Optional comma separated Network Interface name
--                        list. If omitted, All host selective data for each
--                        configured ntopng network interfaces will be used.
--
--  Example Output:
--  [
--    {
--      "netint": "fw0",
--      "data": [
--        {
--          "cli": "24.97.150.194",		-- cli - Client
--          "spt": "54426",			-- spt - Source Port
--          "srv": "104.107.42.57",		-- srv - Server
--          "dpt": "80",			-- dpt - Destination Port
--          "vln": "0",				-- vln - vLAN
--          "l4p": "TCP",			-- l4p - Layer 4 Protocol
--          "dpi": "HTTP.eBay",			-- dpi - nDPI (Application Layer)
--          "dur": "1668",			-- dur - Flow Duration
--          "cby": "396413",			-- cby - Total Bytes Client Sent To Server
--          "sby": "5239537",			-- sby - Total Bytes Server Sent To Client
--          "ctp": "9763.03",			-- ctp - Actual Throughput Client To Server
--          "stp": "190356.78"			-- stp - Actual Throughput Server To Client
--       }
--     ],
--      "flows": 1,
--      "sort": [
--        "column_thpt",
--        "desc"
--      ],
--      "totalflows": 10275
--    },
--    {
--      "netint": "netmon0",
--      "data": [
--        {
--          "cli": "110.44.46.149",
--          "spt": "5353",
--          "srv": "224.0.0.251",
--          "dpt": "5353",
--          "vln": "0",
--          "l4p": "UDP",
--          "dpi": "MDNS",
--          "dur": "2352",
--          "cby": "557429",
--          "sby": "0",
--          "ctp": "3914.26",
--          "stp": "0.00"
--        }
--      ],
--      "requestflows": 1,
--      "sort": [
--        "column_thpt",
--        "desc"
--      ],
--      "totalflows": 92
--   }   
--  ]
-- ###################################################################################

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local icmp_utils = require "icmp_utils"

-- ################################# FUNCTIONS ########################################
function dumpNtopngFlows(netint)
  --
  -- Configure selective data flow dump for Network Interface: 'netint'
  interface.select(netint)
  --
  -- ntopng configured Network Interface check...
  if (not interface.isRunning()) then
    return false
  end

  --
  -- Debug set up (Need to start ntopng with --verbose 6). Output will be set
  -- to the command line or "/var/log/messages".
  --local debug = false

  ifstats = interface.getStats()

  --
  -- Allowed parameters...
  all = _GET["all"]
  currentPage = _GET["currentPage"]
  perPage     = _GET["perPage"]
  sortColumn  = _GET["sortColumn"]
  sortOrder   = _GET["sortOrder"]
  host_info   = url2hostinfo(_GET)
  port        = _GET["port"]
  application = _GET["application"]
  network_id  = _GET["network"]
  vhost       = _GET["vhost"]

  --
  -- System host parameters...
  hosts  = _GET["hosts"]
  user   = _GET["username"]
  host   = _GET["host"]
  pid    = tonumber(_GET["pid"])
  name   = _GET["pid_name"]

  --
  -- Get from redis the throughput type bps or pps...
  throughput_type = getThroughputType()

  prefs = ntop.getPrefs()

  if (network_id ~= nil) then
    network_id = tonumber(network_id)
  end

  if sortColumn == nil or sortColumn == "column_" or sortColumn == "" then
    sortColumn = getDefaultTableSort("flows")
  elseif sortColumn ~= "column_" and  sortColumn ~= "" then
    tablePreferences("sort_flows",sortColumn)
  else
    sortColumn = "column_client"
  end

  if sortOrder == nil then
    sortOrder = getDefaultTableSortOrder("flows")
  elseif sortColumn ~= "column_" and sortColumn ~= "" then
    tablePreferences("sort_order_flows",sortOrder)
  end

  if (currentPage == nil) then
    currentPage = 1
  else
    currentPage = tonumber(currentPage)
  end

  if (perPage == nil) then
    perPage = getDefaultTableSize()
  else
    perPage = tonumber(perPage)
    tablePreferences("rows_number",perPage)
  end

  if (port ~= nil) then
    port = tonumber(port)
  end

  to_skip = (currentPage - 1) * perPage

  if (all ~= nil) then
    perPage = 0
    currentPage = 0
  end

-- io.write("->"..sortColumn.."/"..perPage.."/"..sortOrder.."/"..sortColumn.."\n")

  local a2z = false
  if (sortOrder == "desc") then
    a2z = false
  else
    a2z = true
  end

  local paginfo = {
    ["sortColumn"] = sortColumn,
    ["toSkip"] = to_skip,
    ["maxHits"] = perPage,
    ["a2zSortOrder"] = a2z,
    ["hostFilter"] = host,
    ["portFilter"] = port,
    ["LocalNetworkFilter"] = network_id
  }

  if application ~= nil and application ~= "" then
    paginfo["l7protoFilter"] = interface.getnDPIProtoId(application)
  end

  local flows_stats = interface.getFlowsInfo(host, paginfo)
  local total = flows_stats["numFlows"]
  flows_stats = flows_stats["flows"]

  --
  -- Prepare host
  host_list = {}
  num_host_list = 0
  single_host = 0

  if (hosts ~= nil) then
    host_list, num_host_list = getHostCommaSeparatedList(hosts)
  end
  if (host ~= nil) then
    single_host = 1
    num_host_list = 1
  end

  vals = {}
  num = 0

  if (flows_stats == nil) then
    flows_stats = { }
  end

  for key, value in ipairs(flows_stats) do
    process = true
    client_process = 0
    server_process = 0
    --
    if (vhost ~= nil) then
      if ((flows_stats[key]["cli.host"] ~= vhost)
        and (flows_stats[key]["srv.host"] ~= vhost)
        and (flows_stats[key]["protos.http.server_name"] ~= vhost)
        and (flows_stats[key]["protos.dns.last_query"] ~= vhost)) then
          process = false
      end
    end
    --
    if (network_id ~= nil) then
       process = process and ((flows_stats[key]["cli.network_id"] == network_id) or (flows_stats[key]["srv.network_id"] == network_id))
    end
    ------------- L4 PROTO --------------
    if (l4proto ~= nil) then
      process = process and (flows_stats[key]["proto.l4"] == l4proto)
    end
    --------------- USER ----------------
    if (user ~= nil) then
      if (flows_stats[key]["client_process"] ~= nil) then
        if ((flows_stats[key]["client_process"]["user_name"] == user)) then
          client_process = 1
        end
      end
      if (flows_stats[key]["server_process"] ~= nil) then
        if ((flows_stats[key]["server_process"]["user_name"] == user)) then
          server_process = 1
        end
      end
      process = process and ((client_process == 1) or (server_process == 1))
    end
    ---------------- PID ----------------
    if (pid ~= nil) then
      if (flows_stats[key]["client_process"] ~= nil) then
        if ((flows_stats[key]["client_process"]["pid"] == pid)) then
          client_process = 1
        end
      end
      if (flows_stats[key]["server_process"] ~= nil) then
        if ((flows_stats[key]["server_process"]["pid"] == pid)) then
          server_process = 1
        end
      end
      process = process and ((client_process == 1) or (server_process == 1))
    end
    --------------- NAME ----------------
    if (name ~= nil) then
      if (flows_stats[key]["client_process"] ~= nil) then
        if ((flows_stats[key]["client_process"]["name"] == name)) then
          client_process = 1
        end
      end
      if (flows_stats[key]["server_process"] ~= nil) then
        if ((flows_stats[key]["server_process"]["name"] == name)) then
           server_process = 1
        end
      end
      process = process and ((client_process == 1) or (server_process == 1))
    end
    --------------- PORT ----------------
    if (port ~= nil) then
      process = process and ((flows_stats[key]["cli.port"] == port) or (flows_stats[key]["srv.port"] == port))
    end
    --------------- HOST ----------------
    if ((num_host_list > 0) and process) then
      if (single_host == 1) then
        process = process and ((flows_stats[key]["cli.ip"] == host_info["host"]) or (flows_stats[key]["srv.ip"] == host_info["host"]))
        process = process and (flows_stats[key]["vlan"] == host_info["vlan"])
      else
        cli_num = findStringArray(flows_stats[key]["cli.ip"],host_list)
        srv_num = findStringArray(flows_stats[key]["srv.ip"],host_list)
        if ((cli_num ~= nil) and (srv_num ~= nil)) then
          if (cli_num and srv_num) then
            process = process and (flows_stats[key]["cli.ip"] ~= flows_stats[key]["srv.ip"])
          else
            process = process and false
          end
        else
           process = process and false
        end
      end
    end
    info = ""
    if (flows_stats[key]["protos.dns.last_query"] ~= nil) then
      info = shortenString(flows_stats[key]["protos.dns.last_query"])
    elseif (flows_stats[key]["protos.http.last_url"] ~= nil) then
      info = shortenString(flows_stats[key]["protos.http.last_url"])
    elseif (flows_stats[key]["protos.ssl.certificate"] ~= nil) then
      info = shortenString(flows_stats[key]["protos.ssl.certificate"])
    elseif (flows_stats[key]["bittorrent_hash"] ~= nil) then
      info = shortenString(flows_stats[key]["bittorrent_hash"])
    elseif (flows_stats[key]["host_server_name"] ~= nil) then
      info = shortenString(flows_stats[key]["host_server_name"])
    elseif (not isEmptyString(flows_stats[key]["icmp"])) then
      info = icmp_utils.get_icmp_label(ternary(isIPv4(flows_stats[key]["cli.ip"]), 4, 6), flows_stats[key]["icmp"]["type"], flows_stats[key]["icmp"]["code"])
    elseif (flows_stats[key]["proto.ndpi"] == "SIP") then
      info = getSIPInfo(flows_stats[key])
    elseif (flows_stats[key]["proto.ndpi"] == "RTP") then
      info = getRTPInfo(flows_stats[key])
    end
    flows_stats[key]["info"] = info

    if (flows_stats[key]["profile"] ~= nil) then
      flows_stats[key]["info"] = "<span class='label label-primary'>"..flows_stats[key]["profile"].."</span> "..info
    end

    ---------------- TABLE SORTING ----------------
    if (process) then
      num = num + 1
      if (sortColumn == "column_client") then
        vkey = flows_stats[key]["cli.ip"]
      elseif (sortColumn == "column_server") then
        vkey = flows_stats[key]["srv.ip"]
      elseif (sortColumn == "column_bytes") then
        vkey = flows_stats[key]["bytes"]
      elseif (sortColumn == "column_vlan") then
        vkey = flows_stats[key]["vlan"]
      elseif (sortColumn == "column_info") then
        vkey = flows_stats[key]["info"]
      elseif (sortColumn == "column_ndpi") then
        vkey = flows_stats[key]["proto.ndpi"]
      elseif (sortColumn == "column_server_process") then
        if (flows_stats[key]["server_process"] ~= nil) then
          vkey = flows_stats[key]["server_process"]["name"]
        else
          vkey = ""
        end
      elseif (sortColumn == "column_client_process") then
        if (flows_stats[key]["client_process"] ~= nil) then
          vkey = flows_stats[key]["client_process"]["name"]
        else
          vkey = ""
        end
      elseif (sortColumn == "column_duration") then
        vkey = flows_stats[key]["duration"]
      elseif (sortColumn == "column_thpt") then
        vkey = flows_stats[key]["throughput_" .. throughput_type]
      elseif (sortColumn == "column_proto_l4") then
        vkey = flows_stats[key]["proto.l4"]
      else
	 -- By default sort by bytes
        vkey = flows_stats[key]["bytes"]
      end
      vals[key] = vkey
    end
  end

  num = 0
  if (sortOrder == "asc") then
     funct = asc
  else
     funct = rev
  end

  --
  -- Start JSON Output...
  print ('{"netint":"' .. netint .. '",')
  print ("\"data\":[")

  --[[ Loop thru selected number of flows (perPage)... --]]
  for _key, _value in pairsByValues(vals, funct) do
    value = flows_stats[_key]
    key = value["ntopng.key"]
    --
    if (key ~= nil) then
      if ((num < perPage) or (all ~= nil)) then
        if (num > 0) then
          print ","
        end
        print("{")
        --
        print("\"cli\":\"" .. value["cli.ip"] .. '",')
        --
        print("\"spt\":\"" .. value["cli.port"] .. '",')
        --
        print("\"srv\":\"" .. value["srv.ip"] .. '",')
        --
        print("\"dpt\":\"" .. value["srv.port"] .. '",')
        --
        if ((value["vlan"] ~= nil)) then
           print("\"vln\":\"" .. value["vlan"] .. '",')
        else
           print('"vln":""')
        end
        --
        print("\"l4p\":\"" .. value["proto.l4"] .. '",')
        --
        print(" \"dpi\":\"" .. value["proto.ndpi"] .. '",')
        --
        print("\"dur\":\"" .. value["duration"] .. '",')
        --
        print("\"cby\":\"" .. value["cli2srv.bytes"] .. '",')
        print("\"sby\":\"" .. value["srv2cli.bytes"] .. '",')
        --
        if ((value["throughput_trend_" .. throughput_type] ~= nil)
            and (value["throughput_trend_" .. throughput_type] > 0)) then
           if (throughput_type == "pps") then
              print("\"ctp\":\"" .. value["throughput_cli2srv_pps"] .. '",')
              print("\"stp\":\"" .. value["throughput_srv2cli_pps"] .. '"')
           else
              local ctp = string.format("%.2f", (8 * value["throughput_cli2srv_bps"]))
              print("\"ctp\":\"" .. ctp .. '",')
              local stp = string.format("%.2f", (8 * value["throughput_srv2cli_bps"]))
              print("\"stp\":\"" .. stp .. '"')
           end
        else
           print("\"ctp\":\"0.00\",")
           print("\"stp\":\"0.00\"")
        end
        print("}")
        --
        num = num + 1
      end
    end
  end

  print ("],\"requestflows\":" .. perPage.. ",")

  if (sortColumn == nil) then
     sortColumn = ""
  end

  if (sortOrder == nil) then
    sortOrder = ""
  end

  print ("\"sort\":[\"" .. sortColumn .. "\",\"" .. sortOrder .."\"],")
  print ("\"totalflows\":" .. total .. "}")
  return true
end
-- ###################################################################################


-- ####################################### CODE ######################################

--
-- Get a list of user selected Network Interfaces from URL...
intlist = _GET["p_nstifnamelist"]
if (intlist == nil) then
  --
  -- Get all configured ntopng Network Interfaces
  -- if user did not specify a list...
  ntopngints = interface.getIfNames()
else
  ntopngints = split(intlist, ",")
end

--
-- For each selected Network Interface dump selective flow data...
inum = 0
print("\n[")
for id, int in pairs(ntopngints) do
  if (inum > 0) then
    interface.select(int)
    if (interface.isRunning()) then
      print(",")
    end
  end
  rc = dumpNtopngFlows(int)
  if (rc) then
    inum = inum + 1
  end
end
print("]")
