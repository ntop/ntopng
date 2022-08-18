--
-- (C) 2013-22 - ntop.org
--


local tag_utils = require "tag_utils"
local dscp_consts = require "dscp_consts"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local flow_risk_utils = require "flow_risk_utils"
local country_codes = require "country_codes"
local historical_flow_details_formatter = require "historical_flow_details_formatter"

local historical_flow_utils = {}

------------------------------------------------------------------------
-- Utility Functions

-- #####################################

function historical_flow_utils.formatHistoricalFlowDetails(flow)
  local flow_details = {}

  if flow then
    flow_details = historical_flow_details_formatter.formatHistoricalFlowDetails(flow)
  end

  return flow_details
end

-- #####################################

function historical_flow_utils.fixWhereTypes(query)
   local result = query

   local flow_columns = historical_flow_utils.get_flow_columns()
   for column, info in pairs(flow_columns) do
      if info.where_func then
         result = result:gsub(column ..   "=" , column ..   "="  .. info.where_func)
         result = result:gsub(column ..  " = ", column ..  " = " .. info.where_func)

         result = result:gsub(column ..  "!=" , column ..  "!="  .. info.where_func)
         result = result:gsub(column .. " != ", column .. " != " .. info.where_func)
      end
   end

   return result
end

-- #####################################

-- Converting l4_proto and l7proto to their IDs
function historical_flow_utils.parse_asn(asn)
   if not isEmptyString(asn) then
      local tmp_asn = asn
      asn = nil
      for _, p in pairs(split(tmp_asn, ",")) do
         local p_info = split(p, tag_utils.SEPARATOR)

         if not tonumber(p_info[1]) then
            local tmp = p_info[1]

            if tmp == no_asn_string then
               tmp = "0"
            end

            p_info[1] = tmp
         end

         if asn == nil then asn = '' else asn = asn .. "," end
         asn = asn .. p_info[1] .. tag_utils.SEPARATOR .. p_info[2]
      end
   end

   return asn
end

-- #####################################

-- Converting l4_proto and l7proto to their IDs
function historical_flow_utils.parse_l4_proto(l4_proto)
   if not isEmptyString(l4_proto) then
      local tmp_l4_proto = l4_proto
      l4_proto = nil
      for _, p in pairs(split(tmp_l4_proto, ",")) do
         local p_info = split(p, tag_utils.SEPARATOR)

         if not tonumber(p_info[1]) then
            local tmp = string.lower(p_info[1])
            tmp = l4_proto_to_id(tmp)

            if not p_info[1] then
               tmp = l4_proto_to_id(p_info[1])
            end

            p_info[1] = tmp
         end

         if l4_proto == nil then l4_proto = '' else l4_proto = l4_proto .. "," end
         l4_proto = l4_proto .. p_info[1] .. tag_utils.SEPARATOR .. p_info[2]
      end
   end

   return l4_proto
end

-- #####################################

function historical_flow_utils.parse_l7_cat(l7_cat)
   -- Converting l7 category to their IDs
   if l7_cat then
      local tmp_l7_cat = l7_cat
      l7_cat = nil
      for _, p in pairs(split(tmp_l7_cat, ",")) do
         local p_info = split(p, tag_utils.SEPARATOR)

         if not tonumber(p_info[1]) then
            local tmp = string.lower(p_info[1])
            tmp = interface.getnDPICategoryId(tmp)

            if not p_info[1] then
               tmp = interface.getnDPICategoryId(p_info[1])
            end

            p_info[1] = tmp
         end

         if l7_cat == nil then l7_cat = '' else l7_cat = l7_cat.. "," end
         l7_cat = l7_cat .. p_info[1] .. tag_utils.SEPARATOR .. p_info[2]
      end
   end

   return l7_cat
end

------------------------------------------------------------------------
-- Functions to convert DB columns in the format used by the JS DataTable

-- #####################################

local function dt_format_info(info)
   if not isEmptyString(profile) then
      info = string.gsub(info, " ", "")
      info = formatTrafficProfile(profile) .. info
   end

   return ({
      title = info,
      label = shortenString(info, 32)
   })
end

-- #####################################

local function dt_format_l4_proto(proto)
   local title = l4_proto_to_string(tonumber(proto))
   local l4_proto = {
      title = title,
      label = shortenString(title, 12),
      value = tonumber(proto),
   }

   return l4_proto
end

-- #####################################

local function dt_format_obs_point(obs_point_id)
   local observation_point = {
      title     = "",
      label     = "",
      value     = tonumber(obs_point_id) or 0,
   }

   if tonumber(observation_point["value"]) ~= 0 then
      observation_point["title"] = getFullObsPointName(observation_point["value"], nil, true)
      observation_point["label"] = getFullObsPointName(observation_point["value"], true, true)
   end

   return observation_point
end

-- #####################################

local function dt_format_port(port, record)
   local label

   if isEmptyString(port) then
      port = ""
   else
      port = tonumber(port)
      if port == nil or port == 0 then
         port = ""
      else
         if record["PROTOCOL"] and tonumber(record["PROTOCOL"]) > 0 then
            local service = "" -- TODO get service by port
            if not isEmptyString(service) then
               label = port .. " (" .. service .. ")"
            end
         end
      end
   end

   local port_info = {
      value = port,
      label = label or port,
   }

   return port_info
end

-- #####################################

local function dt_format_vlan(vlan_id)
   local vlan = {
      title = "",
      label = "",
      value = 0,
   }
   if not isEmptyString(vlan_id) then
      vlan["value"] = tonumber(vlan_id)
      vlan["title"] = getFullVlanName(vlan_id)
      vlan["label"] = getFullVlanName(vlan_id, true)
   end

   return vlan
end

-- #####################################

local function dt_format_tcp_flags(tcp_flags)
   local label = ""
   local flags = tonumber(tcp_flags)

   if flags then
      label = formatTCPFlags(flags)
   end

   local tcp_flags = {
      title = tcp_flags,
      label = label,
      value = tcp_flags,
   }

   return tcp_flags
end

-- #####################################

local function dt_format_location(location)
   local location_tag = {
      label = '',
   }

   if not location then
      return location_tag
   end

   if(location == "0") then -- Remote 
      location_tag["label"] = i18n("details.label_short_remote")
   elseif(location == "1") then -- Local
      location_tag["label"] = i18n("details.label_short_local_host")
   elseif(location == "2") then -- Multicast
      location_tag["label"] = i18n("short_multicast")
   end

   location_tag["value"] = location

   return location_tag
end

-- #####################################

local function dt_format_ip(ip, name, location, prefix, record)
   local vlan_id = tonumber(record["VLAN_ID"] or "0")

   -- IP
   local ip_record = {
      value     = ip, -- IP or hostname
      title     = ip, -- IP or hostname
      label     = ip, -- IP and hostname
      tag_key = prefix.."_ip",

      ip        = ip, -- IP address
      name      = "", -- Symbolic hostname (leave empty if IP only)
      reference = hostinfo2detailshref({ip = ip, vlan = vlan_id}, nil, "<i class='fas fa-laptop'></i>", "", true, nil, false),
   }

   if not isEmptyString(name) and name ~= ip then
      ip_record["value"] = name
      ip_record["title"] = name
      ip_record["name"] = name
      ip_record["label"] = hostinfo2label({ label = name, host = ip_record["value"]}, true, 16)
      ip_record["tag_key"] = prefix.."_name"
   end

   return ip_record
end

-- #####################################

local function dt_format_dst_ip(ip, record, column_name)
   if column_name == 'IPV4_DST_ADDR' and (
      (record['IP_PROTOCOL_VERSION'] and record['IP_PROTOCOL_VERSION'] ~= '4') or 
      (record['IP_PROTOCOL_VERSION'] == nil and ip == '0.0.0.0')) 
      then return nil end
   if column_name == 'IPV6_DST_ADDR' and (
      (record['IP_PROTOCOL_VERSION'] and record['IP_PROTOCOL_VERSION'] ~= '6') or 
      (record['IP_PROTOCOL_VERSION'] == nil and ip == '::')) 
      then return nil end

   return dt_format_ip(ip, record["DST_LABEL"] or "", record["SERVER_LOCATION"], "srv", record)
end

-- #####################################

local function dt_format_src_ip(ip, record, column_name)
   if column_name == 'IPV4_SRC_ADDR' and (
      (record['IP_PROTOCOL_VERSION'] and record['IP_PROTOCOL_VERSION'] ~= '4') or
      (record['IP_PROTOCOL_VERSION'] == nil and ip == '0.0.0.0'))
      then return nil end
   if column_name == 'IPV6_SRC_ADDR' and (
      (record['IP_PROTOCOL_VERSION'] and record['IP_PROTOCOL_VERSION'] ~= '6') or
      (record['IP_PROTOCOL_VERSION'] == nil and ip == '::'))
      then return nil end

   return dt_format_ip(ip, record["SRC_LABEL"] or "", record["CLIENT_LOCATION"], "cli", record)
end

-- #####################################

local function dt_format_mac(mac)
   return mac
end

-- #####################################

local function dt_format_dscp(dscp_id)
   dscp_id = tonumber(dscp_id)
   local title = dscp_consts.dscp_class_descr(dscp_id)

   return ({
      title = title,
      label = shortenString(title, 20) or "",
      value = tonumber(dscp_id),
   })
