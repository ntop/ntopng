--
-- (C) 2013-24 - ntop.org
--

local tag_utils = require "tag_utils"
local dscp_consts = require "dscp_consts"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local flow_risk_utils = require "flow_risk_utils"
local country_codes = require "country_codes"

local historical_flow_utils = {}

------------------------------------------------------------------------
-- Utility Functions

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

-- #####################################

function historical_flow_utils.get_selected_filters(ifid)
   local selected_filters = tag_utils.get_tag_filters_from_request()

   if ifid == nil then
      ifid = interface.getId()
   end
   selected_filters['ifid'] = ifid

   -- Exception parsing
   if not isEmptyString(selected_filters['cli_asn']) then
      selected_filters['cli_asn'] = historical_flow_utils.parse_asn(selected_filters["cli_asn"])
   end
   if not isEmptyString(selected_filters['srv_asn']) then
      selected_filters['srv_asn'] = historical_flow_utils.parse_asn(selected_filters["srv_asn"])
   end
   if not isEmptyString(selected_filters['l7cat']) then
      selected_filters['l7cat'] = historical_flow_utils.parse_l7_cat(selected_filters["l7cat"])
   end

   return selected_filters
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
      label = info
   })
end

-- #####################################

local function dt_format_l4_proto(proto)
   local title = l4_proto_to_string(tonumber(proto))
   local l4_proto = {
      title = title,
      label = title,
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
      vlan["title"] = getFullVlanName(vlan_id, false)
      vlan["label"] = getFullVlanName(vlan_id, false)
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
   local location_tag_value = ''

   if(location == "0") then -- Remote 
      location_tag_value = 'remote'
   elseif(location == "1") then -- Local
      location_tag_value = 'local'
   elseif(location == "2") then -- Multicast
      location_tag_value = 'multicast'
   end
   
   return location_tag_value
end

-- #####################################

local function dt_format_ip_common(ip, name, location, prefix, record)
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

local function dt_format_ip(ip, record, column_name)
   if column_name == 'IPV4_ADDR' and (
      (record['IP_PROTOCOL_VERSION'] and record['IP_PROTOCOL_VERSION'] ~= '4') or 
      (record['IP_PROTOCOL_VERSION'] == nil and ip == '0.0.0.0')) 
      then return nil end
   if column_name == 'IPV6_ADDR' and (
      (record['IP_PROTOCOL_VERSION'] and record['IP_PROTOCOL_VERSION'] ~= '6') or 
      (record['IP_PROTOCOL_VERSION'] == nil and ip == '::')) 
      then return nil end

   return dt_format_ip_common(ip, record["HOST_LABEL"] or "", record["SERVER_LOCATION"], "srv", record)
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

   return dt_format_ip_common(ip, record["DST_LABEL"] or "", record["SERVER_LOCATION"], "srv", record)
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

   return dt_format_ip_common(ip, record["SRC_LABEL"] or "", record["CLIENT_LOCATION"], "cli", record)
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
      label = title or "",
      value = tonumber(dscp_id),
   })
end

-- #####################################

local function dt_format_high_number(value)
   return formatValue(value)
end

-- #####################################