end

-- #####################################

local function dt_format_l7_proto(l7_proto, record)
  
   if not isEmptyString(l7_proto) then
    local title = interface.getnDPIProtoName(tonumber(l7_proto))
    local confidence = format_confidence_from_json(record)

    l7_proto = {
      confidence = confidence,
      title = title,
      label = shortenString(title, 12),
      value = tonumber(l7_proto),
    } 
  end
   
   return l7_proto
end

-- #####################################

local function dt_format_bytes(bytes, record, column_name, formatted_record)
   if (formatted_record ~= nil) and (formatted_record == false) then
      return tonumber(bytes)
   end

   return bytesToSize(tonumber(bytes))
end

-- #####################################

local function dt_format_time(time)
   if (time) and (tonumber(time)) then
      time = format_utils.formatPastEpochShort(time)
   end

   return time
end

-- #####################################

local function dt_format_latency_ms(int_num)
   -- Convert microseconds to milliseconds
   return tonumber(int_num) / 1000
end

-- #####################################

local function dt_format_pkts(packets)
   local pkts = 0

   if not isEmptyString(packets) then
      pkts = tonumber(packets)
   end

   return pkts
end

-- #####################################

local function dt_format_asn(processed_record, record)
   -- Client
   if not isEmptyString(record["SRC_ASN"]) then
      local cli_asn = {
         title = "",
         label = "No ASN",
         value = 0
      }

      if record["SRC_ASN"] ~= "0" then
         cli_asn["value"] = tonumber(record["SRC_ASN"])
         cli_asn["label"] = cli_asn["value"]
         local as_name = nil
         if processed_record["cli_ip"]  then
            as_name = ntop.getASName(processed_record["cli_ip"]["ip"])
            cli_asn["label"] = cli_asn["label"].. " (" .. (as_name or "") .. ")"
         end
         cli_asn["title"] = as_name or cli_asn["value"]
      end

      processed_record["cli_asn"] = cli_asn
   end
   
   -- Server
   if not isEmptyString(record["DST_ASN"]) then
      local srv_asn = {
         title = "",
         label = "No ASN",
         value = 0
      }

      if (record["DST_ASN"] ~= "0") then
         srv_asn["value"] = tonumber(record["DST_ASN"])
         srv_asn["label"] = srv_asn["value"]
         local as_name = nil
         if processed_record["srv_ip"]  then
            as_name = ntop.getASName(processed_record["srv_ip"]["ip"])
            srv_asn["label"] = srv_asn["label"] .. " (" .. (as_name or "") .. ")"
         end
         srv_asn["title"] = as_name or srv_asn["value"]
      end

      processed_record["srv_asn"] = srv_asn
   end
end

-- #####################################

local function dt_format_flow_risk(flow_risk_id)
   local flow_risks = {}

   for i = 1, 63 do
      local cur_risk = (tonumber(flow_risk_id) >> i) & 0x1

      if cur_risk > 0 then
	 local cur_risk_id = i
         local title = ntop.getRiskStr(cur_risk_id)
	 local flow_risk = {
	    title = title,
	    label = title,
	    value = cur_risk_id,
            help  = flow_risk_utils.get_documentation_link(cur_risk_id),
	 }

	 flow_risks[#flow_risks + 1] = flow_risk
      end
   end

   return flow_risks
end

-- #####################################

local function dt_format_flow_alert_id(flow_status)
   local record_status = {
      title = "",
      label = "",
      value = 0,
   }

   if not isEmptyString(flow_status) then
      flow_status = tonumber(flow_status)
      local stats_str = i18n("flow_details.normal")

      -- No status setted
      if (flow_status ~= 0) then
         stats_str = alert_consts.alertTypeLabel(flow_status, true)
      end

      record_status["title"] = stats_str
      record_status["label"] = shortenString(stats_str, 32)
      record_status["value"] = flow_status
   end

   return record_status
end

-- #####################################

local function dt_format_score(score)
  -- Score could be nil, in fact score could be not a selected column
   local score = tonumber(score) or 0
   local severity_id = map_score_to_severity(score or 0)
   local severity = {}

   if severity_id ~= 0 then
      severity = alert_consts.alertSeverityById(severity_id)
   end

   return ({
      value = score,
      label = format_utils.formatValue(score),
      color = severity.color,
   })
end

-- #####################################

local function dt_format_l7_category(l7_category)
   local formatted_cat = {
      title = "",
      label = "",
      value = 0,
   } 

   if not isEmptyString(l7_category) then
      local title = interface.getnDPICategoryName(tonumber(l7_category))
      
      formatted_cat["title"] = title
      formatted_cat["label"] = shortenString(title, 12)
      formatted_cat["value"] = tonumber(l7_category)
   end

   return formatted_cat
end

-- #####################################

local function dt_format_probe(probe_ip)
   local probe_info = {
      title     = probe_ip or "",
      label     = probe_ip or "",
      value     = probe_ip or "",
   }

   if isEmptyString(probe_ip) or probe_ip == "0.0.0.0" or probe_ip == "0" then
      probe_info["title"] = ""
      probe_info["label"] = ""
   else
      probe_info["label"] = getProbeName(probe_ip)
      if (probe_info["label"]
            and (probe_info["title"] ~= probe_info["label"]) 
            and not isEmptyString(probe_info["label"])) then
         probe_info["title"] = probe_info["title"] .. " [" .. probe_info["label"] .. "]"
      end
   end

   return probe_info
end

-- #####################################

local function dt_format_thpt(thpt)
   return bitsToSize(tonumber(thpt) or 0)
end

-- #####################################

local function dt_format_pool_id(id)
   local name = getPoolName(tonumber(id)) or id
   local pool_tag = {
      value = id,
      label = name,
      title = name,
   }

   return pool_tag
end

-- #####################################

local function dt_format_country(id)
   local country_code = interface.convertCountryU162Code(id)
   local label = ""
   if country_codes[country_code] then
      label = country_codes[country_code]
   end
   local country_tag = {
      value = country_code, -- id
      label = label,
      title = label,
   }

   return country_tag
end

-- #####################################

local function dt_format_network(network)
   local networks_stats = interface.getNetworksStats()

   -- If network is (u_int8_t)-1 then return an empty value
   if network == "65535" then
     return { value = 0, label = "", title = "" }
   end

   local network_tag = {
      value = network,
      label = network,
      title = network,
   }

   for n, ns in pairs(networks_stats) do
      if ns.network_id == tonumber(network) then
         network_tag.title = getFullLocalNetworkName(ns.network_key)
         network_tag.label = network_tag.title
      end
   end

   return network_tag
end

-- #####################################

local function dt_format_snmp_interface(interface, flow)
  local exporter = flow["PROBE_IP"]
  local label = interface
  local value = interface

  if tostring(interface) ~= "0" and not isEmptyString(exporter) then
    label = format_portidx_name(exporter, tostring(interface))
    value = exporter .. "_" .. tostring(interface)
  end
    
  local interface_tag = {
    value = value,
    label = label,
    title = interface,
  }

  return interface_tag
end

-- #####################################

local function dt_unify_l7_proto(record)
   if (record["l7proto_master"]) and (record["l7proto_master"]["value"] ~= 0) then
      local l7proto_master = tonumber(record["l7proto_master"]["value"]) or 0
      local l7proto_app = tonumber(record["l7proto"]["value"]) or 0
      local full_l7_proto = interface.getnDPIFullProtoName(l7proto_master, l7proto_app)
      record["l7proto"]["label"] = full_l7_proto
      record["l7proto"]["title"] = full_l7_proto
      -- record["l7proto"]["value"] = l7proto_app .. "." .. l7proto_master
      if l7proto_app ~= 0 then
         record["l7proto"]["value"] = l7proto_app
      else
         record["l7proto"]["value"] = l7proto_master
      end
   end
end

-- #####################################

local function simple_format_src_ip(value, record)
   if not isEmptyString(record["SRC_LABEL"]) then
      record["label"] = shortenString(record["SRC_LABEL"], 12)
   end
end

-- #####################################

local function simple_format_dst_ip(value, record)
   if not isEmptyString(record["DST_LABEL"]) then
      record["label"] = shortenString(record["DST_LABEL"], 12)
   end
end

-- #####################################

local function simple_format_src_asn(value, record)
   local ip = record["IPV4_SRC_ADDR"] or record["IPV6_SRC_ADDR"]

   if not isEmptyString(ip) then
      if tonumber(value) == 0 then 
         record["label"] = "No ASN"
      else
         record["label"] = shortenString(ntop.getASName(ip), 12)
      end
   end
end

-- #####################################

local function simple_format_dst_asn(value, record)
   local ip = record["IPV4_DST_ADDR"] or record["IPV6_DST_ADDR"]

   if not isEmptyString(ip) then
      if tonumber(value) == 0 then 
         record["label"] = "No ASN"
      else
         record["label"] = shortenString(ntop.getASName(ip), 12)
      end
   end
end

-- #####################################

local function dt_add_alerts_url(processed_record, record)

   if not record["FIRST_SEEN"] or
      not record["LAST_SEEN"] then
      return -- not from the row flow page
   end

   local op_suffix = tag_utils.SEPARATOR .. 'eq'
   processed_record["alerts_url"] = string.format('%s/lua/alert_stats.lua?page=flow&status=historical&epoch_begin=%u&epoch_end=%u&%s=%s%s&%s=%s%s&cli_port=%s%s&srv_port=%s%s', -- &l4proto=%s%s',
         ntop.getHttpPrefix(), 
         tonumber(record["FIRST_SEEN"]) - (5*60),
         tonumber(record["LAST_SEEN"]) + (5*60),
         --[[ Use name if available, IP otherwise
         processed_record.cli_ip.tag_key, processed_record.cli_ip.value, op_suffix,
         processed_record.srv_ip.tag_key, processed_record.srv_ip.value, op_suffix,
         --]]
         -- Always use IP
         "cli_ip", processed_record.cli_ip.ip, op_suffix,
         "srv_ip", processed_record.srv_ip.ip, op_suffix,
         ternary(processed_record.cli_port and processed_record.cli_port.value, processed_record.cli_port.value, ''), op_suffix,
         ternary(processed_record.srv_port and processed_record.srv_port.value, processed_record.srv_port.value, ''), op_suffix)
         --ternary(processed_record.l4proto ~= nil, processed_record.l4proto.value, ''), op_suffix)
end

-- #####################################

local function dt_format_flow(processed_record, record)
   local cli = processed_record["cli_ip"]
   local srv = processed_record["srv_ip"]
   local vlan_id = processed_record["vlan_id"]

   if cli and srv and _GET["visible_columns"] and string.find(_GET["visible_columns"], "flow") then
      -- Add flow info to the processed_record, in place of cli_ip/srv_ip
      local flow = {}
      local cli_ip = {}
      local srv_ip = {}
      local vlan = {}

      -- Converting to the same format used for alert flows (see DataTableRenders.formatFlowTuple)

      cli_ip["value"]      = cli["ip"]    -- IP address
      cli_ip["name"]       = cli["name"]  -- Host name
      cli_ip["label"]      = cli["label"] -- Label - This can be shortened if required
      cli_ip["label_long"] = cli["title"] -- Label - This is not shortened
      cli_ip["reference"]  = cli["reference"]
      cli_ip["location"]   = dt_format_location(record["CLIENT_LOCATION"])

      if processed_record["cli_country"] then
         cli_ip["country"] = processed_record["cli_country"]["value"]
      end 

      srv_ip["value"]      = srv["ip"]
      srv_ip["name"]       = srv["name"]
      srv_ip["label"]      = srv["label"]
      srv_ip["label_long"] = srv["title"]
      srv_ip["reference"]  = srv["reference"]
      srv_ip["location"]   = dt_format_location(record["SERVER_LOCATION"])

      if processed_record["srv_country"] then
         srv_ip["country"] = processed_record["srv_country"]["value"]
      end 

      vlan["value"] = vlan_id["value"]
      vlan["label"] = vlan_id["label"]
      vlan["title"] = vlan_id["title"]

      flow["cli_ip"] = cli_ip
      flow["srv_ip"] = srv_ip
      flow["vlan"] = vlan

      flow["cli_port"] = ""
      if processed_record["cli_port"] then
         flow["cli_port"] = processed_record["cli_port"]["value"]
      end

      flow["srv_port"] = ""
      if processed_record["srv_port"] then
         flow["srv_port"] = processed_record["srv_port"]["value"]
      end

      local severity_id = map_score_to_severity(tonumber(record["SCORE"]) or 0)
      local severity = alert_consts.alertSeverityById(severity_id)

      flow["highlight"] = severity.color

      processed_record["flow"] = flow

      processed_record["cli_ip"] = nil
      processed_record["srv_ip"] = nil
   end
end

-- #####################################

local function dt_add_tstamp(record)
   record["tstamp"] = tonumber(record["FIRST_SEEN"] or 0)
end

-- #####################################