local function dt_format_l7_proto(l7_proto, record)
  
   if not isEmptyString(l7_proto) then
      local title = interface.getnDPIProtoName(tonumber(l7_proto))
      local confidence = format_confidence_from_json(record)

      l7_proto = {
         confidence = confidence,
         title = title,
         label = title,
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

local function dt_format_duration(time)
   time = tonumber(time)
   if time <= 0 then
      time = 1
   end
   return secondsToTime(time)
end

-- #####################################

local function dt_format_time_with_highlight(time, record)
   if (time) and (tonumber(time)) then
      time = format_utils.formatPastEpochShort(time)
   end

   local severity_id = map_score_to_severity(tonumber(record["SCORE"]) or 0)
   local severity = alert_consts.alertSeverityById(severity_id)

   return {
      time = time,
      highlight = severity.color,
   }
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

local function dt_format_asn_common(ip, asn)
   local asn_obj = {
      title = "",
      label = "No ASN",
      value = 0
   }

   if asn ~= "0" then
      asn_obj["value"] = tonumber(asn)
      asn_obj["label"] = asn_obj["value"]
      local as_name = nil
      if ip then
         as_name = ntop.getASName(ip)
         asn_obj["label"] = asn_obj["label"].. " (" .. (as_name or "") .. ")"
      end
      asn_obj["title"] = as_name or asn_obj["value"]
   end

   return asn_obj
end

-- #####################################

local function dt_format_asn(processed_record, record)

   -- Client
   if not isEmptyString(record["SRC_ASN"]) then
      local ip
      if processed_record["cli_ip"] and processed_record["cli_ip"]["ip"] then
         ip = processed_record["cli_ip"]["ip"]
      end
      processed_record["cli_asn"] = dt_format_asn_common(ip, record["SRC_ASN"])
   end
   
   -- Server
   if not isEmptyString(record["DST_ASN"]) then
      local ip
      if processed_record["srv_ip"] and processed_record["srv_ip"]["ip"] then
         ip = processed_record["srv_ip"]["ip"]
      end
      processed_record["srv_asn"] = dt_format_asn_common(ip, record["DST_ASN"])
   end

   -- Any (from queries)
   if not isEmptyString(record["ASN"]) then
      local ip
      if processed_record["ip"] and processed_record["ip"]["ip"] then
         ip = processed_record["ip"]["ip"]
      end
      processed_record["asn"] = dt_format_asn_common(ip, record["ASN"])
   end
end

-- #####################################

local function dt_format_flow_risk(flow_risk_id)
   local flow_risks = {}
   
   -- Get alert risk source
   --[[
      local alert_src = ""
      local alert_risk = ntop.getFlowAlertRisk(tonumber(flow_risk_id))
      tprint("flow_risk_id:" .. tostring(flow_risk_id))
      tprint("alert_risk_id:" .. tostring(alert_risk))
      tprint("-------")
      
      if (tonumber(alert_risk) == 0) then 
         alert_src = "ntopng"
      else
         alert_src = "nDPI"
      end
      ]]

   for i = 1, 63 do
      local cur_risk = (tonumber(flow_risk_id) >> i) & 0x1

      if cur_risk > 0 then
	 local cur_risk_id = i
         local title = ntop.getRiskStr(cur_risk_id)

	 local flow_risk = {
	    title = title,
	    label = title,
	    value = cur_risk_id,
            help  = flow_risk_utils.get_documentation_link(cur_risk_id, ""),
            remediation = flow_risk_utils.get_remediation_documentation_link(cur_risk_id, "")
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
      record_status["label"] = stats_str
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
      local title = getCategoryLabel(interface.getnDPICategoryName(tonumber(l7_category)), tonumber(l7_category))
      
      formatted_cat["title"] = title
      formatted_cat["label"] = title
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

local function dt_format_connection_state(id, major)
   local i18n_conn_states = "flow_fields_description.minor_connection_states"
   local name = ""
   if (major) then
      i18n_conn_states = "flow_fields_description.major_connection_states"
      name = ternary(tonumber(id) == 0, "", i18n(string.format("%s.%u",i18n_conn_states,id)))
   else 
      name = ternary(tonumber(id) == 0, "", i18n(string.format("%s.%u",i18n_conn_states,id)) .. " - " .. i18n(string.format("%s.%u","flow_fields_description.minor_connection_states_info",id))) 
   end
    
   
   local conn_state_tag = {
      value = id,
      label = name,
      title = name
   }
   return conn_state_tag
end

local function dt_format_major_connection_state(id)
   return dt_format_connection_state(id, true --[[ major ]])
end

local function dt_format_minor_connection_state(id)
   return dt_format_connection_state(id, false --[[ is minor ]])
end

local function dt_format_port(value)
   local label = value
   if value == '0' then
      label = ''
   end
   return {
      value = label,
      label = label,
      title = label
   }
end

local function dt_format_nat_ip(value)
   local label = value
   if value == '0.0.0.0' then
      label = ''
   end
   return {
      value = label,
      label = label,
      title = label
   }
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
    label = format_portidx_name(exporter, tostring(interface), false, false)
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

local function simple_format_ip(value, record)
   if not isEmptyString(record["HOST_LABEL"]) then
      record["label"] = record["HOST_LABEL"]
   end
end

-- #####################################

local function simple_format_src_ip(value, record)
   if not isEmptyString(record["SRC_LABEL"]) then
      record["label"] = record["SRC_LABEL"]
   end
end

-- #####################################

local function simple_format_dst_ip(value, record)
   if not isEmptyString(record["DST_LABEL"]) then
      record["label"] = record["DST_LABEL"]
   end
end

-- #####################################

local function simple_format_asn(value, record)
   local ip = record["IPV4_ADDR"] or record["IPV6_ADDR"]

   if not isEmptyString(ip) then
      if tonumber(value) == 0 then 
         record["label"] = "No ASN"
      else
         record["label"] = ntop.getASName(ip)
      end
   end
end

-- #####################################

local function simple_format_src_asn(value, record)
   local ip = record["IPV4_SRC_ADDR"] or record["IPV6_SRC_ADDR"]

   if not isEmptyString(ip) then
      if tonumber(value) == 0 then 
         record["label"] = "No ASN"
      else
         record["label"] = ntop.getASName(ip)
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
         record["label"] = ntop.getASName(ip)
      end
   end
end

-- #####################################

local function dt_add_alerts_url(processed_record, record, is_aggregated)

   if not record["FIRST_SEEN"] or
      not record["LAST_SEEN"] then
      return -- not from the row flow page
   end

   local op_suffix = tag_utils.SEPARATOR .. 'eq'
   local cli_port = ''
   if (not is_aggregated and processed_record.cli_port and  processed_record.cli_port.value) then
      cli_port = processed_record.cli_port.value
   end
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
         cli_port, op_suffix,
         ternary(processed_record.srv_port and processed_record.srv_port.value, processed_record.srv_port.value, ''), op_suffix)
         --ternary(processed_record.l4proto ~= nil, processed_record.l4proto.value, ''), op_suffix)
end

-- #####################################