local function dt_add_filter(record)
   local rules = {}

   if record["IP_PROTOCOL_VERSION"] and tonumber(record["IP_PROTOCOL_VERSION"]) == 4 then
      rules[#rules+1] = "host " .. record["IPV4_SRC_ADDR"]
      rules[#rules+1] = "host " .. record["IPV4_DST_ADDR"]
   elseif record["IP_PROTOCOL_VERSION"] and tonumber(record["IP_PROTOCOL_VERSION"]) == 6 then
      rules[#rules+1] = "host " .. record["IPV6_SRC_ADDR"]
      rules[#rules+1] = "host " .. record["IPV6_DST_ADDR"]
   end

   if record["IP_SRC_PORT"] and tonumber(record["IP_SRC_PORT"]) > 0 then
      rules[#rules+1] = "port " .. record["IP_SRC_PORT"] 
      rules[#rules+1] = "port " .. record["IP_DST_PORT"] 
   end 

   record["filter"] = {
      epoch_begin = tonumber(record["FIRST_SEEN"] or 0),
      epoch_end = tonumber(record["LAST_SEEN"] or 0) + 1,
      bpf = table.concat(rules, " and "),
   }
end

-- #####################################

------------------------------------------------------------------------
-- Functions to format DB columns to string/html (used by flow details page)

-- ##################################### 

local function format_flow_info(info, flow)
   return info or ""
end

local function format_flow_alert_id(status, flow)
   if isEmptyString(status) then
      return ""
   elseif tonumber(status) == 0 then
      return i18n("flow_details.normal")
   else
      return alert_consts.alertTypeLabel(tonumber(status), true)
   end
end

local function format_flow_score(score, flow)
   local score = tonumber(score)
   local label = format_utils.formatValue(score)

   local severity_id = map_score_to_severity(score or 0)
   if severity_id ~= 0 then
      local severity = alert_consts.alertSeverityById(severity_id)
      label = "<span style='color: "..severity.color.."'>"..label.."</span>"
   end

   return label
end

local function format_flow_observation_point(id, flow)
   return getFullObsPointName(tonumber(id), nil, true)
end

local function format_flow_latency(latency, flow)
   return (tonumber(latency) / 1000) .. " msec"
end

------------------------------------------------------------------------

-- List of flow columns in the database
--
-- Keep in sync with ClickHouseFlowDB.cpp and tag_utils.lua
--
-- - select_func is used in SELECT clause to convert DB-to-Lua the value (e.g. IP addresses)
-- - where_func is used in WHERE clause to convert Lua-to-DB the value
-- - format_func is used to format the value as string/html (used by flow details page)
-- - dt_func is used to convert the value in the format expected by the js datatable
-- - order is used to sort the fields in the flow details
local flow_columns = {
   ['FLOW_ID'] =              { tag = "rowid" },
   ['IP_PROTOCOL_VERSION'] =  {},
   ['FIRST_SEEN'] =           { tag = "first_seen",   dt_func = dt_format_time },
   ['LAST_SEEN'] =            { tag = "last_seen",    dt_func = dt_format_time },
   ['VLAN_ID'] =              { tag = "vlan_id",      dt_func = dt_format_vlan },
   ['PACKETS'] =              { tag = "packets",      dt_func = dt_format_pkts },
   ['TOTAL_BYTES'] =          { tag = "bytes",        dt_func = dt_format_bytes, js_chart_func = "bytesToSize"  },
   ['SRC2DST_BYTES'] =        {},
   ['DST2SRC_BYTES'] =        {},
   ['SRC2DST_DSCP'] =         { tag = "src2dst_dscp", dt_func = dt_format_dscp, simple_dt_func = dscp_consts.dscp_class_descr },
   ['DST2SRC_DSCP'] =         { tag = "dst2src_dscp", dt_func = dt_format_dscp, simple_dt_func = dscp_consts.dscp_class_descr },
   ['PROTOCOL'] =             { tag = "l4proto",      dt_func = dt_format_l4_proto, simple_dt_func = l4_proto_to_string },
   ['IPV4_SRC_ADDR'] =        { tag = "cli_ip",       dt_func = dt_format_src_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_src_ip },
   ['IPV6_SRC_ADDR'] =        { tag = "cli_ip",       dt_func = dt_format_src_ip, select_func = "IPv6NumToString", where_func = "IPv6StringToNum", simple_dt_func = simple_format_src_ip },
   ['IP_SRC_PORT'] =          { tag = "cli_port",     dt_func = dt_format_port },
   ['IPV4_DST_ADDR'] =        { tag = "srv_ip",       dt_func = dt_format_dst_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_dst_ip },
   ['IPV6_DST_ADDR'] =        { tag = "srv_ip",       dt_func = dt_format_dst_ip, select_func = "IPv6NumToString", where_func = "IPv6StringToNum", simple_dt_func = simple_format_dst_ip },
   ['IP_DST_PORT'] =          { tag = "srv_port",     dt_func = dt_format_port },
   ['L7_PROTO'] =             { tag = "l7proto",      dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName },
   ['L7_CATEGORY'] =          { tag = "l7cat",        dt_func = dt_format_l7_category, simple_dt_func = interface.getnDPICategoryName },
   ['FLOW_RISK'] =            { tag = "flow_risk",    dt_func = dt_format_flow_risk },
   ['INFO'] =                 { tag = "info",         dt_func = dt_format_info, format_func = format_flow_info, i18n = i18n("info"), order = 11 },
   ['PROFILE'] =              {},
   ['NTOPNG_INSTANCE_NAME'] = {},
   ['INTERFACE_ID'] =         { tag = "interface_id" },
   ['STATUS'] =               { tag = "alert_id",       dt_func = dt_format_flow_alert_id, format_func = format_flow_alert_id, i18n = i18n("status"), simple_dt_func = format_flow_alert_id , order = 8 },
   ['SRC_COUNTRY_CODE'] =     { tag = "cli_country", dt_func = dt_format_country },
   ['DST_COUNTRY_CODE'] =     { tag = "srv_country", dt_func = dt_format_country },
   ['SRC_LABEL'] =            { tag = "cli_name" },
   ['DST_LABEL'] =            { tag = "srv_name" },
   ['SRC_MAC'] =              { tag = "cli_mac", dt_func = dt_format_mac },
   ['DST_MAC'] =              { tag = "srv_mac", dt_func = dt_format_mac },
   ['COMMUNITY_ID'] =         { format_func = format_flow_info, i18n = i18n("flow_fields_description.community_id"), order = 10 },
   ['SRC_ASN'] =              { tag = "cli_asn", simple_dt_func = simple_format_src_asn },
   ['DST_ASN'] =              { tag = "srv_asn", simple_dt_func = simple_format_dst_asn },
   ['PROBE_IP'] =             { tag = "probe_ip",     dt_func = dt_format_probe, select_func = "IPv4NumToString", where_func = "IPv4StringToNum" },
   ['OBSERVATION_POINT_ID'] = { tag = "observation_point_id", dt_func = dt_format_obs_point, format_func = format_flow_observation_point, i18n = i18n("details.observation_point_id"), order = 12 },
   ['SRC2DST_TCP_FLAGS'] =    { tag = "src2dst_tcp_flags", dt_func = dt_format_tcp_flags },
   ['DST2SRC_TCP_FLAGS'] =    { tag = "dst2src_tcp_flags", dt_func = dt_format_tcp_flags },
   ['SCORE'] =                { tag = "score",        dt_func = dt_format_score, format_func = format_flow_score, i18n = i18n("score"), order = 9 },
   ['L7_PROTO_MASTER'] =      { tag = "l7proto_master", dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName },
   ['CLIENT_NW_LATENCY_US'] = { tag = "cli_nw_latency", dt_func = dt_format_latency_ms, format_func = format_flow_latency, i18n = i18n("db_search.cli_nw_latency"), order = 13 },
   ['SERVER_NW_LATENCY_US'] = { tag = "srv_nw_latency", dt_func = dt_format_latency_ms,format_func = format_flow_latency, i18n = i18n("db_search.srv_nw_latency"), order = 14 },
   ['CLIENT_LOCATION'] =      { tag = "cli_location", dt_func = dt_format_location },
   ['SERVER_LOCATION'] =      { tag = "srv_location", dt_func = dt_format_location },
   ['SRC_NETWORK_ID'] =       { tag = "cli_network", dt_func = dt_format_network },
   ['DST_NETWORK_ID'] =       { tag = "srv_network", dt_func = dt_format_network },
   ['INPUT_SNMP'] =           { tag = "input_snmp", dt_func = dt_format_snmp_interface },
   ['OUTPUT_SNMP'] =          { tag = "output_snmp", dt_func = dt_format_snmp_interface },
   ['SRC_HOST_POOL_ID'] =     { tag = "cli_host_pool_id", dt_func = dt_format_pool_id },
   ['DST_HOST_POOL_ID'] =     { tag = "srv_host_pool_id", dt_func = dt_format_pool_id },
   ['ALERTS_MAP'] =           { tag = "alerts_map" },
   ['SEVERITY'] =             { tag = "severity" },
   ['IS_CLI_ATTACKER'] =      { tag = "is_cli_attacker" },
   ['IS_CLI_VICTIM'] =        { tag = "is_cli_victim" },
   ['IS_CLI_BLACKLISTED'] =   { tag = "is_cli_blacklisted" },
   ['IS_SRV_ATTACKER'] =      { tag = "is_srv_attacker" },
   ['IS_SRV_VICTIM'] =        { tag = "is_srv_victim" },
   ['IS_SRV_BLACKLISTED'] =   { tag = "is_srv_blacklisted" },
   ['ALERT_JSON'] =           { tag = "json" },
   ['SRC_PROC_NAME'] =        { tag = "cli_proc_name" },
   ['DST_PROC_NAME'] =        { tag = "srv_proc_name" },
   ['SRC_PROC_USER_NAME'] =   { tag = "cli_user_name" },
   ['DST_PROC_USER_NAME'] =   { tag = "srv_user_name" },

   -- Alert data
   ['ALERT_STATUS'] =         { tag = "alert_status" },
   ['USER_LABEL'] =           { tag = "user_label" },
   ['USER_LABEL_TSTAMP'] =    { tag = "user_label_tstamp" },
}

-- Extra columns (e.g. result of SQL functions)
local additional_flow_columns = {
   ['bytes'] =                { tag = "bytes",        dt_func = dt_format_bytes },
   ['packets'] =              { tag = "packets",      dt_func = dt_format_pkts },
   ['THROUGHPUT'] =           { tag = "throughput",   dt_func = dt_format_thpt },
}

-- #####################################

historical_flow_utils.min_db_columns = {
   "FLOW_ID",
   "FIRST_SEEN",
   "LAST_SEEN",
   "VLAN_ID",
   "IP_PROTOCOL_VERSION",
   "IPV4_SRC_ADDR",
   "IPV4_DST_ADDR",
   "IPV6_SRC_ADDR",
   "IPV6_DST_ADDR",
   "IP_SRC_PORT",
   "IP_DST_PORT",
   "PROBE_IP",
   "SRC_LABEL",
   "DST_LABEL",
   "CLIENT_LOCATION",
   "SERVER_LOCATION",
   "COMMUNITY_ID",
}

historical_flow_utils.extra_db_columns = {
   ["throughput"] = "ABS(LAST_SEEN - FIRST_SEEN) as TIME_DELTA, (TOTAL_BYTES / (TIME_DELTA + 1)) * 8 as THROUGHPUT",
   ["alert_json"] = "ALERT_JSON"
}

historical_flow_utils.ordering_special_columns = {
   ["srv_ip"]   = {[4] = "IPv4StringToNum(IPV4_DST_ADDR)", [6] = "IPv6StringToNum(IPV6_DST_ADDR)"},
   ["cli_ip"]   = {[4] = "IPv4StringToNum(IPV4_SRC_ADDR)", [6] = "IPv6StringToNum(IPV6_SRC_ADDR)"},
   ["l7proto"]  = "L7_PROTO_MASTER",
   ["throughput"] = "THROUGHPUT"
}

historical_flow_utils.extra_where_tags = {
   ["ip"]       = { [4] = { "IPV4_DST_ADDR", "IPV4_SRC_ADDR" } , [6] = { "IPV6_DST_ADDR", "IPV6_SRC_ADDR" } },
   ["srv_ip"]   = { [4] = "IPV4_DST_ADDR", [6] = "IPV6_DST_ADDR" },
   ["cli_ip"]   = { [4] = "IPV4_SRC_ADDR", [6] = "IPV6_SRC_ADDR" },
   ["l7proto"]  = { "L7_PROTO_MASTER", "L7_PROTO" },
   ["cli_name"] = "SRC_LABEL",
   ["srv_name"] = "DST_LABEL",
   ["cli_host_pool_id"] = "SRC_HOST_POOL_ID",
   ["srv_host_pool_id"] = "DST_HOST_POOL_ID",
   ["cli_mac"] = "SRC_MAC",
   ["srv_mac"] = "DST_MAC",
   ["input_snmp"] = "INPUT_SNMP",
   ["output_snmp"] = "OUTPUT_SNMP",
   ["cli_country"] = "SRC_COUNTRY_CODE",
   ["srv_country"] = "DST_COUNTRY_CODE",
   ["vlan_id"] = "VLAN_ID",
}

historical_flow_utils.topk_tags_v4 = {
   ["host"]   = {
      "IPV4_DST_ADDR",
      "IPV4_SRC_ADDR",
   },
   ["protocol"] = {
      "L7_PROTO",
   }
}

historical_flow_utils.topk_tags_v6 = {
   ["host"]   = {
      "IPV6_DST_ADDR",
      "IPV6_SRC_ADDR",
   },
   ["protocol"] = {
      "L7_PROTO",
   }
}

historical_flow_utils.builtin_presets = {
   {
      id = "",
      count = nil,
      i18n_name = "queries.raw_flows_records",
      name = i18n("queries.raw_flows_records"),
   },
   {
      id = "raw_flows_bytes",
      count = "TOTAL_BYTES",
      i18n_name = "queries.raw_flows_bytes",
      name = i18n("queries.raw_flows_bytes"),
   },
   {
      id = "raw_flows_score",
      count = "SCORE",
      i18n_name = "queries.raw_flows_score",
      name = i18n("queries.raw_flows_score"),
   },
}

-- #####################################

function historical_flow_utils.get_flow_columns()
   return flow_columns
end

-- #####################################

function historical_flow_utils.get_extended_flow_columns()
   local extended_flow_columns = {}

   for k, v in pairs(flow_columns) do
      extended_flow_columns[k] = v
   end
   for k, v in pairs(additional_flow_columns) do
      extended_flow_columns[k] = v
   end

   return extended_flow_columns
end

-- #####################################

function historical_flow_utils.get_sortable_flow_columns()
   for k, v in pairs(flow_columns) do
      if not v.order then v.order = 0 end
   end
   return flow_columns
end

-- #####################################

function historical_flow_utils.get_tags()
   local columns = historical_flow_utils.get_flow_columns()
   local tags = tag_utils.defined_tags
   local flow_defined_tags = {}

   for _, v in pairs(columns) do
      if v.tag and tag_utils.defined_tags[v.tag] then
         local tag = tag_utils.defined_tags[v.tag]
         if not tag.hide then
            flow_defined_tags[v.tag] = tag_utils.defined_tags[v.tag]
         end
      end
   end

   -- Add extra tags
   flow_defined_tags["ip"] = tag_utils.defined_tags["ip"]
   flow_defined_tags["name"] = tag_utils.defined_tags["name"]
   flow_defined_tags["mac"] = tag_utils.defined_tags["mac"]
   flow_defined_tags["snmp_interface"] = tag_utils.defined_tags["snmp_interface"]
   flow_defined_tags["country"] = tag_utils.defined_tags["country"]
   flow_defined_tags["l7_error_id"] = tag_utils.defined_tags["l7_error_id"]
   flow_defined_tags["cli_location"] = tag_utils.defined_tags["cli_location"]
   flow_defined_tags["srv_location"] = tag_utils.defined_tags["srv_location"]
   flow_defined_tags["traffic_direction"] = tag_utils.defined_tags["traffic_direction"]
   flow_defined_tags["confidence"] = tag_utils.defined_tags["confidence"]

   return flow_defined_tags
end

-- #####################################

function historical_flow_utils.get_flow_columns_to_tags()
   local c2t = {}

   for k, v in pairs(flow_columns) do
      if v.tag then
         c2t[k] = v.tag
      end
   end

   return c2t 
end

-- #####################################

-- Return a table with a list of DB columns for each tag
-- Example:
-- { ["srv_ip"] = ["IPV4_DST_ADDR"], ["IPV6_DST_ADDR"], .. }
local function get_flow_tags_to_columns()
   local t2c = {}
   local c2t = historical_flow_utils.get_flow_columns_to_tags()

   for c, t in pairs(c2t) do
      if not t2c[t] then
         t2c[t] = {}
      end
      t2c[t][#t2c[t] + 1] = c
   end

   return t2c
end

-- Return DB select by tag
-- Example: 'srv_ip' -> "IPV4_DST_ADDR, IPV6_DST_ADDR"
function historical_flow_utils.get_flow_select_by_tag(tag)
   local tags_to_columns = get_flow_tags_to_columns()
   local s = ''

   ::next::
   if tags_to_columns[tag] then
      for _, column in ipairs(tags_to_columns[tag]) do
         if isEmptyString(s) then
            s = column
         else
            s = s .. ', ' .. column
         end
      end

      -- l7proto also includes l7proto_master
      if tag == 'l7proto' then
         tag = 'l7proto_master'
         goto next
      end
   end

   return s
end

-- Return DB column by tag
-- First or ip_version-based in case of multiple
-- nil in case of undefined tag
function historical_flow_utils.get_flow_column_by_tag(tag, ip_version)
   local tags_to_columns = get_flow_tags_to_columns()

   if tags_to_columns[tag] then
      if tag:ends('ip') and ip_version and ip_version == 6 then
         return tags_to_columns[tag][2]
      end

      return tags_to_columns[tag][1]
   end

   return nil
end

-- Return the javascript formatter for chart Y
function historical_flow_utils.get_js_chart_formatter(field)
   local db_columns = historical_flow_utils.get_flow_columns()

   if db_columns[field] and db_columns[field].js_chart_func then
      return db_columns[field].js_chart_func
   end

   return "formatValue" --default
end

------------------------------------------------------------------------
-- Functions to format records for the JS DataTable

-- #####################################

function historical_flow_utils.format_record(record, csv_format, formatted_record)
   local processed_record = {}
         
   ----------------------------------
   -- Need to do this in order to remove unnecessary frontend data
   if csv_format == true then
      processed_record = ""

      for _, value in pairs(record) do
         processed_record = string.format("%s%s|", processed_record, value)
      end

      processed_record = string.sub(processed_record, 1, -2)
   else
      local extended_flow_columns = historical_flow_utils.get_extended_flow_columns()

      dt_add_tstamp(record)
      dt_add_filter(record)

      ----------------------------------
      -- Cycling the value of the record
      for column_name, value in pairs(record) do
         local new_column_name = nil
         local new_value = nil

         -- Format the values and pass to the answer
         if extended_flow_columns[column_name] then
            new_column_name = extended_flow_columns[column_name]["tag"]
            new_value = extended_flow_columns[column_name]["dt_func"](value, record, column_name, formatted_record)
         end
         
         if new_column_name and new_value then
            processed_record[new_column_name] = new_value
         end
      end

      -- NB: Currently we need to add a dt_format_asn
      -- TODO: add this automatically
      dt_format_asn(processed_record, record)
      dt_add_alerts_url(processed_record, record)
      dt_format_flow(processed_record, record)
   end

   return processed_record 
end

-- #####################################

function historical_flow_utils.format_clickhouse_record(record, csv_format, formatted_record)
   local processed_record = {}

   ----------------------------------
   -- Need to do this in order to remove unnecessary frontend data

   if csv_format == true then
      processed_record = ""

      for _, value in pairs(record) do
         processed_record = string.format("%s%s|", processed_record, value)
      end

      processed_record = string.sub(processed_record, 1, -2)
   else
      local extended_flow_columns = historical_flow_utils.get_extended_flow_columns()

      dt_add_tstamp(record)
      dt_add_filter(record)

      ----------------------------------
      -- Cycling the value of the record
      for column_name, value in pairs(record) do
	 if do_trace == "1" then traceError(TRACE_NORMAL, TRACE_CONSOLE, column_name .. " start") end
         local new_column_name = nil
         local new_value = nil

      	 -- Format the values and pass to the answer
      	 if extended_flow_columns[column_name] and extended_flow_columns[column_name]["dt_func"] then
      	    new_column_name = extended_flow_columns[column_name]["tag"]
      	    new_value = extended_flow_columns[column_name]["dt_func"](value, record, column_name, formatted_record)
         else
            new_column_name = column_name
            new_value = value
      	 end

      	 if new_column_name and new_value then
            processed_record[new_column_name] = new_value
      	 end
	 if do_trace == "1" then traceError(TRACE_NORMAL, TRACE_CONSOLE, column_name .. " end") end
      end

      dt_format_asn(processed_record, record)
      dt_unify_l7_proto(processed_record)
      dt_add_alerts_url(processed_record, record)
      dt_format_flow(processed_record, record)
   end

   return processed_record
end

------------------------------------------------------------------------
-- JS DataTable columns

-- #####################################

local function build_datatable_js_column_default(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap'}]] 
   }
end

-- #####################################

local function build_datatable_js_column_number(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined)
          return NtopUtils.formatValue(]] .. name .. [[);
      }}]]
   }
end

-- #####################################

local function build_datatable_js_column_ip(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        let html_ref = '';
        let location = '';
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined) {
            if (]] .. name .. [[.reference !== undefined)
                html_ref = ]] .. name .. [[.reference;

            if (]] .. name .. [[.location)
               location = ]] .. name .. [[.location.label;

                
            return `<a class='tag-filter' data-tag-key='${]] .. name .. [[.tag_key}' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a> ${location} ${html_ref}`;
        }}}]] }