local function dt_format_flow(processed_record, record)
   local cli = processed_record["cli_ip"]
   local srv = processed_record["srv_ip"]
   local vlan_id = processed_record["vlan_id"]

   if cli and srv and _GET["visible_columns"] and string.find(_GET["visible_columns"], "flow") then
      local cli_ip_alias = getHostAltName({host = cli["ip"], vlan = vlan_id})
      local srv_ip_alias = getHostAltName({host = srv["ip"], vlan = vlan_id})

      -- Add flow info to the processed_record, in place of cli_ip/srv_ip
      local flow = {}
      local vlan = {}
      local cli_ip = {}
      local srv_ip = {}
      local cli_port = {}
      local srv_port = {}

      -- Converting to the same format used for alert flows (see DataTableRenders.formatFlowTuple)

      cli_ip["value"]      = cli["ip"]                                                        -- IP address
      cli_ip["name"]       = cli["name"]                                                      -- Host name
      cli_ip["label"]      = ternary(isEmptyString(cli_ip_alias), cli["label"], cli_ip_alias) -- Label - This can be shortened if required
      cli_ip["label_long"] = cli["title"]                                                     -- Label - This is not shortened
      cli_ip["reference"]  = cli["reference"]
      cli_ip["location"]   = dt_format_location(record["CLIENT_LOCATION"])

      if processed_record["cli_country"] then
         cli_ip["country"] = processed_record["cli_country"]["value"]
      end 

      srv_ip["value"]      = srv["ip"]
      srv_ip["name"]       = srv["name"]
      srv_ip["label"]      = ternary(isEmptyString(srv_ip_alias), srv["label"], srv_ip_alias)
      srv_ip["label_long"] = srv["title"]
      srv_ip["reference"]  = srv["reference"]
      srv_ip["location"]   = dt_format_location(record["SERVER_LOCATION"])

      if processed_record["srv_country"] then
         srv_ip["country"] = processed_record["srv_country"]["value"]
      end 

      vlan["value"] = vlan_id["value"]
      vlan["label"] = vlan_id["label"]
      vlan["title"] = vlan_id["title"]

      if processed_record["cli_port"] then
         cli_port["value"] = processed_record["cli_port"]["value"]
         cli_port["label"] = getservbyport(tonumber(cli_port["value"]))
      end

      if processed_record["srv_port"] then
         srv_port["value"] = processed_record["srv_port"]["value"]
         srv_port["label"] = getservbyport(tonumber(srv_port["value"]))
      end

      flow["vlan"] = vlan
      flow["cli_ip"] = cli_ip
      flow["srv_ip"] = srv_ip
      flow["cli_port"] = cli_port
      flow["srv_port"] = srv_port

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
      if record["IPV4_SRC_ADDR"] then rules[#rules+1] = "host " .. record["IPV4_SRC_ADDR"] end
      if record["IPV4_DST_ADDR"] then rules[#rules+1] = "host " .. record["IPV4_DST_ADDR"] end
   elseif record["IP_PROTOCOL_VERSION"] and tonumber(record["IP_PROTOCOL_VERSION"]) == 6 then
      if record["IPV6_SRC_ADDR"] then rules[#rules+1] = "host " .. record["IPV6_SRC_ADDR"] end
      if record["IPV6_DST_ADDR"] then rules[#rules+1] = "host " .. record["IPV6_DST_ADDR"] end
   end

   if record["IP_SRC_PORT"] and tonumber(record["IP_SRC_PORT"]) > 0 then
      rules[#rules+1] = "port " .. record["IP_SRC_PORT"] 
   end 
   if record["IP_DST_PORT"] and tonumber(record["IP_DST_PORT"]) > 0 then
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
   ['FLOW_ID'] =              { tag = "rowid", db_type = "Number", db_raw_type = "Uint64" },
   ['IP_PROTOCOL_VERSION'] =  { db_type = "Number", db_raw_type = "Uint8" },
   ['FIRST_SEEN'] =           { tag = "first_seen",   dt_func = dt_format_time_with_highlight, db_type = "DateTime", db_raw_type = "DateTime" },
   ['LAST_SEEN'] =            { tag = "last_seen",    dt_func = dt_format_time, db_type = "DateTime", db_raw_type = "DateTime" },
   ['VLAN_ID'] =              { tag = "vlan_id",      dt_func = dt_format_vlan, db_type = "Number", db_raw_type = "Uint16" },
   ['PACKETS'] =              { tag = "packets",      dt_func = dt_format_pkts, db_type = "Number", db_raw_type = "Uint32" },
   ['TOTAL_BYTES'] =          { tag = "bytes",        dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64" },
   ['SRC2DST_BYTES'] =        { db_type = "Number", db_raw_type = "Uint64" },
   ['DST2SRC_BYTES'] =        { db_type = "Number", db_raw_type = "Uint64" },
   ['SRC2DST_DSCP'] =         { tag = "src2dst_dscp", dt_func = dt_format_dscp, simple_dt_func = dscp_consts.dscp_class_descr, db_type = "Number", db_raw_type = "Uint8" },
   ['DST2SRC_DSCP'] =         { tag = "dst2src_dscp", dt_func = dt_format_dscp, simple_dt_func = dscp_consts.dscp_class_descr, db_type = "Number", db_raw_type = "Uint8" },
   ['PROTOCOL'] =             { tag = "l4proto",      dt_func = dt_format_l4_proto, simple_dt_func = l4_proto_to_string, db_type = "Number", db_raw_type = "Uint8" },
   ['IPV4_SRC_ADDR'] =        { tag = "cli_ip",       dt_func = dt_format_src_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_src_ip, db_type = "Number", db_raw_type = "Uint32" },
   ['IPV6_SRC_ADDR'] =        { tag = "cli_ip",       dt_func = dt_format_src_ip, select_func = "IPv6NumToString", where_func = "IPv6StringToNum", simple_dt_func = simple_format_src_ip, db_type = "IPv6", db_raw_type = "IPv6" },
   ['IP_SRC_PORT'] =          { tag = "cli_port",     dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['IPV4_DST_ADDR'] =        { tag = "srv_ip",       dt_func = dt_format_dst_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_dst_ip, db_type = "Number", db_raw_type = "Uint32" },
   ['IPV6_DST_ADDR'] =        { tag = "srv_ip",       dt_func = dt_format_dst_ip, select_func = "IPv6NumToString", where_func = "IPv6StringToNum", simple_dt_func = simple_format_dst_ip, db_type = "IPv6", db_raw_type = "IPv6" },
   ['IP_DST_PORT'] =          { tag = "srv_port",     dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_PROTO'] =             { tag = "l7proto",      dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_CATEGORY'] =          { tag = "l7cat",        dt_func = dt_format_l7_category, simple_dt_func = interface.getnDPICategoryName, db_type = "Number", db_raw_type = "Uint16" },
   ['FLOW_RISK'] =            { tag = "flow_risk",    dt_func = dt_format_flow_risk, db_type = "Number", db_raw_type = "Uint64" },
   ['INFO'] =                 { tag = "info",         dt_func = dt_format_info, format_func = format_flow_info, i18n = i18n("info"), order = 11, db_type = "String", db_raw_type = "String" },
   ['PROFILE'] =              { db_type = "String", db_raw_type = "String" },
   ['NTOPNG_INSTANCE_NAME'] = { db_type = "String", db_raw_type = "String" },
   ['INTERFACE_ID'] =         { tag = "interface_id", db_type = "Number", db_raw_type = "Uint16" },
   ['STATUS'] =               { tag = "alert_id",       dt_func = dt_format_flow_alert_id, format_func = format_flow_alert_id, i18n = i18n("status"), simple_dt_func = format_flow_alert_id , order = 8, db_type = "Number", db_raw_type = "Uint8" },
   ['SRC_COUNTRY_CODE'] =     { tag = "cli_country", dt_func = dt_format_country, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_COUNTRY_CODE'] =     { tag = "srv_country", dt_func = dt_format_country, db_type = "Number", db_raw_type = "Uint16" },
   ['SRC_LABEL'] =            { tag = "cli_name", db_type = "String", db_raw_type = "String" },
   ['DST_LABEL'] =            { tag = "srv_name", db_type = "String", db_raw_type = "String" },
   ['SRC_MAC'] =              { tag = "cli_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   ['DST_MAC'] =              { tag = "srv_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   ['COMMUNITY_ID'] =         { tag = "community_id", format_func = format_flow_info, i18n = i18n("flow_fields_description.community_id"), order = 10, db_type = "String", db_raw_type = "String" },
   ['SRC_ASN'] =              { tag = "cli_asn", simple_dt_func = simple_format_src_asn, db_type = "Number", db_raw_type = "Uint32" },
   ['DST_ASN'] =              { tag = "srv_asn", simple_dt_func = simple_format_dst_asn, db_type = "Number", db_raw_type = "Uint32" },
   ['PROBE_IP'] =             { tag = "probe_ip",     dt_func = dt_format_probe, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", db_type = "Number", db_raw_type = "Uint32" },
   ['OBSERVATION_POINT_ID'] = { tag = "observation_point_id", dt_func = dt_format_obs_point, format_func = format_flow_observation_point, i18n = i18n("details.observation_point_id"), order = 12 , db_type = "Number", db_raw_type = "Uint16" },
   ['SRC2DST_TCP_FLAGS'] =    { tag = "src2dst_tcp_flags", dt_func = dt_format_tcp_flags, db_type = "Number", db_raw_type = "Uint8" },
   ['DST2SRC_TCP_FLAGS'] =    { tag = "dst2src_tcp_flags", dt_func = dt_format_tcp_flags, db_type = "Number", db_raw_type = "Uint8" },
   ['SCORE'] =                { tag = "score",        dt_func = dt_format_score, format_func = format_flow_score, i18n = i18n("score"), order = 9, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_PROTO_MASTER'] =      { tag = "l7proto_master", dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName, hide = true },
   ['CLIENT_NW_LATENCY_US'] = { tag = "cli_nw_latency", dt_func = dt_format_latency_ms, i18n = i18n("db_search.cli_nw_latency"), order = 13, db_type = "Number", db_raw_type = "Uint32" },
   ['SERVER_NW_LATENCY_US'] = { tag = "srv_nw_latency", dt_func = dt_format_latency_ms, i18n = i18n("db_search.srv_nw_latency"), order = 14, db_type = "Number", db_raw_type = "Uint32" },
   ['CLIENT_LOCATION'] =      { tag = "cli_location", dt_func = dt_format_location, db_type = "Number", db_raw_type = "Uint8" },
   ['SERVER_LOCATION'] =      { tag = "srv_location", dt_func = dt_format_location, db_type = "Number", db_raw_type = "Uint8" },
   ['SRC_NETWORK_ID'] =       { tag = "cli_network", dt_func = dt_format_network, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_NETWORK_ID'] =       { tag = "srv_network", dt_func = dt_format_network, db_type = "Number", db_raw_type = "Uint16" },
   ['INPUT_SNMP'] =           { tag = "input_snmp", dt_func = dt_format_snmp_interface, db_type = "Number", db_raw_type = "Uint32" },
   ['OUTPUT_SNMP'] =          { tag = "output_snmp", dt_func = dt_format_snmp_interface, db_type = "Number", db_raw_type = "Uint32" },
   ['SRC_HOST_POOL_ID'] =     { tag = "cli_host_pool_id", dt_func = dt_format_pool_id, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_HOST_POOL_ID'] =     { tag = "srv_host_pool_id", dt_func = dt_format_pool_id, db_type = "Number", db_raw_type = "Uint16" },
   ['ALERTS_MAP'] =           { tag = "alerts_map" },
   ['SEVERITY'] =             { tag = "severity" },
   ['IS_CLI_ATTACKER'] =      { tag = "is_cli_attacker" },
   ['IS_CLI_VICTIM'] =        { tag = "is_cli_victim" },
   ['IS_CLI_BLACKLISTED'] =   { tag = "is_cli_blacklisted" },
   ['IS_SRV_ATTACKER'] =      { tag = "is_srv_attacker" },
   ['IS_SRV_VICTIM'] =        { tag = "is_srv_victim" },
   ['IS_SRV_BLACKLISTED'] =   { tag = "is_srv_blacklisted" },
   ['ALERT_JSON'] =           { tag = "json" },
   ['SRC_PROC_NAME'] =        { tag = "cli_proc_name", db_type = "String", db_raw_type = "String" },
   ['DST_PROC_NAME'] =        { tag = "srv_proc_name", db_type = "String", db_raw_type = "String" },
   ['SRC_PROC_USER_NAME'] =   { tag = "cli_user_name", db_type = "String", db_raw_type = "String" },
   ['DST_PROC_USER_NAME'] =   { tag = "srv_user_name", db_type = "String", db_raw_type = "String" },
   ['MAJOR_CONNECTION_STATE'] = { tag = "major_connection_state", dt_func = dt_format_major_connection_state, db_type = "Number", db_raw_type = "Uint8" },
   ['MINOR_CONNECTION_STATE'] = { tag = "minor_connection_state", dt_func = dt_format_minor_connection_state, db_type = "Number", db_raw_type = "Uint8" },
   ['PRE_NAT_IPV4_SRC_ADDR']  = { tag = "pre_nat_ipv4_src_addr", dt_func = dt_format_nat_ip, select_func = "IPv4NumToString", db_type = "Number", db_raw_type = "Uint32"  },
   ['PRE_NAT_SRC_PORT']       = { tag = "pre_nat_src_port", dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['PRE_NAT_IPV4_DST_ADDR']  = { tag = "pre_nat_ipv4_dst_addr", dt_func = dt_format_nat_ip, select_func = "IPv4NumToString", db_type = "Number", db_raw_type = "Uint32"  },
   ['PRE_NAT_DST_PORT']       = { tag = "pre_nat_dst_port", dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['POST_NAT_IPV4_SRC_ADDR'] = { tag = "post_nat_ipv4_src_addr", dt_func = dt_format_nat_ip, select_func = "IPv4NumToString", db_type = "Number", db_raw_type = "Uint32"  },
   ['POST_NAT_SRC_PORT']      = { tag = "post_nat_src_port", dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['POST_NAT_IPV4_DST_ADDR'] = { tag = "post_nat_ipv4_dst_addr", dt_func = dt_format_nat_ip, select_func = "IPv4NumToString", db_type = "Number", db_raw_type = "Uint32"  },
   ['POST_NAT_DST_PORT']      = { tag = "post_nat_dst_port", dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   
   --[[ TODO: this column is for the aggregated_flow_columns but the parsing Function
              only parses these columns, so a new logic to parse only the aggregated_flow_columns
              is needed 
   ]]
   --['NUM_FLOWS'] =            { tag = "flows_number", dt_func = dt_format_high_number },
   
   -- Alert data
   ['ALERT_STATUS'] =         { tag = "alert_status" },
   ['USER_LABEL'] =           { tag = "user_label" },
   ['USER_LABEL_TSTAMP'] =    { tag = "user_label_tstamp" },
}
local aggregated_flow_columns = {
   ['FLOW_ID'] =              { tag = "rowid", db_type = "Number", db_raw_type = "Uint64" },
   ['IP_PROTOCOL_VERSION'] =  { db_type = "Number", db_raw_type = "Uint8" },
   ['FIRST_SEEN'] =           { tag = "first_seen",   dt_func = dt_format_time_with_highlight, db_type = "DateTime", db_raw_type = "DateTime" },
   ['LAST_SEEN'] =            { tag = "last_seen",    dt_func = dt_format_time, db_type = "DateTime", db_raw_type = "DateTime" },
   ['VLAN_ID'] =              { tag = "vlan_id",      dt_func = dt_format_vlan, db_type = "Number", db_raw_type = "Uint16"  },
   ['PACKETS'] =              { tag = "packets",      dt_func = dt_format_pkts, db_type = "Number", db_raw_type = "Uint32" },
   ['TOTAL_BYTES'] =          { tag = "bytes",        dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64"  },
   ['SRC2DST_BYTES'] =        { tag = "src2dst_bytes",        dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64"  },
   ['DST2SRC_BYTES'] =        { tag = "dst2src_bytes",        dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64"  },
   ['PROTOCOL'] =             { tag = "l4proto",      dt_func = dt_format_l4_proto, simple_dt_func = l4_proto_to_string, db_type = "Number", db_raw_type = "Uint8" },
   ['IPV4_SRC_ADDR'] =        { tag = "cli_ip",       dt_func = dt_format_src_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_src_ip, db_type = "Number", db_raw_type = "Uint32" },
   ['IPV6_SRC_ADDR'] =        { tag = "cli_ip",       dt_func = dt_format_src_ip, select_func = "IPv6NumToString", where_func = "IPv6StringToNum", simple_dt_func = simple_format_src_ip, db_type = "IPv6", db_raw_type = "IPv6"  },
   ['IPV4_DST_ADDR'] =        { tag = "srv_ip",       dt_func = dt_format_dst_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_dst_ip, db_type = "Number", db_raw_type = "Uint32" },
   ['IPV6_DST_ADDR'] =        { tag = "srv_ip",       dt_func = dt_format_dst_ip, select_func = "IPv6NumToString", where_func = "IPv6StringToNum", simple_dt_func = simple_format_dst_ip, db_type = "IPv6", db_raw_type = "IPv6"  },
   ['IP_DST_PORT'] =          { tag = "srv_port",     dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_PROTO'] =             { tag = "l7proto",      dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName, db_type = "Number", db_raw_type = "Uint16" },
   ['NTOPNG_INSTANCE_NAME'] = { db_type = "String", db_raw_type = "String" },
   ['SCORE'] =                { tag = "score",        dt_func = dt_format_score, format_func = format_flow_score, i18n = i18n("score"), order = 9, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_PROTO_MASTER'] =      { tag = "l7proto_master", dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName },
   ['NUM_FLOWS'] =            { tag = "flows_number", dt_func = dt_format_high_number },
   ['FLOW_RISK'] =            { tag = "flow_risk",    dt_func = dt_format_flow_risk, db_type = "Number", db_raw_type = "Uint64" },
   ['SRC_LABEL'] =            { tag = "cli_name", db_type = "String", db_raw_type = "String" },
   ['DST_LABEL'] =            { tag = "srv_name", db_type = "String", db_raw_type = "String" },
   ['SRC_MAC'] =              { tag = "cli_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   ['DST_MAC'] =              { tag = "srv_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   ['PROBE_IP'] =             { tag = "probe_ip",     dt_func = dt_format_probe, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", db_type = "Number", db_raw_type = "Uint32" },
   ['SRC_COUNTRY_CODE'] =     { tag = "cli_country", dt_func = dt_format_country, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_COUNTRY_CODE'] =     { tag = "srv_country", dt_func = dt_format_country, db_type = "Number", db_raw_type = "Uint16" },
   ['SRC_ASN'] =              { tag = "cli_asn", simple_dt_func = simple_format_src_asn, db_type = "Number", db_raw_type = "Uint32" },
   ['DST_ASN'] =              { tag = "srv_asn", simple_dt_func = simple_format_dst_asn, db_type = "Number", db_raw_type = "Uint32" },
   ['INPUT_SNMP'] =           { tag = "input_snmp", dt_func = dt_format_snmp_interface, db_type = "Number", db_raw_type = "Uint32" },
   ['OUTPUT_SNMP'] =          { tag = "output_snmp", dt_func = dt_format_snmp_interface, db_type = "Number", db_raw_type = "Uint32" },
   ['SRC_NETWORK_ID'] =       { tag = "cli_network", dt_func = dt_format_network, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_NETWORK_ID'] =       { tag = "srv_network", dt_func = dt_format_network, db_type = "Number", db_raw_type = "Uint16" },

}
-- Extra columns (e.g. result of SQL functions)
local additional_flow_columns = {
   ['bytes'] =                { tag = "bytes",        dt_func = dt_format_bytes },
   ['packets'] =              { tag = "packets",      dt_func = dt_format_pkts }, 
   ['IPV4_ADDR'] =            { tag = "ip",           dt_func = dt_format_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_ip },
   ['IPV6_ADDR'] =            { tag = "ip",           dt_func = dt_format_ip, select_func = "IPv6NumToString", where_func = "IPv6StringToNum", simple_dt_func = simple_format_ip },
   ['NETWORK_ID'] =           { tag = "network", dt_func = dt_format_network },
   ['ASN'] =                  { tag = "asn", simple_dt_func = simple_format_asn },
   ['COUNTRY_CODE'] =         { tag = "country", dt_func = dt_format_country },
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
   "PROTOCOL",
   "PROBE_IP",
   "SRC_LABEL",
   "DST_LABEL",
   "CLIENT_LOCATION",
   "SERVER_LOCATION",
   "COMMUNITY_ID",
   "NTOPNG_INSTANCE_NAME"
}

historical_flow_utils.min_aggregated_flow_db_columns = {
   "FLOW_ID",
   "FIRST_SEEN",
   "LAST_SEEN",
   "VLAN_ID",
   "PACKETS",
   "TOTAL_BYTES",
   "SRC2DST_BYTES",
   "DST2SRC_BYTES",
   "SCORE",
   "PROTOCOL",
   "IP_PROTOCOL_VERSION",
   "IPV4_SRC_ADDR",
   "IPV4_DST_ADDR",
   "IPV6_SRC_ADDR",
   "IPV6_DST_ADDR",
   "SRC_LABEL",
   "DST_LABEL",
   "IP_DST_PORT",
   "L7_PROTO",
   "L7_PROTO_MASTER",
   "NTOPNG_INSTANCE_NAME",
   "NUM_FLOWS",
   "FLOW_RISK",
   "SRC_MAC",
   "DST_MAC",
   "PROBE_IP",
   "SRC_COUNTRY_CODE",
   "DST_COUNTRY_CODE",
   "SRC_ASN",
   "DST_ASN",
   "INPUT_SNMP",
   "OUTPUT_SNMP",
   "SRC_NETWORK_ID",
   "DST_NETWORK_ID"
}

historical_flow_utils.extra_db_columns = {
   ["throughput"] = "ABS(LAST_SEEN - FIRST_SEEN) as TIME_DELTA, (TOTAL_BYTES / (TIME_DELTA + 1)) * 8 as THROUGHPUT",
   ["duration"] = "ABS(LAST_SEEN - FIRST_SEEN) as DURATION",
   ["alert_json"] = "ALERT_JSON"
}

historical_flow_utils.ordering_special_columns = {
   ["srv_ip"]   = {[4] = "IPv4NumToString(IPV4_DST_ADDR)", [6] = "IPv6NumToString(IPV6_DST_ADDR)"},
   ["cli_ip"]   = {[4] = "IPv4NumToString(IPV4_SRC_ADDR)", [6] = "IPv6NumToString(IPV6_SRC_ADDRc)"},
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
   ["community_id"] = "COMMUNITY_ID",
   ["duration"] = "DURATION",
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
      i18n_name = "queries.raw_flows_thpt",
      name = i18n("queries.raw_flows_thpt"),
      chart =
         {
            {
               unit_measure = "bps",
               params = {
                  count = "THROUGHPUT"
               }
            }
         },
   },
--[[   {
      id = "raw_flows_records",
      i18n_name = "queries.raw_flows_records",
      name = i18n("queries.raw_flows_records"),
      chart =
         {
            {
               unit_measure = "number",
               params = {
                  COUNT = "NUM_FLOWS"
               }
            }
         },
   },]]
   {
      id = "raw_flows_bytes",
      i18n_name = "queries.raw_flows_bytes",
      name = i18n("queries.raw_flows_bytes"),
      chart =
         {
            {
               unit_measure = "bytes",
               params = {
                  count = "TOTAL_BYTES"
               }
            }
         },
   },
   {
      id = "raw_flows_score",
      i18n_name = "queries.raw_flows_score",
      name = i18n("queries.raw_flows_score"),
      chart =
         {
            {
               params = {
                  count = "SCORE"
               }
            }
         },
   },
}

-- #####################################

function historical_flow_utils.get_flow_columns()
   return flow_columns
end

-- #####################################

function historical_flow_utils.get_extended_flow_columns(use_aggregated)
   local extended_flow_columns = {}
   if not use_aggregated then
      for k, v in pairs(flow_columns) do
         extended_flow_columns[k] = v
      end
   else
      for k, v in pairs(aggregated_flow_columns) do
         extended_flow_columns[k] = v
      end
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
   flow_defined_tags["ja4_client"] = tag_utils.defined_tags["ja4_client"]
   flow_defined_tags["issuer_dn"] = tag_utils.defined_tags["issuer_dn"]
   flow_defined_tags["http_method"] = tag_utils.defined_tags["http_method"]
   flow_defined_tags["http_url"] = tag_utils.defined_tags["http_url"]
   flow_defined_tags["http_return"] = tag_utils.defined_tags["http_return"]
   flow_defined_tags["user_agent"] = tag_utils.defined_tags["user_agent"]
   flow_defined_tags["last_server"] = tag_utils.defined_tags["last_server"]
   flow_defined_tags["netbios_name"] = tag_utils.defined_tags["netbios_name"]
   flow_defined_tags["mdns_answer"] = tag_utils.defined_tags["mdns_answer"]
   flow_defined_tags["mdns_name"] = tag_utils.defined_tags["mdns_name"]
   flow_defined_tags["mdns_name_txt"] = tag_utils.defined_tags["mdns_name_txt"]
   flow_defined_tags["mdns_ssid"] = tag_utils.defined_tags["mdns_ssid"]
   flow_defined_tags["cli_location"] = tag_utils.defined_tags["cli_location"]
   flow_defined_tags["srv_location"] = tag_utils.defined_tags["srv_location"]
   flow_defined_tags["traffic_direction"] = tag_utils.defined_tags["traffic_direction"]
   flow_defined_tags["confidence"] = tag_utils.defined_tags["confidence"]
   flow_defined_tags["network_cidr"] = tag_utils.defined_tags["network_cidr"]
   flow_defined_tags["srv_network_cidr"] = tag_utils.defined_tags["srv_network_cidr"]
   flow_defined_tags["cli_network_cidr"] = tag_utils.defined_tags["cli_network_cidr"]
   flow_defined_tags["duration"] = tag_utils.defined_tags["duration"]
   flow_defined_tags["network"] = tag_utils.defined_tags["network"]
   flow_defined_tags["retransmissions"] = tag_utils.defined_tags["retransmissions"]
   flow_defined_tags["out_of_order"] = tag_utils.defined_tags["out_of_order"]
   flow_defined_tags["lost"] = tag_utils.defined_tags["lost"]
   flow_defined_tags["l4proto"] = tag_utils.defined_tags["l4proto"]
   flow_defined_tags["pre_nat_ipv4_src_addr"] = tag_utils.defined_tags["pre_nat_ipv4_src_addr"]
   flow_defined_tags["pre_nat_src_port"] = tag_utils.defined_tags["pre_nat_src_port"]
   flow_defined_tags["pre_nat_ipv4_dst_addr"] = tag_utils.defined_tags["pre_nat_ipv4_dst_addr"]
   flow_defined_tags["pre_nat_dst_port"] = tag_utils.defined_tags["pre_nat_dst_port"]
   flow_defined_tags["post_nat_ipv4_src_addr"] = tag_utils.defined_tags["post_nat_ipv4_src_addr"]
   flow_defined_tags["post_nat_src_port"] = tag_utils.defined_tags["post_nat_src_port"]
   flow_defined_tags["post_nat_ipv4_dst_addr"] = tag_utils.defined_tags["post_nat_ipv4_dst_addr"]
   flow_defined_tags["post_nat_dst_port"] = tag_utils.defined_tags["post_nat_dst_port"]

   return flow_defined_tags
end

-- #####################################

function historical_flow_utils.get_flow_columns_to_tags(aggregated)
   local c2t = {}
   local t2c = {}

   if aggregated then
      for k, v in pairs(aggregated_flow_columns) do
         if v.tag then
            c2t[k] = v.tag
            t2c[v.tag] = k
         end
      end
   else
      for k, v in pairs(flow_columns) do
         if v.tag then
            c2t[k] = v.tag
            t2c[v.tag] = k
         end
      end
   end

   for k, v in pairs(additional_flow_columns) do
      if v.tag then 
         if not t2c[v.tag] then -- tag not already defined in real columns
            c2t[k] = v.tag
            -- t2c[v.tag] = k
         end
      end
   end

   return c2t 
end

-- #####################################

-- Return a table with a list of DB columns for each tag
-- Example:
-- { ["srv_ip"] = ["IPV4_DST_ADDR"], ["IPV6_DST_ADDR"], .. }
local function get_flow_tags_to_columns(aggregated)
   local t2c = {}
   local c2t = historical_flow_utils.get_flow_columns_to_tags(aggregated)

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
function historical_flow_utils.get_flow_select_by_tag(tag, aggregated)
   local tags_to_columns = get_flow_tags_to_columns(aggregated)
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
function historical_flow_utils.get_flow_column_by_tag(tag, ip_version, aggregated)
   local tags_to_columns = get_flow_tags_to_columns(aggregated)

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
      dt_add_alerts_url(processed_record, record,false)
      dt_format_flow(processed_record, record)
   end

   return processed_record 
end

-- #####################################

function historical_flow_utils.format_clickhouse_record(record, csv_format, formatted_record, is_aggregated)
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
      local extended_flow_columns = historical_flow_utils.get_extended_flow_columns(is_aggregated)
      
      dt_add_tstamp(record)
      dt_add_filter(record)

      ----------------------------------
      -- Cycling the value of the record
      for column_name, value in pairs(record) do
	 if do_trace == "1" then traceError(TRACE_NORMAL, TRACE_CONSOLE, column_name .. " start") end
         local new_column_name = column_name
         local new_value = value

      	 -- Format the values and pass to the answer
      	 if extended_flow_columns[column_name] and 
            --extended_flow_columns[column_name]["dt_func"] and
            extended_flow_columns[column_name]["tag"] then

            new_column_name = extended_flow_columns[column_name]["tag"]

            if extended_flow_columns[column_name]["dt_func"] then
               new_value = extended_flow_columns[column_name]["dt_func"](value, record, column_name, formatted_record)
            end
      	 end

      	 if new_column_name and new_value then
            processed_record[new_column_name] = new_value
      	 end
	 if do_trace == "1" then traceError(TRACE_NORMAL, TRACE_CONSOLE, column_name .. " end") end
      end

      dt_format_asn(processed_record, record)
      dt_unify_l7_proto(processed_record)
      dt_add_alerts_url(processed_record, record, is_aggregated)
      dt_format_flow(processed_record, record)
   end

   return processed_record
end

-- #####################################

function historical_flow_utils.get_historical_url(label, tag, value, add_hyperlink, title, add_copy_button)
   if not add_hyperlink then 
      return label
   else
      if add_copy_button ~= nil and add_copy_button then
         return "<span><button data-to-copy='"..value.."' class='copy-http-url btn btn-light btn-sm border ms-1' style='cursor: pointer;'><i class='fas fa-copy'></i></button> <a href=\"" .. ntop.getHttpPrefix() .. "/lua/pro/db_search.lua?" .. 
            tag .. "=" .. value .. tag_utils.SEPARATOR .. "eq\" " .. 
            ternary(title ~= nil, "title=\"" .. (title or "") .."\"", "") .. 
            " target='_blank'>" .. label .. "</a>"
      end
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

   if add_hyperlinks and info.cli_location and not isEmptyString(info.cli_location) then
      label = label .. " " .. format_location_badge(info.cli_location)
   end

   if info.cli_port and not isEmptyString(info.cli_port.label) then
      label = label .. ":" ..historical_flow_utils.get_historical_url(info.cli_port.label, "cli_port", info.cli_port.value, add_hyperlinks)
   end

   if info.is_cli_attacker and info.is_cli_attacker == '1' then
    label = label .. ' <i class="fas fa-skull" title="' .. i18n('db_explorer.is_attacker') .. '"></i> '
   end
   
   if info.is_cli_victim and info.is_cli_victim == '1' then
    label = label .. ' <i class="fas fa-sad-tear" title="' .. i18n('db_explorer.is_victim') .. '"></i> '
   end
   
   if info.is_cli_blacklisted and info.is_cli_blacklisted == '1' then
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

   if add_hyperlinks and info.srv_location and not isEmptyString(info.srv_location) then
      label = label .. " " .. format_location_badge(info.srv_location)
   end

   if info.srv_port and not isEmptyString(info.srv_port.label) then
      label = label .. ":" ..historical_flow_utils.get_historical_url(info.srv_port.label, "srv_port", info.srv_port.value, add_hyperlinks)
   end

   if info.is_srv_attacker and info.is_srv_attacker == '1' then
    label = label .. ' <i class="fas fa-skull" title="' .. i18n('db_explorer.is_attacker') .. '"></i> '
   end
   
   if info.is_srv_victim and info.is_srv_victim == '1' then
    label = label .. ' <i class="fas fa-sad-tear" title="' .. i18n('db_explorer.is_victim') .. '"></i> '
   end
   
   if info.is_srv_blacklisted and info.is_srv_blacklisted == '1' then
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
      local blacklist_name = ""
      if (info.l7cat.label == 'Malware') then
         local json_info = json.decode(info.json)
         if (json_info and json_info.custom_cat_file) then
            blacklist_name = " @ " ..json_info.custom_cat_file
         end
      end
    label = label .. " (" ..historical_flow_utils.get_historical_url(info.l7cat.label, "l7cat", info.l7cat.value, add_hyperlinks) .. blacklist_name .. ")"
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

-- #####################################

-- Return the list of available DB columns and 
-- relative tags used to filter info
function historical_flow_utils.getAvailableColumns()
  if not interfaceHasClickHouseSupport() then
    return {}
  end
  local extended_flow_columns = historical_flow_utils.get_extended_flow_columns()
  local data = {}

  for column_name, column_options in pairs(extended_flow_columns) do
    data[#data + 1] = {
      column_name = column_name,
      tag = column_options["tag"]
    }
  end

  return data
end

return historical_flow_utils