end

-- #####################################

local function build_datatable_js_column_port(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
          if (type !== 'display') return ]] .. name .. [[;
          if (]] .. name .. [[ !== undefined)
             return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' href='#'>${]] .. name .. [[.label}</a>`;
      }}]] 
   }
end

-- #####################################

local function build_datatable_js_column_flow(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', orderable: false, className: 'text-nowrap', width: '100%', render: DataTableRenders.formatFlowTuple, createdCell: DataTableRenders.applyCellStyle}]] 
   }

end

-- #####################################

local function build_datatable_js_column_nw_latency(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
          if (type !== 'display') return ]] .. name .. [[;
          if (]] .. name .. [[ !== undefined)
             return `<a class='tag-filter' data-tag-value='${]] .. name .. [[}' href='#'>${NtopUtils.msecToTime(]] .. name .. [[)}</a>`;
      }}]] 
   }
end

-- #####################################

local function build_datatable_js_column_asn(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined && ]] .. name .. [[.value != 0)
          return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
        return ''}}]] }
end

-- #####################################

local function build_datatable_js_column_snmp_interface(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined && ]] .. name .. [[.value != 0)
          return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
        return ''}}]] }
end

-- #####################################

local function build_datatable_js_column_network(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined) {
          return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
      }}}]] }
end

-- #####################################

local function build_datatable_js_column_pool_id(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined) {
          return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
      }}}]] }
end

-- #####################################

local function build_datatable_js_column_country(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined) {
          return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
      }}}]] }
end

-- #####################################

local function build_datatable_js_column_packets(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined)
          return NtopUtils.formatPackets(]] .. name .. [[);
      }}]]
   }
end

-- #####################################

local function build_datatable_js_column_bytes(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap'}]] 
   }
end

-- #####################################

local function build_datatable_js_column_tcp_flags(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
        {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
          if (type !== 'display') return ]] .. name .. [[;
          if (]] .. name .. [[ !== undefined)
            return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
        }}]] }
end

-- #####################################

local function build_datatable_js_column_dscp(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
        {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. data_name .. [[', className: 'no-wrap', render: (]] .. name .. [[, type) => {
            if (type !== 'display') return ]] .. name .. [[;
            if (]] .. name .. [[ !== undefined)
               return `<a class='tag-filter' data-tag-value='${]] .. name .. [[.value}' title='${]] .. name .. [[.title}' href='#'>${]] .. name .. [[.label}</a>`;
        }}]] }
end

-- #####################################

local function build_datatable_js_column_float(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. name .. [[', className: 'text-right', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined)
          return (]] .. name .. [[ > 0) ? NtopUtils.ffloat(]] .. name .. [[) : "";
      }}]] }
end

-- #####################################

local function build_datatable_js_column_msec(name, data_name, label, order, hide)
   return {
      i18n = label,
      order = order,
      visible_by_default = not hide,
      js = [[
      {name: ']] .. name .. [[', responsivePriority: 2, data: ']] .. name .. [[', className: 'text-right', render: (]] .. name .. [[, type) => {
        if (type !== 'display') return ]] .. name .. [[;
        if (]] .. name .. [[ !== undefined)
          return (]] .. name .. [[ > 0) ? NtopUtils.msecToTime(]] .. name .. [[) : "";
      }}]] }
end

-- #####################################

historical_flow_utils.datatable_js_column_builder_by_type = {
   ['default'] = build_datatable_js_column_default,
   ['number'] = build_datatable_js_column_number,
   ['ip'] = build_datatable_js_column_ip,
   ['port'] = build_datatable_js_column_port,
   ['asn'] = build_datatable_js_column_asn,
   ['tcp_flags'] = build_datatable_js_column_tcp_flags,
   ['dscp'] = build_datatable_js_column_dscp,
   ['packets'] = build_datatable_js_column_packets,
   ['bytes'] = build_datatable_js_column_bytes,
   ['float'] = build_datatable_js_column_float,
   ['msec'] = build_datatable_js_column_msec,
   ['network'] = build_datatable_js_column_network,
   ['pool_id'] = build_datatable_js_column_pool_id,
   ['country'] = build_datatable_js_column_country,
   ['snmp_interface'] = build_datatable_js_column_snmp_interface,
}

-- #####################################

local all_datatable_js_columns_by_tag = {
   ["flow"] = build_datatable_js_column_flow("flow", "flow", i18n("flow"), 0),
   ['vlan_id'] = {
      i18n = i18n("db_search.vlan_id"),
      order = 1,
      visible_by_default = interface.hasVLANs(),
      js = [[
        {name: 'vlan_id', responsivePriority: 2, data: 'vlan_id', visible: ]] ..ternary(interface.hasVLANs(), "true", "false").. [[, className: 'no-wrap', render: (vlan_id, type) => {
            if (type !== 'display') 
                return vlan_id;
            if (vlan_id !== undefined)
                return `<a class='tag-filter' data-tag-value='${vlan_id.value}' title='${vlan_id.title}' href='#'>${vlan_id.label}</a>`;
        }}]] },
   ['cli_ip'] = build_datatable_js_column_ip('cli_ip', 'cli_ip', i18n("db_search.client"), 2),
   ['srv_ip'] = build_datatable_js_column_ip('srv_ip', 'srv_ip', i18n("db_search.server"), 3),
   ['cli_port'] = build_datatable_js_column_port('cli_port', 'cli_port', i18n("db_search.cli_port"), 4),
   ['srv_port'] = build_datatable_js_column_port('srv_port', 'srv_port', i18n("db_search.srv_port"), 5),
   ['l4proto'] = {
      i18n = i18n("db_search.l4proto"),
      order = 6,
      visible_by_default = true,
      js = [[
      {name: 'l4proto', responsivePriority: 2, data: 'l4proto', className: 'no-wrap', render: (l4proto, type) => {
        if (type !== 'display') return l4proto;
        if (l4proto !== undefined)
           return `<a class='tag-filter' data-tag-value='${l4proto.label}' data-tag-realvalue='${l4proto.value}' title='${l4proto.title}' href='#'>${l4proto.label}</a>`;
      }}]] },
   ['l7proto'] = {
      i18n = i18n("db_search.l7proto"),
      order = 7,
      visible_by_default = true,
      js = [[
      {name: 'l7proto', responsivePriority: 2, data: 'l7proto', className: 'no-wrap', render: (proto, type, row) => {
        if (type !== 'display') return proto;
        if (proto !== undefined) {
          let confidence = ""
          if (proto.confidence !== undefined) {
            (proto.confidence == "DPI") ? confidence = `<span class="badge bg-success">${proto.confidence}</span>` : confidence = `<span class="badge bg-warning">${proto.confidence}</span>` 
          }

           return `<a class='tag-filter' data-tag-value='${proto.value}' title='${proto.title}' href='#'>${proto.label} ${confidence}</a>`;
        }
      }}]] },
   ['score'] = {
      i18n = i18n("score"),
      order = 8,
      visible_by_default = true,
      js = [[
      {name: 'score', responsivePriority: 2, data: 'score', className: 'text-center', render: (score, type) => {
        if (type !== 'display') return score;
        if (score !== undefined && score.value != 0)
          return `<a class='tag-filter' data-tag-value='${score.value}' href='#'><span style='color: ${score.color}'>` + NtopUtils.fint(score.value) + `</span></a>`;
      }}]] },
   ['packets'] = build_datatable_js_column_packets('packets', 'packets', i18n("db_search.packets"), 9, true),
   ['bytes'] = build_datatable_js_column_bytes('bytes', 'bytes', i18n("db_search.bytes"), 10),
   ['throughput'] = {
      i18n = i18n("db_search.throughput"),
      order = 11,
      visible_by_default = true,
      js = [[
      {name: 'throughput', responsivePriority: 2, data: 'throughput', className: 'no-wrap'}]] },
   ['first_seen'] = {
      i18n = i18n("db_search.first_seen"),
      order = 12,
      visible_by_default = true,
      js = [[
      {name: 'first_seen', responsivePriority: 2, data: 'first_seen', className: 'no-wrap'}]] },
   ['last_seen'] = {
      i18n = i18n("db_search.last_seen"),
      order = 13,
      visible_by_default = true,
      js = [[
      {name: 'last_seen', responsivePriority: 2, data: 'last_seen', className: 'no-wrap'}]] },
   ['cli_asn'] = build_datatable_js_column_asn('cli_asn', 'cli_asn', i18n("db_search.cli_asn"), 14, true),
   ['srv_asn'] = build_datatable_js_column_asn('srv_asn', 'srv_asn', i18n("db_search.srv_asn"), 15, true),
   ['l7cat'] = {
      i18n = i18n("db_search.l7cat"),
      order = 16,
      visible_by_default = true,
      js = [[
      {name: 'l7cat', responsivePriority: 2, data: 'l7cat', className: 'no-wrap', render: (l7cat, type) => {
        if (type !== 'display') return l7cat;
        if (l7cat !== undefined) {
           const label = (l7cat.label || l7cat.value);
           const value = l7cat.value;
           return `<a class='tag-filter' data-tag-value='${value}' title='${l7cat.title}' href='#'>${label}</a>`;
        }
      }}]] },
   ['alert_id'] = {
      i18n = i18n("db_search.alert_id"),
      order = 17,
      visible_by_default = true,
      js = [[
      {name: 'alert_id', responsivePriority: 2, data: 'alert_id', className: 'no-wrap', render: (alert_id, type) => {
        if (type !== 'display') return alert_id;
        if (alert_id !== undefined)
           return `<a class='tag-filter' data-tag-value='${alert_id.value}' title='${alert_id.title}' href='#'>${alert_id.label}</a>`;
      }}]] },
   ['flow_risk'] = {
      i18n = i18n("db_search.flow_risk"),
      order = 18,
      visible_by_default = true,
      js = [[
      {name: 'flow_risk', responsivePriority: 2, data: 'flow_risk', className: 'no-wrap', render: (flow_risks, type) => {
        if (type !== 'display') return flow_risks;
        if (flow_risks !== undefined) {
           let res = [];

           for (let i = 0; i < flow_risks.length; i++) {
             const flow_risk = flow_risks[i];
             const flow_risk_label = (flow_risk.label || flow_risk.value);
             const flow_risk_help = (flow_risk.help);
             // res.push(`<a class='tag-filter' data-tag-value='${flow_risk.value}' title='${flow_risk.title}' href='#'>${flow_risk_label}</a>`);
             res.push(`${flow_risk_label} ${flow_risk_help}`);
           }
           return res.join(', ');
        }
      }}]] },
   ['src2dst_tcp_flags'] = build_datatable_js_column_tcp_flags('src2dst_tcp_flags', 'src2dst_tcp_flags', i18n("db_search.src2dst_tcp_flags"), 19, true),
   ['dst2src_tcp_flags'] = build_datatable_js_column_tcp_flags('dst2src_tcp_flags', 'dst2src_tcp_flags', i18n("db_search.dst2src_tcp_flags"), 20, true),
   ['src2dst_dscp'] = build_datatable_js_column_dscp('src2dst_dscp', 'src2dst_dscp', i18n("db_search.src2dst_dscp"), 21, true),
   ['dst2src_dscp'] = build_datatable_js_column_dscp('dst2src_dscp', 'dst2src_dscp', i18n("db_search.dst2src_dscp"), 22, true),
   ['cli_nw_latency'] = build_datatable_js_column_nw_latency('cli_nw_latency', 'cli_nw_latency', i18n("db_search.cli_nw_latency"), 23, true),
   ['srv_nw_latency'] = build_datatable_js_column_nw_latency('srv_nw_latency', 'srv_nw_latency', i18n("db_search.srv_nw_latency"), 24, true),
   ['info'] = {
      i18n = i18n("db_search.info"),
      order = 25,
      visible_by_default = true,
      js = [[
        {name: 'info', responsivePriority: 2, data: 'info', orderable: true, render: (info, type) => {
            if (type !== 'display') return info;
            if (info !== undefined)
                return `<a class='tag-filter' data-tag-value='${info.title}' title='${info.title}' href='#'>${info.label}</a>`;
        }}]] },
   ['observation_point_id'] = {
      i18n = i18n("db_search.observation_point_id"),
      order = 26,
      visible_by_default = false,
      js = [[
        {name: 'observation_point_id', responsivePriority: 2, data: 'observation_point_id', visible: ]] ..ternary(not interface.isPacketInterface(), "true", "false").. [[, className: 'no-wrap', render: (observation_point_id, type) => {
            if (type !== 'display') return observation_point_id;
            if (observation_point_id !== undefined)
               return `<a class='tag-filter' data-tag-value='${observation_point_id.value}' title='${observation_point_id.title}' href='#'>${observation_point_id.label}</a>`;
        }}]] },
   ['probe_ip'] = {
      i18n = i18n("db_search.probe_ip"),
      order = 27,
      visible_by_default = false,
      js = [[
        {name: 'probe_ip', responsivePriority: 2, data: 'probe_ip', className: 'no-wrap', render: (probe_ip, type) => {
            if (type !== 'display') return probe_ip;
            if (probe_ip !== undefined && probe_ip.label !== "") {
              return `<a class='tag-filter' data-tag-value='${probe_ip.value}' title='${probe_ip.title}' href='#'>${probe_ip.label}</a>`;
            }
            return ''
        }}]] },
   ['cli_network'] = build_datatable_js_column_network('cli_network', 'cli_network', i18n("db_search.tags.cli_network"), 28, true),
   ['srv_network'] = build_datatable_js_column_network('srv_network', 'srv_network', i18n("db_search.tags.srv_network"), 29, true),
   ['cli_host_pool_id'] = build_datatable_js_column_pool_id('cli_host_pool_id', 'cli_host_pool_id', i18n("db_search.tags.cli_host_pool_id"), 30, true),
   ['srv_host_pool_id'] = build_datatable_js_column_pool_id('srv_host_pool_id', 'srv_host_pool_id', i18n("db_search.tags.srv_host_pool_id"), 31, true),
   ["input_snmp"] = build_datatable_js_column_snmp_interface("input_snmp", "input_snmp", i18n("db_search.tags.input_snmp"), 32),
   ["output_snmp"] = build_datatable_js_column_snmp_interface("output_snmp", "output_snmp", i18n("db_search.tags.output_snmp"), 33),
   ['cli_country'] = build_datatable_js_column_country('cli_country', 'cli_country', i18n("db_search.tags.cli_country"), 34, true),
   ['srv_country'] = build_datatable_js_column_country('srv_country', 'srv_country', i18n("db_search.tags.srv_country"), 35, true),
}

-- #####################################

function historical_flow_utils.get_datatable_js_columns_by_tag(tag, hide)
   if all_datatable_js_columns_by_tag[tag] then
      return all_datatable_js_columns_by_tag[tag]
   else
      local order = #all_datatable_js_columns_by_tag
      return build_datatable_js_column_default(tag, tag, i18n("db_search.tags."..tag) or tag, order, hide)
   end
end

-- #####################################

local function get_js_columns_to_display()
   -- Display selected columns in the flows table
   local js_columns = {}

   js_columns["flow"]       = build_datatable_js_column_flow("flow", "flow", i18n("flow"), 0)
   js_columns["l4proto"]    = historical_flow_utils.get_datatable_js_columns_by_tag("l4proto")
   js_columns["l7proto"]    = historical_flow_utils.get_datatable_js_columns_by_tag("l7proto")
   js_columns["score"]      = historical_flow_utils.get_datatable_js_columns_by_tag("score")
   js_columns["packets"]    = historical_flow_utils.get_datatable_js_columns_by_tag("packets")
   js_columns["bytes"]      = historical_flow_utils.get_datatable_js_columns_by_tag("bytes")
   js_columns["throughput"] = historical_flow_utils.get_datatable_js_columns_by_tag("throughput")
   js_columns["first_seen"] = historical_flow_utils.get_datatable_js_columns_by_tag("first_seen")
   js_columns["last_seen"]  = historical_flow_utils.get_datatable_js_columns_by_tag("last_seen")
   js_columns["l7cat"]      = historical_flow_utils.get_datatable_js_columns_by_tag("l7cat")
   js_columns["alert_id"]     = historical_flow_utils.get_datatable_js_columns_by_tag("alert_id")
   js_columns["flow_risk"]  = historical_flow_utils.get_datatable_js_columns_by_tag("flow_risk")
   js_columns["info"]       = historical_flow_utils.get_datatable_js_columns_by_tag("info")
   js_columns["cli_asn"]    = historical_flow_utils.get_datatable_js_columns_by_tag("cli_asn")
   js_columns["srv_asn"]    = historical_flow_utils.get_datatable_js_columns_by_tag("srv_asn")
   js_columns["src2dst_tcp_flags"] = historical_flow_utils.get_datatable_js_columns_by_tag("src2dst_tcp_flags")
   js_columns["dst2src_tcp_flags"] = historical_flow_utils.get_datatable_js_columns_by_tag("dst2src_tcp_flags")
   js_columns["cli_nw_latency"] = historical_flow_utils.get_datatable_js_columns_by_tag("cli_nw_latency")
   js_columns["srv_nw_latency"] = historical_flow_utils.get_datatable_js_columns_by_tag("srv_nw_latency")
   js_columns["observation_point_id"] = historical_flow_utils.get_datatable_js_columns_by_tag("observation_point_id")
   js_columns["probe_ip"]   = historical_flow_utils.get_datatable_js_columns_by_tag("probe_ip")
   js_columns["cli_network"] = historical_flow_utils.get_datatable_js_columns_by_tag("cli_network")
   js_columns["srv_network"] = historical_flow_utils.get_datatable_js_columns_by_tag("srv_network")
   js_columns["cli_host_pool_id"] = historical_flow_utils.get_datatable_js_columns_by_tag("cli_host_pool_id")
   js_columns["srv_host_pool_id"] = historical_flow_utils.get_datatable_js_columns_by_tag("srv_host_pool_id")
   js_columns["cli_country"] = historical_flow_utils.get_datatable_js_columns_by_tag("cli_country")
   js_columns["srv_country"] = historical_flow_utils.get_datatable_js_columns_by_tag("srv_country")
   js_columns["input_snmp"]  = historical_flow_utils.get_datatable_js_columns_by_tag("input_snmp")
   js_columns["output_snmp"] = historical_flow_utils.get_datatable_js_columns_by_tag("output_snmp")

   local ifstats = interface.getStats()
   if ifstats.has_seen_ebpf_events then
      js_columns["cli_proc_name"] = historical_flow_utils.get_datatable_js_columns_by_tag("cli_proc_name")
      js_columns["srv_proc_name"] = historical_flow_utils.get_datatable_js_columns_by_tag("srv_proc_name")
      js_columns["cli_user_name"] = historical_flow_utils.get_datatable_js_columns_by_tag("cli_user_name")
      js_columns["srv_user_name"] = historical_flow_utils.get_datatable_js_columns_by_tag("srv_user_name")
   end

   return js_columns

   -- Or print all columns defined
   --return all_datatable_js_columns_by_tag
end

-- #####################################

local function order_asc(a, b)
   return asc(a.order, b.order)
end

-- #####################################

function historical_flow_utils.get_datatable_js_columns() 
   local str = "["

   local js_columns = get_js_columns_to_display()
   for _, column in pairsByValues(js_columns, order_asc) do
      str = str .. column.js .. ","
   end
   str = str:sub(1, -2)
   str = str .. "]"

   return str
end

function historical_flow_utils.get_datatable_default_hidden_columns()
   local hidden_columns = ""
   
   local js_columns = get_js_columns_to_display()
   local idx = 0
   for name, column in pairsByValues(js_columns, order_asc) do
      if not column.visible_by_default then
         hidden_columns = hidden_columns .. idx .. ","
      end
      idx = idx + 1
   end

   if not isEmptyString(hidden_columns) then
      hidden_columns = hidden_columns:sub(1, -2)
   end

   return hidden_columns
end

function historical_flow_utils.get_datatable_i18n_columns() 
   local columns = {}

   local js_columns = get_js_columns_to_display()
   for _, column in pairsByValues(js_columns, order_asc) do
      columns[#columns + 1] = column.i18n
   end

   return columns
end

-- #####################################

function historical_flow_utils.get_historical_url(label, tag, value, add_hyperlink, title)
   if not add_hyperlink then 
      return label
   else
      return "<a href=\"" .. ntop.getHttpPrefix() .. "/lua/pro/db_search.lua?" .. 
         tag .. "=" .. value .. tag_utils.SEPARATOR .. "eq\" " .. 
         ternary(title ~= nil, "title=\"" .. (title or "") .."\"", "") .. 
         " target='_blank'>" .. label .. "</a>"
   end
end

-- #####################################

function historical_flow_utils.getHistoricalFlowLabel(record, add_hyperlinks, add_hostnames, add_country_flags)
   local label = ""
   local vlan = ""

   local info = historical_flow_utils.format_clickhouse_record(record)

   if not info.cli_ip or not info.srv_ip then
      return label
   end

   -- add_hostnames ~= nil, added to be compatible with older calls to this function
   if (add_hostnames == nil) or (add_hostnames == true)  then
      label = label ..historical_flow_utils.get_historical_url(info.cli_ip.label, ternary(info.cli_ip.label ~= info.cli_ip.ip, "cli_name", "cli_ip"), info.cli_ip.label, add_hyperlinks, ternary(info.cli_ip.label ~= info.cli_ip.ip, info.cli_ip.ip, nil))
   else
      label = label ..historical_flow_utils.get_historical_url(info.cli_ip.ip, "cli_ip", info.cli_ip.ip, add_hyperlinks, nil)  
   end

   if (info.vlan_id) and (info.vlan_id.value ~= 0) then
      vlan = historical_flow_utils.get_historical_url(info.vlan_id.label, "vlan_id", info.vlan_id.value, add_hyperlinks, nil) 
      label = format_ip_vlan(label, vlan)
   end

   if info.cli_country and not isEmptyString(info.cli_country.value) then
    label = label .. ' <img src="' .. ntop.getHttpPrefix() .. '/dist/images/blank.gif" class="flag flag-' .. string.lower(info.cli_country.value) .. '">'
   end

   if add_hyperlinks and info.cli_location and not isEmptyString(info.cli_location.label) then
      label = label .. " " .. format_location_badge(info.cli_location.label)
   end

   if info.cli_port and not isEmptyString(info.cli_port.label) then
      label = label .. ":" ..historical_flow_utils.get_historical_url(info.cli_port.label, "cli_port", info.cli_port.value, add_hyperlinks)
   end

   if info.IS_CLI_ATTACKER and info.IS_CLI_ATTACKER == '1' then
    label = label .. ' <i class="fas fa-skull" title="' .. i18n('db_explorer.is_attacker') .. '"></i> '
   end
   
   if info.IS_CLI_VICTIM and info.IS_CLI_VICTM == '1' then
    label = label .. ' <i class="fas fa-sad-tear" title="' .. i18n('db_explorer.is_victim') .. '"></i> '
   end
   
   if info.IS_CLI_BLACKLISTED and info.IS_CLI_BLACKLISTED == '1' then
    label = label .. ' <i class="fas fa-ban fa-sm" title="' .. i18n('db_explorer.is_blacklisted') .. '"></i> '
   end
   
   if add_hyperlinks then
      if info.cli_asn and info.cli_asn.value > 0 and not isEmptyString(info.cli_asn.title) then
         label = label .. " [ " ..historical_flow_utils.get_historical_url(info.cli_asn.title, "cli_asn", info.cli_asn.value, add_hyperlinks) .. " ]"
      elseif not isEmptyString(info.cli_mac) and (info.cli_mac ~= '00:00:00:00:00:00') then
         label = label .. " [ " .. info. cli_mac .. " ]"
      end
   end
   
   label = label .. "&nbsp; <i class=\"fas fa-exchange-alt fa-lg\"  aria-hidden=\"true\"></i> &nbsp;"

   if (add_hostnames == nil) or (add_hostnames == true)  then
    label = label ..historical_flow_utils.get_historical_url(info.srv_ip.label, ternary(info.srv_ip.label ~= info.srv_ip.ip, "srv_name", "srv_ip"), info.srv_ip.label, add_hyperlinks, ternary(info.srv_ip.label ~= info.srv_ip.ip, info.srv_ip.ip, nil))
   else
    label = label ..historical_flow_utils.get_historical_url(info.srv_ip.ip, "srv_ip", info.srv_ip.ip, add_hyperlinks, nil)  
   end

   if not isEmptyString(vlan) then
      label = format_ip_vlan(label, vlan)  
   end

   if info.srv_country and not isEmptyString(info.srv_country.value) then
    label = label .. ' <img src="' .. ntop.getHttpPrefix() .. '/dist/images/blank.gif" class="flag flag-' .. string.lower(info.srv_country.value) .. '">'
   end

   if add_hyperlinks and info.srv_location and not isEmptyString(info.srv_location.label) then
      label = label .. " " .. format_location_badge(info.srv_location.label)
   end

   if info.srv_port and not isEmptyString(info.srv_port.label) then
      label = label .. ":" ..historical_flow_utils.get_historical_url(info.srv_port.label, "srv_port", info.srv_port.value, add_hyperlinks)
   end

   if info.IS_SRV_ATTACKER and info.IS_SRV_ATTACKER == '1' then
    label = label .. ' <i class="fas fa-skull" title="' .. i18n('db_explorer.is_attacker') .. '"></i> '
   end
   
   if info.IS_SRV_VICTIM and info.IS_SRV_VICTIM == '1' then
    label = label .. ' <i class="fas fa-sad-tear" title="' .. i18n('db_explorer.is_victim') .. '"></i> '
   end
   
   if info.IS_SRV_BLACKLISTED and info.IS_SRV_BLACKLISTED == '1' then
    label = label .. ' <i class="fas fa-ban fa-sm" title="' .. i18n('db_explorer.is_blacklisted') .. '"></i> '
   end

   if add_hyperlinks then
      if info.srv_asn and info.srv_asn.value > 0 and not isEmptyString(info.srv_asn.title) then
         label = label .. " [ " ..historical_flow_utils.get_historical_url(info.srv_asn.title, "srv_asn", info.srv_asn.value, add_hyperlinks) .. " ]"
      elseif not isEmptyString(info.srv_mac) and (info.srv_mac ~= '00:00:00:00:00:00') then
         label = label .. " [ " .. info. srv_mac .. " ]"
      end
   end

   return label
end

-- #####################################

function historical_flow_utils.getHistoricalProtocolLabel(record, add_hyperlinks)
  local json = require "dkjson"
  local label = ""

  local info = historical_flow_utils.format_clickhouse_record(record)
  local alert_json = json.decode(info["ALERT_JSON"] or '') or {}
  
  if info.l4proto then
    label = label ..historical_flow_utils.get_historical_url(info.l4proto.label, "l4proto", info.l4proto.value, add_hyperlinks)
  end

  label = label .. " / "

  if info.l7proto then
    label = label ..historical_flow_utils.get_historical_url(info.l7proto.label, "l7proto", info.l7proto.value, add_hyperlinks)
  end

  if info.l7cat then
    label = label .. " (" ..historical_flow_utils.get_historical_url(info.l7cat.label, "l7cat", info.l7cat.value, add_hyperlinks) .. ")"
  end

  if (alert_json.proto) and (alert_json.proto.confidence) and (not isEmptyString(alert_json.proto.confidence)) then
    label = label .. " [" .. i18n("confidence") .. ": " .. get_confidence(alert_json.proto.confidence) .. "]"
  end

  return label
end

-- #####################################

function historical_flow_utils.simpleColumnFormatter(records, label)
   local extended_flow_columns = historical_flow_utils.get_extended_flow_columns()
   local process_records = records["results"] or {}
   local extended_flow_columns = historical_flow_utils.get_extended_flow_columns()

   -- Cycling the value of the record
   for _, record in pairs(process_records) do
      for column_name, value in pairs(record) do
         if label and label == column_name then
            local formatted_label
            
            col_data = extended_flow_columns[column_name]
            
            if (col_data) and (col_data["simple_dt_func"]) then
               formatted_label = col_data["simple_dt_func"](tonumber(value) or value, record)
            end

            if formatted_label then
               record["label"] = formatted_label
            end
         end
      end
   end

   return records
end

-- #####################################

function historical_flow_utils.getSimpleColumnFormatter(label, data)
   local extended_flow_columns = historical_flow_utils.get_extended_flow_columns()

   if label then      
      col_data = extended_flow_columns[label]
      
      if (col_data) and (col_data["simple_dt_func"]) then
         return col_data["simple_dt_func"](tonumber(data) or data)
      end
   end

   return data
end

return historical_flow_utils

