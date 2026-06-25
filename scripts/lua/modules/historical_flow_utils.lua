--
-- (C) 2013-26 - ntop.org
--

require "lua_utils_get"
local flowfilter_utils = require "flowfilter_utils"
local dscp_consts = require "dscp_consts"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local flow_risk_utils = require "flow_risk_utils"
local country_codes = require "country_codes"
local network_consts = require "network_consts"
local historical_format_utils = require "historical_format_utils"
local qoe_utils
local historical_ts_definitions
if ntop.isEnterpriseM and ntop.isEnterpriseM() then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/flow_db/?.lua;" .. package.path
    historical_ts_definitions = require "historical_ts_definitions"
end
if ntop.isEnterpriseL and ntop.isEnterpriseL() then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    qoe_utils = require "qoe_utils"
end

local tag_badge_utils = require "tag_badge_utils"

local historical_flow_utils = {}

local _all_tags_cache = nil
local function get_all_tags()
   if _all_tags_cache == nil then
      _all_tags_cache = tag_badge_utils.getTags()
   end
   return _all_tags_cache
end

-- Parse TAGS_MAP hex string stored in ClickHouse into an array of name/color
local function dt_format_tags_map(hex_str)
   if isEmptyString(hex_str) then return nil end
   local bitmap = tonumber(hex_str, 16)
   if not bitmap or bitmap == 0 then return nil end
   local result = {}
   for _, label in ipairs(get_all_tags()) do
      local bit_index = tonumber(label.id) or 0
      if (bitmap & (1 << bit_index)) ~= 0 then
         result[#result + 1] = { id = label.id, name = label.name, color = label.color }
      end
   end
   return #result > 0 and result or nil
end

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
         local p_info = split(p, flowfilter_utils.SEPARATOR)

         if not tonumber(p_info[1]) then
            local tmp = p_info[1]

            if tmp == no_asn_string then
               tmp = "0"
            end

            p_info[1] = tmp
         end

         if asn == nil then asn = '' else asn = asn .. "," end
         asn = asn .. p_info[1] .. flowfilter_utils.SEPARATOR .. p_info[2]
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
         local p_info = split(p, flowfilter_utils.SEPARATOR)

         if not tonumber(p_info[1]) then
            local tmp = string.lower(p_info[1])
            tmp = l4_proto_to_id(tmp)

            if not p_info[1] then
               tmp = l4_proto_to_id(p_info[1])
            end

            p_info[1] = tmp
         end

         if l4_proto == nil then l4_proto = '' else l4_proto = l4_proto .. "," end
         l4_proto = l4_proto .. p_info[1] .. flowfilter_utils.SEPARATOR .. p_info[2]
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
         local p_info = split(p, flowfilter_utils.SEPARATOR)

         if not tonumber(p_info[1]) then
            local tmp = string.lower(p_info[1])
            tmp = interface.getnDPICategoryId(tmp)

            if not p_info[1] then
               tmp = interface.getnDPICategoryId(p_info[1])
            end

            p_info[1] = tmp
         end

         if l7_cat == nil then l7_cat = '' else l7_cat = l7_cat.. "," end
         l7_cat = l7_cat .. p_info[1] .. flowfilter_utils.SEPARATOR .. p_info[2]
      end
   end

   return l7_cat
end

-- #####################################

function historical_flow_utils.get_selected_filters(ifid)
   local selected_filters = flowfilter_utils.get_flowfilter_filters_from_request()

   if ifid ~= nil then
      selected_filters['ifid'] = ifid
   end

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

local function dt_format_generic(s)
   return {
      title = s,
      label = s,
      value = s,
   } 
end

-- #####################################

local function dt_format_first_flow_dump(s) 
   return {
      label = ternary(tonumber(s) == 1, i18n('yes'), i18n('no')),
      value = tonumber(s),
   }
end

-- #####################################

local function dt_format_tcp_stats(s)
   -- TODO Implement

   return dt_format_generic(s)
end

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
   if mac == nil then return "" end
   if type(mac) == "string" and isMacAddress(mac) then return mac end
   mac = tonumber(mac)
   if not mac or mac == 0 then return "" end
   return ntop.decodeMac64(mac)
end

-- #####################################

local function dt_format_mac_obj(mac)
   local mac_str = dt_format_mac(mac)
   local formatted_mac = {
      title = mac_str,
      label = mac_str,
      value = mac_str,
   } 

   return formatted_mac
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

local function dt_format_time(epoch)
   local time = epoch
   if (time) and (tonumber(time)) then
      time = format_utils.formatPastEpochShort(time)
   end

   return {
      epoch = tonumber(epoch),
      time = time
   }
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

local function dt_format_time_with_highlight(epoch, record)
   local time = epoch
   if (time) and (tonumber(time)) then
      time = format_utils.formatPastEpochShort(time)
   end

   local severity_id = map_score_to_severity(tonumber(record["SCORE"]) or 0)
   local severity = alert_consts.alertSeverityById(severity_id)

   return {
      epoch = tonumber(epoch),
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

local function dt_format_qoe_score(score)
   local score = tonumber(score) or 0

   return ({
      value = score,
      label = format_utils.formatValue(score),
      color = nil,
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

   if isEmptyString(probe_ip) or probe_ip == "0.0.0.0" or probe_ip == "0" or probe_ip == "::" then
      probe_info["title"] = ""
      probe_info["label"] = ""
      probe_info["value"] = ""
   else
      local display_ip = probe_ip
      probe_info["title"] = display_ip
      probe_info["value"] = probe_ip
      probe_info["label"] = getProbeName(display_ip)
      if (probe_info["label"]
            and (probe_info["title"] ~= probe_info["label"])
            and not isEmptyString(probe_info["label"])) then
         probe_info["title"] = probe_info["title"] .. " [" .. probe_info["label"] .. "]"
      end
   end

   return probe_info
end

-- #####################################

local function dt_format_site(site_id)
   local site = {
      title     = i18n("unknown"),
      label     = i18n("unknown"),
      value     = tonumber(site_id) or 0,
   }

   if tonumber(site["value"]) ~= 0 then
      local site_utils = require "site_utils"
      local sites = site_utils.getSites() or {}
      for _, site in pairs(sites) do
         if site.id == tostring(site_id) then
            site["title"] = site.name
            site["label"] = site.name
            break
         end
      end
   else
      site["title"] = i18n("default")
      site["label"] = i18n("default")
   end

   return site
end

-- #####################################

local function dt_format_thpt(thpt)
   if getThroughputType() == "bps" then
      return bitsToSize(tonumber(thpt) or 0)
   else
      return pktsToSize(tonumber(thpt) or 0)
   end
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

   if isEmptyString(network)
      or tonumber(network) >= network_consts.UNKNOWN_NETWORK then
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
  
  local display_ip = exporter

  if tostring(interface) ~= "0" and not isEmptyString(display_ip) and display_ip ~= "::" then
    label = format_portidx_name(display_ip, tostring(interface), true)
    value = display_ip .. "_" .. tostring(interface)
  end

  local interface_tag = {
    value = value,
    label = label,
    title = interface,
  }

  return interface_tag
end

-- #####################################

local function dt_format_interface(interface_id)
  local ifid = tonumber(interface_id) or 0
  local label = getInterfaceName(ifid)

  if isEmptyString(label) then
    label = tostring(ifid)
  end

  local interface_tag = {
    value = ifid,
    label = label,
    title = label,
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

local function simple_format_interface_role(value)
   local role_labels = {
      [0] = i18n("prefs.snmp_interface_role_list.other"),
      [1] = i18n("prefs.snmp_interface_role_list.transit"),
      [2] = i18n("prefs.snmp_interface_role_list.peering"),
      [3] = i18n("prefs.snmp_interface_role_list.internal_interface"),
      [4] = i18n("prefs.snmp_interface_role_list.ix"),
      [5] = i18n("prefs.snmp_interface_role_list.customer_interface"),
      [6] = i18n("prefs.snmp_interface_role_list.internet_connectivity"),
   }
   return role_labels[tonumber(value)] or tostring(value)
end

-- #####################################

local function dt_add_alerts_url(processed_record, record, is_aggregated)

   if not record["FIRST_SEEN"] or
      not record["LAST_SEEN"] then
      return -- not from the row flow page
   end

   local op_suffix = flowfilter_utils.SEPARATOR .. 'eq'
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

      local cli_mac = processed_record["cli_mac"]
      local srv_mac = processed_record["srv_mac"]
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
      flow["cli_mac"] = cli_mac
      flow["srv_mac"] = srv_mac
      processed_record["flow"] = flow
      processed_record["tags"] = processed_record["tags_map"]
      processed_record["tags_map"] = nil
      processed_record["src_tags"] = processed_record["src_tags_map"]
      processed_record["src_tags_map"] = nil
      processed_record["dst_tags"] = processed_record["dst_tags_map"]
      processed_record["dst_tags_map"] = nil

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

local function format_flow_qoe_score(score, flow)
   local score = tonumber(score)
   local label = format_utils.formatValue(score)

   return label
end

local function chart_format_flow_qoe_score(score, flow)
    local label = tonumber(score)
    if qoe_utils then
        label = qoe_utils.getQoELabel(label)
    end
    return label
end

local function format_flow_observation_point(id, flow)
   return getFullObsPointName(tonumber(id), nil, true)
end

------------------------------------------------------------------------

-- List of flow columns in the database
--
-- Keep in sync with ClickHouseDB.cpp and flowfilter_utils.lua
--
-- - select_func is used in SELECT clause to convert DB-to-Lua the value (e.g. IP addresses)
-- - where_func is used in WHERE clause to convert Lua-to-DB the value
-- - format_func is used to format the value as string/html (used by flow details page)
-- - dt_func is used to convert the value in the format expected by the js datatable
-- - order is used to sort the fields in the flow details
local flow_columns = {
   ['FLOW_ID'] =              { flowfilter = "rowid", db_type = "Number", db_raw_type = "Uint64" },
   ['IP_PROTOCOL_VERSION'] =  { db_type = "Number", db_raw_type = "Uint8" },
   ['FIRST_SEEN'] =           { flowfilter = "first_seen",   dt_func = dt_format_time_with_highlight, db_type = "DateTime", db_raw_type = "DateTime" },
   ['LAST_SEEN'] =            { flowfilter = "last_seen",    dt_func = dt_format_time, db_type = "DateTime", db_raw_type = "DateTime" },
   ['VLAN_ID'] =              { flowfilter = "vlan_id",      dt_func = dt_format_vlan, db_type = "Number", db_raw_type = "Uint16" },
   ['PACKETS'] =              { flowfilter = "packets",      dt_func = dt_format_pkts, db_type = "Number", db_raw_type = "Uint32" },
   ['TOTAL_BYTES'] =          { flowfilter = "bytes",        dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64" },
   ['SRC2DST_BYTES'] =        { flowfilter = "cli2srv_bytes", dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64" },
   ['DST2SRC_BYTES'] =        { flowfilter = "srv2cli_bytes", dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64" },
   ['SRC2DST_PACKETS'] =      { flowfilter = "cli2srv_packets", dt_func = dt_format_pkts, db_type = "Number", db_raw_type = "Uint32" },
   ['DST2SRC_PACKETS'] =      { flowfilter = "srv2cli_packets", dt_func = dt_format_pkts, db_type = "Number", db_raw_type = "Uint32" },
   ['SRC2DST_DSCP'] =         { flowfilter = "src2dst_dscp", dt_func = dt_format_dscp, simple_dt_func = dscp_consts.dscp_class_descr, db_type = "Number", db_raw_type = "Uint8" },
   ['DST2SRC_DSCP'] =         { flowfilter = "dst2src_dscp", dt_func = dt_format_dscp, simple_dt_func = dscp_consts.dscp_class_descr, db_type = "Number", db_raw_type = "Uint8" },
   ['PROTOCOL'] =             { flowfilter = "l4proto",      dt_func = dt_format_l4_proto, simple_dt_func = l4_proto_to_string, db_type = "Number", db_raw_type = "Uint8" },
   ['IPV4_SRC_ADDR'] =        { flowfilter = "cli_ip",       dt_func = dt_format_src_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_src_ip, db_type = "Number", db_raw_type = "Uint32" },
   ['IPV6_SRC_ADDR'] =        { flowfilter = "cli_ip",       dt_func = dt_format_src_ip, where_func = "IPv6StringToNum", simple_dt_func = simple_format_src_ip, db_type = "IPv6", db_raw_type = "IPv6" },
   ['IP_SRC_PORT'] =          { flowfilter = "cli_port",     dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['IPV4_DST_ADDR'] =        { flowfilter = "srv_ip",       dt_func = dt_format_dst_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_dst_ip, db_type = "Number", db_raw_type = "Uint32" },
   ['IPV6_DST_ADDR'] =        { flowfilter = "srv_ip",       dt_func = dt_format_dst_ip, where_func = "IPv6StringToNum", simple_dt_func = simple_format_dst_ip, db_type = "IPv6", db_raw_type = "IPv6" },
   ['IP_DST_PORT'] =          { flowfilter = "srv_port",     dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_PROTO'] =             { flowfilter = "l7proto",      dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_CATEGORY'] =          { flowfilter = "l7cat",        dt_func = dt_format_l7_category, simple_dt_func = interface.getnDPICategoryName, db_type = "Number", db_raw_type = "Uint16" },
   ['FLOW_RISK'] =            { flowfilter = "flow_risk",    dt_func = dt_format_flow_risk, db_type = "Number", db_raw_type = "Uint64" },
   ['INFO'] =                 { flowfilter = "info",         dt_func = dt_format_info, format_func = format_flow_info, i18n = i18n("info"), order = 11, db_type = "String", db_raw_type = "String" },
   ['PROFILE'] =              { db_type = "String", db_raw_type = "String" },
   ['NTOPNG_INSTANCE_NAME'] = { db_type = "String", db_raw_type = "String" },
   ['INTERFACE_ID'] =         { flowfilter = "ntopng_interface", dt_func = dt_format_interface, db_type = "Number", db_raw_type = "Uint16" },
   ['STATUS'] =               { flowfilter = "alert_id",       dt_func = dt_format_flow_alert_id, format_func = format_flow_alert_id, i18n = i18n("status"), simple_dt_func = format_flow_alert_id , order = 8, db_type = "Number", db_raw_type = "Uint8" },
   ['SRC_COUNTRY_CODE'] =     { flowfilter = "cli_country", dt_func = dt_format_country, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_COUNTRY_CODE'] =     { flowfilter = "srv_country", dt_func = dt_format_country, db_type = "Number", db_raw_type = "Uint16" },
   ['SRC_LABEL'] =            { flowfilter = "cli_name", db_type = "String", db_raw_type = "String" },
   ['DST_LABEL'] =            { flowfilter = "srv_name", db_type = "String", db_raw_type = "String" },
   ['SRC_MAC'] =              { flowfilter = "cli_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   ['DST_MAC'] =              { flowfilter = "srv_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   -- ['COMMUNITY_ID'] =         { flowfilter = "community_id", format_func = format_flow_info, i18n = i18n("flow_fields_description.community_id"), order = 10, db_type = "String", db_raw_type = "String" },
   ['CLIENT_FINGERPRINT'] =   { flowfilter = "cli_fingerprint", dt_func = dt_format_generic, order = 11, db_type = "String", db_raw_type = "String" },
   -- ['TCP_FINGERPRINT'] =      { flowfilter = "tcp_fingerprint", dt_func = dt_format_generic, order = 11, db_type = "String", db_raw_type = "String" },

   -- ['TCP_STATS_SRC_TO_DST'] = { flowfilter = "tcp_stats_src_to_dst", dt_func = dt_format_tcp_stats, order = 11, db_type = "String", db_raw_type = "String" },
   -- ['TCP_STATS_SRC_TO_DST'] = { flowfilter = "tcp_stats_src_to_dst", dt_func = dt_format_tcp_stats, order = 11, db_type = "String", db_raw_type = "String" },
   
   ['SRC_ASN'] =              { flowfilter = "cli_asn", simple_dt_func = simple_format_src_asn, db_type = "Number", db_raw_type = "Uint32" },
   ['DST_ASN'] =              { flowfilter = "srv_asn", simple_dt_func = simple_format_dst_asn, db_type = "Number", db_raw_type = "Uint32" },
   ['PROBE_IP'] =             { flowfilter = "probe_ip", dt_func = dt_format_probe, where_func = "toIPv6", db_type = "IPv6", db_raw_type = "IPv6" },
   ['EXPORTER_SITE'] =        { flowfilter = "site", dt_func = dt_format_site, db_type = "Number", db_raw_type = "Uint16" },
   ['OBSERVATION_POINT_ID'] = { flowfilter = "observation_point_id", dt_func = dt_format_obs_point, format_func = format_flow_observation_point, i18n = i18n("details.observation_point_id"), order = 12 , db_type = "Number", db_raw_type = "Uint16" },
   ['SRC2DST_TCP_FLAGS'] =    { flowfilter = "src2dst_tcp_flags", dt_func = dt_format_tcp_flags, db_type = "Number", db_raw_type = "Uint8" },
   ['DST2SRC_TCP_FLAGS'] =    { flowfilter = "dst2src_tcp_flags", dt_func = dt_format_tcp_flags, db_type = "Number", db_raw_type = "Uint8" },
   ['SCORE'] =                { flowfilter = "score",        dt_func = dt_format_score, format_func = format_flow_score, i18n = i18n("score"), order = 9, db_type = "Number", db_raw_type = "Uint16" },
   ['QOE_SCORE'] =            { flowfilter = "qoe_score",    dt_func = dt_format_qoe_score, format_func = format_flow_qoe_score, simple_dt_func = chart_format_flow_qoe_score, i18n = i18n("db_search.flowfilters.qoe_score"), order = 10, db_type = "Number", db_raw_type = "Uint8" },
   ['L7_PROTO_MASTER'] =      { flowfilter = "l7proto_master", dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName, hide = true },
   ['CLIENT_NW_LATENCY_US'] = { flowfilter = "cli_nw_latency", dt_func = dt_format_latency_ms, i18n = i18n("db_search.cli_nw_latency"), order = 13, db_type = "Number", db_raw_type = "Uint32" },
   ['SERVER_NW_LATENCY_US'] = { flowfilter = "srv_nw_latency", dt_func = dt_format_latency_ms, i18n = i18n("db_search.srv_nw_latency"), order = 14, db_type = "Number", db_raw_type = "Uint32" },
   ['CLIENT_LOCATION'] =      { flowfilter = "cli_location", dt_func = dt_format_location, db_type = "Number", db_raw_type = "Uint8" },
   ['SERVER_LOCATION'] =      { flowfilter = "srv_location", dt_func = dt_format_location, db_type = "Number", db_raw_type = "Uint8" },
   ['SRC_NETWORK_ID'] =       { flowfilter = "cli_network", dt_func = dt_format_network, db_type = "Number", db_raw_type = "Uint32" },
   ['DST_NETWORK_ID'] =       { flowfilter = "srv_network", dt_func = dt_format_network, db_type = "Number", db_raw_type = "Uint32" },
   ['SRC_SITE_ID'] =          { flowfilter = "cli_site", dt_func = dt_format_site, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_SITE_ID'] =          { flowfilter = "srv_site", dt_func = dt_format_site, db_type = "Number", db_raw_type = "Uint16" },
   ['INPUT_SNMP'] =           { flowfilter = "input_snmp", dt_func = dt_format_snmp_interface, db_type = "Number", db_raw_type = "Uint32" },
   ['OUTPUT_SNMP'] =          { flowfilter = "output_snmp", dt_func = dt_format_snmp_interface, db_type = "Number", db_raw_type = "Uint32" },
   ['SRC_HOST_POOL_ID'] =     { flowfilter = "cli_host_pool_id", dt_func = dt_format_pool_id, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_HOST_POOL_ID'] =     { flowfilter = "srv_host_pool_id", dt_func = dt_format_pool_id, db_type = "Number", db_raw_type = "Uint16" },
   ['ALERTS_MAP'] =           { flowfilter = "alerts_map" },
   ['TAGS_MAP'] =           { flowfilter = "tags_map", dt_func = dt_format_tags_map, db_type = "String", db_raw_type = "String" },
   ['SRC_TAGS_MAP'] =       { flowfilter = "src_tags_map", dt_func = dt_format_tags_map, db_type = "String", db_raw_type = "String" },
   ['DST_TAGS_MAP'] =       { flowfilter = "dst_tags_map", dt_func = dt_format_tags_map, db_type = "String", db_raw_type = "String" },
   ['SEVERITY'] =             { flowfilter = "severity" },
   ['IS_CLI_ATTACKER'] =      { flowfilter = "is_cli_attacker" },
   ['IS_CLI_VICTIM'] =        { flowfilter = "is_cli_victim" },
   ['IS_CLI_BLACKLISTED'] =   { flowfilter = "is_cli_blacklisted" },
   ['IS_SRV_ATTACKER'] =      { flowfilter = "is_srv_attacker" },
   ['IS_SRV_VICTIM'] =        { flowfilter = "is_srv_victim" },
   ['IS_SRV_BLACKLISTED'] =   { flowfilter = "is_srv_blacklisted" },
   ['PROTOCOL_INFO_JSON'] =   { flowfilter = "protocol_info_json", dt_func = historical_format_utils.parseInfoJson },
   ['THROUGHPUT'] =           { flowfilter = "throughput", dt_func = dt_format_thpt, exclude_from_details = true },
   ['ALERT_JSON'] =           { flowfilter = "json" },
   ['SRC_PROC_NAME'] =        { flowfilter = "cli_proc_name", db_type = "String", db_raw_type = "String" },
   ['DST_PROC_NAME'] =        { flowfilter = "srv_proc_name", db_type = "String", db_raw_type = "String" },
   ['SRC_PROC_USER_NAME'] =   { flowfilter = "cli_user_name", db_type = "String", db_raw_type = "String" },
   ['DST_PROC_USER_NAME'] =   { flowfilter = "srv_user_name", db_type = "String", db_raw_type = "String" },
   ['MAJOR_CONNECTION_STATE'] = { flowfilter = "major_connection_state", dt_func = dt_format_major_connection_state, db_type = "Number", db_raw_type = "Uint8" },
   ['MINOR_CONNECTION_STATE'] = { flowfilter = "minor_connection_state", dt_func = dt_format_minor_connection_state, db_type = "Number", db_raw_type = "Uint8" },
   ['POST_NAT_IPV4_SRC_ADDR'] = { flowfilter = "post_nat_ipv4_src_addr", dt_func = dt_format_nat_ip, select_func = "IPv4NumToString", db_type = "Number", db_raw_type = "Uint32"  },
   ['POST_NAT_SRC_PORT']      = { flowfilter = "post_nat_src_port", dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['POST_NAT_IPV4_DST_ADDR'] = { flowfilter = "post_nat_ipv4_dst_addr", dt_func = dt_format_nat_ip, select_func = "IPv4NumToString", db_type = "Number", db_raw_type = "Uint32"  },
   ['POST_NAT_DST_PORT']      = { flowfilter = "post_nat_dst_port", dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   --['WLAN_SSID']              = { flowfilter = "wlan_ssid", dt_func = dt_format_generic, db_type = "String", db_raw_type = "String" },
   --['WTP_MAC_ADDRESS']        = { flowfilter = "apn_mac", dt_func = dt_format_mac_obj, db_type = "Number", db_raw_type = "Uint64" },
   ['DOMAIN_NAME']            = { flowfilter = "domain_name", dt_func = dt_format_generic, db_type = "String", db_raw_type = "String" },
   ['IS_FIRST_DUMP']          = { flowfilter = "first_flow_dump", dt_func = dt_format_first_flow_dump, db_type = "Boolean", db_raw_type = "Boolean" },
   
   --[[ TODO: this column is for the aggregated_flow_columns but the parsing Function
              only parses these columns, so a new logic to parse only the aggregated_flow_columns
              is needed 
   ]]
   --['NUM_FLOWS'] =            { flowfilter = "flows_number", dt_func = dt_format_high_number },
   
   -- Alert data
   ['ALERT_STATUS'] =         { flowfilter = "alert_status" },
   ['REQUIRE_ATTENTION'] =    { flowfilter = "require_attention" },
   ['USER_LABEL'] =           { flowfilter = "user_label" },
   ['USER_LABEL_TSTAMP'] =    { flowfilter = "user_label_tstamp" },
   ['SRC_PEER_ASN'] =         { flowfilter = "src_peer_asn" },
   ['DST_PEER_ASN'] =         { flowfilter = "dst_peer_asn" },
   ['INTERFACE_ROLE'] =         { flowfilter = "iface_role", simple_dt_func = simple_format_interface_role, db_type = "Number", db_raw_type = "Uint8" }
}
local aggregated_flow_columns = {
   ['FLOW_ID'] =              { flowfilter = "rowid", db_type = "Number", db_raw_type = "Uint64" },
   ['IP_PROTOCOL_VERSION'] =  { db_type = "Number", db_raw_type = "Uint8" },
   ['FIRST_SEEN'] =           { flowfilter = "first_seen",   dt_func = dt_format_time_with_highlight, db_type = "DateTime", db_raw_type = "DateTime" },
   ['LAST_SEEN'] =            { flowfilter = "last_seen",    dt_func = dt_format_time, db_type = "DateTime", db_raw_type = "DateTime" },
   ['VLAN_ID'] =              { flowfilter = "vlan_id",      dt_func = dt_format_vlan, db_type = "Number", db_raw_type = "Uint16"  },
   ['PACKETS'] =              { flowfilter = "packets",      dt_func = dt_format_pkts, db_type = "Number", db_raw_type = "Uint32" },
   ['TOTAL_BYTES'] =          { flowfilter = "bytes",        dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64"  },
   ['SRC2DST_BYTES'] =        { flowfilter = "src2dst_bytes", dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64"  },
   ['DST2SRC_BYTES'] =        { flowfilter = "dst2src_bytes", dt_func = dt_format_bytes, js_chart_func = "bytesToSize", db_type = "Number", db_raw_type = "Uint64"  },
   ['PROTOCOL'] =             { flowfilter = "l4proto",      dt_func = dt_format_l4_proto, simple_dt_func = l4_proto_to_string, db_type = "Number", db_raw_type = "Uint8" },
   ['IPV4_SRC_ADDR'] =        { flowfilter = "cli_ip",       dt_func = dt_format_src_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_src_ip, db_type = "Number", db_raw_type = "Uint32" },
   ['IPV6_SRC_ADDR'] =        { flowfilter = "cli_ip",       dt_func = dt_format_src_ip, where_func = "IPv6StringToNum", simple_dt_func = simple_format_src_ip, db_type = "IPv6", db_raw_type = "IPv6"  },
   ['IPV4_DST_ADDR'] =        { flowfilter = "srv_ip",       dt_func = dt_format_dst_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_dst_ip, db_type = "Number", db_raw_type = "Uint32" },
   ['IPV6_DST_ADDR'] =        { flowfilter = "srv_ip",       dt_func = dt_format_dst_ip, where_func = "IPv6StringToNum", simple_dt_func = simple_format_dst_ip, db_type = "IPv6", db_raw_type = "IPv6"  },
   ['IP_DST_PORT'] =          { flowfilter = "srv_port",     dt_func = dt_format_port, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_PROTO'] =             { flowfilter = "l7proto",      dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName, db_type = "Number", db_raw_type = "Uint16" },
   ['NTOPNG_INSTANCE_NAME'] = { db_type = "String", db_raw_type = "String" },
   ['SCORE'] =                { flowfilter = "score",        dt_func = dt_format_score, format_func = format_flow_score, i18n = i18n("score"), order = 9, db_type = "Number", db_raw_type = "Uint16" },
   ['L7_PROTO_MASTER'] =      { flowfilter = "l7proto_master", dt_func = dt_format_l7_proto, simple_dt_func = interface.getnDPIProtoName },
   ['NUM_FLOWS'] =            { flowfilter = "flows_number", dt_func = dt_format_high_number },
   ['FLOW_RISK'] =            { flowfilter = "flow_risk",    dt_func = dt_format_flow_risk, db_type = "Number", db_raw_type = "Uint64" },
   ['SRC_LABEL'] =            { flowfilter = "cli_name", db_type = "String", db_raw_type = "String" },
   ['DST_LABEL'] =            { flowfilter = "srv_name", db_type = "String", db_raw_type = "String" },
   ['SRC_MAC'] =              { flowfilter = "cli_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   ['DST_MAC'] =              { flowfilter = "srv_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   ['PROBE_IP'] =             { flowfilter = "probe_ip", dt_func = dt_format_probe, where_func = "toIPv6", db_type = "IPv6", db_raw_type = "IPv6" },
   ['EXPORTER_SITE'] =        { flowfilter = "site", dt_func = dt_format_site, db_type = "Number", db_raw_type = "Uint16" },
   ['SRC_COUNTRY_CODE'] =     { flowfilter = "cli_country", dt_func = dt_format_country, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_COUNTRY_CODE'] =     { flowfilter = "srv_country", dt_func = dt_format_country, db_type = "Number", db_raw_type = "Uint16" },
   ['SRC_ASN'] =              { flowfilter = "cli_asn", simple_dt_func = simple_format_src_asn, db_type = "Number", db_raw_type = "Uint32" },
   ['DST_ASN'] =              { flowfilter = "srv_asn", simple_dt_func = simple_format_dst_asn, db_type = "Number", db_raw_type = "Uint32" },
   ['INPUT_SNMP'] =           { flowfilter = "input_snmp", dt_func = dt_format_snmp_interface, db_type = "Number", db_raw_type = "Uint32" },
   ['OUTPUT_SNMP'] =          { flowfilter = "output_snmp", dt_func = dt_format_snmp_interface, db_type = "Number", db_raw_type = "Uint32" },
   ['SRC_NETWORK_ID'] =       { flowfilter = "cli_network", dt_func = dt_format_network, db_type = "Number", db_raw_type = "Uint32" },
   ['DST_NETWORK_ID'] =       { flowfilter = "srv_network", dt_func = dt_format_network, db_type = "Number", db_raw_type = "Uint32" },
   --['WLAN_SSID'] =            { flowfilter = "wlan_ssid", db_type = "String", db_raw_type = "String" },
   --['WTP_MAC_ADDRESS'] =      { flowfilter = "apn_mac", dt_func = dt_format_mac, db_type = "Number", db_raw_type = "Uint64" },
   ['SRC_SITE_ID'] =          { flowfilter = "cli_site", dt_func = dt_format_site, db_type = "Number", db_raw_type = "Uint16" },
   ['DST_SITE_ID'] =          { flowfilter = "srv_site", dt_func = dt_format_site, db_type = "Number", db_raw_type = "Uint16" },
   ['INTERFACE_ID'] =         { flowfilter = "ntopng_interface", dt_func = dt_format_interface, db_type = "Number", db_raw_type = "Uint16" },
}
-- Extra columns (e.g. result of SQL functions)
local additional_flow_columns = {
   ['bytes'] =                { flowfilter = "bytes",        dt_func = dt_format_bytes },
   ['packets'] =              { flowfilter = "packets",      dt_func = dt_format_pkts }, 
   ['IPV4_ADDR'] =            { flowfilter = "ip",           dt_func = dt_format_ip, select_func = "IPv4NumToString", where_func = "IPv4StringToNum", simple_dt_func = simple_format_ip },
   ['IPV6_ADDR'] =            { flowfilter = "ip",           dt_func = dt_format_ip, where_func = "IPv6StringToNum", simple_dt_func = simple_format_ip },
   ['NETWORK_ID'] =           { flowfilter = "network", dt_func = dt_format_network },
   ['ASN'] =                  { flowfilter = "asn", simple_dt_func = simple_format_asn },
   ['COUNTRY_CODE'] =         { flowfilter = "country", dt_func = dt_format_country },
   ['snmp_interface'] =       { flowfilter = "snmp_interface", dt_func = dt_format_snmp_interface },
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
   --"COMMUNITY_ID",
   "TAGS_MAP",
   "SRC_TAGS_MAP",
   "DST_TAGS_MAP",
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
   ["throughput"] = "ABS(LAST_SEEN - FIRST_SEEN) as TIME_DELTA, (" .. ternary(getThroughputType() == "bps", "TOTAL_BYTES", "PACKETS") .. " / (TIME_DELTA + 1)) * 8 as THROUGHPUT",
   ["duration"] = "ABS(LAST_SEEN - FIRST_SEEN) as DURATION",
   ["protocol_info_json"] = "PROTOCOL_INFO_JSON",
   ["alert_json"] = "ALERT_JSON"
}

historical_flow_utils.ordering_special_columns = {
   ["srv_ip"]   = {[4] = "IPv4NumToString(IPV4_DST_ADDR)", [6] = "IPv6NumToString(IPV6_DST_ADDR)"},
   ["cli_ip"]   = {[4] = "IPv4NumToString(IPV4_SRC_ADDR)", [6] = "IPv6NumToString(IPV6_SRC_ADDR)"},
   ["l7proto"]  = "L7_PROTO_MASTER",
   ["throughput"] = "THROUGHPUT"
}

historical_flow_utils.extra_where_flowfilters = {
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
   --["community_id"] = "COMMUNITY_ID",
   ["cli_fingerprint"] = "CLIENT_FINGERPRINT",
   --["tcp_fingerprint"] = "TCP_FINGERPRINT",
   ["duration"] = "DURATION",
   ["site"] = "EXPORTER_SITE", -- required?
   ["cli_site"] = "SRC_SITE_ID",
   ["srv_site"] = "DST_SITE_ID",
}

historical_flow_utils.topk_flowfilters_v4 = {
   ["host"]   = {
      "IPV4_DST_ADDR",
      "IPV4_SRC_ADDR",
   },
   ["protocol"] = {
      "L7_PROTO",
   }
}

historical_flow_utils.topk_flowfilters_v6 = {
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
      i18n_name = "queries.raw_flows",
      name = i18n("queries.raw_flows"),
      chart_type = "heatmap",
      chart_height = 60,
      chart =
         {
            {
               unit_measure = "",
               params = {
                  count = historical_ts_definitions and historical_ts_definitions.get_available_query_types()[4]
               }
            }
         },
   },
   {
      id = "raw_flows_thpt",
      i18n_name = "queries.raw_flows_thpt",
      name = i18n("queries.raw_flows_thpt"),
      chart_type = "histogram",
      chart =
         {
            {
               unit_measure = "bps",
               params = {
                  count = historical_ts_definitions and historical_ts_definitions.get_available_query_types()[1]
               }
            }
         },
   },
   {
      id = "raw_flows_bytes",
      i18n_name = "queries.raw_flows_bytes",
      name = i18n("queries.raw_flows_bytes"),
      chart_type = "histogram",
      chart =
         {
            {
               unit_measure = "bytes",
               params = {
                  count = historical_ts_definitions and historical_ts_definitions.get_available_query_types()[2]
               }
            }
         },
   },
   {
      id = "raw_flows_score",
      i18n_name = "queries.raw_flows_score",
      name = i18n("queries.raw_flows_score"),
      chart_type = "histogram",
      chart =
         {
            {
               params = {
                    count = historical_ts_definitions and historical_ts_definitions.get_available_query_types()[3]
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

function historical_flow_utils.get_flowfilters()
   local columns = historical_flow_utils.get_flow_columns()
   local filters = flowfilter_utils.defined_filters
   local flow_defined_filters = {}

   for _, v in pairs(columns) do
      if v.flowfilter and flowfilter_utils.defined_filters[v.flowfilter] then
         local flowfilter = flowfilter_utils.defined_filters[v.flowfilter]
         if not flowfilter.hide then
            flow_defined_filters[v.flowfilter] = flowfilter_utils.defined_filters[v.flowfilter]
         end
      end
   end

   -- Add extra tags
   flow_defined_filters["ip"] = flowfilter_utils.defined_filters["ip"]
   flow_defined_filters["name"] = flowfilter_utils.defined_filters["name"]
   flow_defined_filters["mac"] = flowfilter_utils.defined_filters["mac"]
   flow_defined_filters["snmp_interface"] = flowfilter_utils.defined_filters["snmp_interface"]
   flow_defined_filters["country"] = flowfilter_utils.defined_filters["country"]
   flow_defined_filters["l7_error_id"] = flowfilter_utils.defined_filters["l7_error_id"]
   -- flow_defined_filters["ja4_client"] = flowfilter_utils.defined_filters["ja4_client"]
   flow_defined_filters["issuer_dn"] = flowfilter_utils.defined_filters["issuer_dn"]
   flow_defined_filters["http_method"] = flowfilter_utils.defined_filters["http_method"]
   flow_defined_filters["http_url"] = flowfilter_utils.defined_filters["http_url"]
   flow_defined_filters["http_return"] = flowfilter_utils.defined_filters["http_return"]
   flow_defined_filters["user_agent"] = flowfilter_utils.defined_filters["user_agent"]
   flow_defined_filters["last_server"] = flowfilter_utils.defined_filters["last_server"]
   flow_defined_filters["netbios_name"] = flowfilter_utils.defined_filters["netbios_name"]
   flow_defined_filters["dns_query"] = flowfilter_utils.defined_filters["dns_query"]
   flow_defined_filters["dns_answer"] = flowfilter_utils.defined_filters["dns_answer"]
   flow_defined_filters["mdns_answer"] = flowfilter_utils.defined_filters["mdns_answer"]
   flow_defined_filters["mdns_name"] = flowfilter_utils.defined_filters["mdns_name"]
   flow_defined_filters["mdns_name_txt"] = flowfilter_utils.defined_filters["mdns_name_txt"]
   flow_defined_filters["mdns_ssid"] = flowfilter_utils.defined_filters["mdns_ssid"]
   flow_defined_filters["cli_location"] = flowfilter_utils.defined_filters["cli_location"]
   flow_defined_filters["srv_location"] = flowfilter_utils.defined_filters["srv_location"]
   flow_defined_filters["traffic_direction"] = flowfilter_utils.defined_filters["traffic_direction"]
   flow_defined_filters["confidence"] = flowfilter_utils.defined_filters["confidence"]
   flow_defined_filters["network_cidr"] = flowfilter_utils.defined_filters["network_cidr"]
   flow_defined_filters["srv_network_cidr"] = flowfilter_utils.defined_filters["srv_network_cidr"]
   flow_defined_filters["cli_network_cidr"] = flowfilter_utils.defined_filters["cli_network_cidr"]
   flow_defined_filters["duration"] = flowfilter_utils.defined_filters["duration"]
   flow_defined_filters["network"] = flowfilter_utils.defined_filters["network"]
   flow_defined_filters["retransmissions"] = flowfilter_utils.defined_filters["retransmissions"]
   flow_defined_filters["out_of_order"] = flowfilter_utils.defined_filters["out_of_order"]
   flow_defined_filters["lost"] = flowfilter_utils.defined_filters["lost"]
   flow_defined_filters["l4proto"] = flowfilter_utils.defined_filters["l4proto"]
   flow_defined_filters["post_nat_ipv4_src_addr"] = flowfilter_utils.defined_filters["post_nat_ipv4_src_addr"]
   flow_defined_filters["post_nat_src_port"] = flowfilter_utils.defined_filters["post_nat_src_port"]
   flow_defined_filters["post_nat_ipv4_dst_addr"] = flowfilter_utils.defined_filters["post_nat_ipv4_dst_addr"]
   flow_defined_filters["post_nat_dst_port"] = flowfilter_utils.defined_filters["post_nat_dst_port"]
   flow_defined_filters["verdict"] = flowfilter_utils.defined_filters["verdict"]
   flow_defined_filters["ndpi_fingerprint"] = flowfilter_utils.defined_filters["ndpi_fingerprint"]
   flow_defined_filters["community_id"] = flowfilter_utils.defined_filters["community_id"]
   flow_defined_filters["tcp_fingerprint"] = flowfilter_utils.defined_filters["tcp_fingerprint"]
   flow_defined_filters["apn_mac"] = flowfilter_utils.defined_filters["apn_mac"]
   flow_defined_filters["wlan_ssid"] = flowfilter_utils.defined_filters["wlan_ssid"]
   flow_defined_filters["site"] = flowfilter_utils.defined_filters["site"] -- required?
   flow_defined_filters["network_site"] = flowfilter_utils.defined_filters["network_site"]
   flow_defined_filters["cli_site"] = flowfilter_utils.defined_filters["cli_site"]
   flow_defined_filters["srv_site"] = flowfilter_utils.defined_filters["srv_site"]
   flow_defined_filters["asn"] = flowfilter_utils.defined_filters["asn"]
   flow_defined_filters["tag"] = flowfilter_utils.defined_filters["tag"]
   flow_defined_filters["cli_tag"] = flowfilter_utils.defined_filters["cli_tag"]
   flow_defined_filters["srv_tag"] = flowfilter_utils.defined_filters["srv_tag"]

   return flow_defined_filters
end

-- #####################################

function historical_flow_utils.get_flow_columns_to_flowfilters(aggregated, real_cols_only)

   local c2t = {}
   local t2c = {}

   if aggregated then
      for k, v in pairs(aggregated_flow_columns) do

         if v.flowfilter then
            c2t[k] = v.flowfilter
            t2c[v.flowfilter] = k
         end
      end
   else
      for k, v in pairs(flow_columns) do
         if v.flowfilter then
            c2t[k] = v.flowfilter
            t2c[v.flowfilter] = k
         end
      end
   end

   -- if real_cols_only is provided, exclude additional_flow_columns for historical flow export errors
   if not real_cols_only then
      for k, v in pairs(additional_flow_columns) do
         if v.flowfilter then 
            if not t2c[v.flowfilter] then -- flowfilter not already defined in real columns
               c2t[k] = v.flowfilter
               -- t2c[v.flowfilter] = k
            end
         end
      end
   end
      
   return c2t 
end

-- #####################################

-- Return a table with a list of DB columns for each flowfilter
-- Example:
-- { ["srv_ip"] = ["IPV4_DST_ADDR"], ["IPV6_DST_ADDR"], .. }
local function get_flow_flowfilters_to_columns(aggregated)
   local t2c = {}
   local c2t = historical_flow_utils.get_flow_columns_to_flowfilters(aggregated)

   for c, t in pairs(c2t) do
      if not t2c[t] then
         t2c[t] = {}
      end
      t2c[t][#t2c[t] + 1] = c
   end

   return t2c
end

-- Return DB select by flowfilter
-- Example: 'srv_ip' -> "IPV4_DST_ADDR, IPV6_DST_ADDR"
function historical_flow_utils.get_flow_select_by_flowfilter(filter_key, aggregated)
   local flowfilters_to_columns = get_flow_flowfilters_to_columns(aggregated)
   local s = ''

   ::next::
   if flowfilters_to_columns[filter_key] then
      for _, column in ipairs(flowfilters_to_columns[filter_key]) do
         if isEmptyString(s) then
            s = column
         else
            s = s .. ', ' .. column
         end
      end

      -- l7proto also includes l7proto_master
      if filter_key == 'l7proto' then
         filter_key = 'l7proto_master'
         goto next
      end
   end

   return s
end

-- Return DB column by flowfilter
-- First or ip_version-based in case of multiple
-- nil in case of undefined flowfilter
function historical_flow_utils.get_flow_column_by_flowfilter(filter_key, ip_version, aggregated)
   local flowfilters_to_columns = get_flow_flowfilters_to_columns(aggregated)

   if flowfilters_to_columns[filter_key] then
      if filter_key:ends('ip') and ip_version and ip_version == 6 then
         return flowfilters_to_columns[filter_key][2]
      end

      return flowfilters_to_columns[filter_key][1]
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
            new_column_name = extended_flow_columns[column_name]["flowfilter"]
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
            extended_flow_columns[column_name]["flowfilter"] then

            new_column_name = extended_flow_columns[column_name]["flowfilter"]

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

function historical_flow_utils.get_historical_url(label, flowfilter, value, add_hyperlink, title, add_copy_button)
   if not add_hyperlink then 
      return label
   else
      if add_copy_button ~= nil and add_copy_button then
         return "<span><button data-to-copy='"..value.."' class='copy-http-url btn btn-light btn-sm border ms-1' style='cursor: pointer;'><i class='fas fa-copy'></i></button> <a href=\"" .. ntop.getHttpPrefix() .. "/lua/pro/db_search.lua?" .. 
            flowfilter .. "=" .. value .. flowfilter_utils.SEPARATOR .. "eq\" " .. 
            ternary(title ~= nil, "title=\"" .. (title or "") .."\"", "") .. 
            " target='_blank'>" .. label .. "</a>"
      end
      return "<a href=\"" .. ntop.getHttpPrefix() .. "/lua/pro/db_search.lua?" .. 
            flowfilter .. "=" .. value .. flowfilter_utils.SEPARATOR .. "eq\" " .. 
            ternary(title ~= nil, "title=\"" .. (title or "") .."\"", "") .. 
            " target='_blank'>" .. label .. "</a>"
      
   end
end

-- #####################################

function historical_flow_utils.get_historical_mac(mac, info)
   -- live mac data (OLD URL)
   --return "<a href=\"" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?mac=" .. mac .. "\">" .. mac .. "</a>"

   local url = ntop.getHttpPrefix() .. "/lua/pro/db_search.lua?"
   
   -- Add ifid
   if info.interface_id then
      url = url .. "ifid=" .. info.interface_id .. "&"
   end
   
   -- Add epoch begin and end from filter or first_seen/last_seen
   if info.filter and info.filter.epoch_begin and info.filter.epoch_end then
      url = url .. "epoch_begin=" .. info.filter.epoch_begin .. "&"
      url = url .. "epoch_end=" .. info.filter.epoch_end .. "&"
   elseif info.first_seen and info.last_seen then
      url = url .. "epoch_begin=" .. info.first_seen.epoch .. "&"
      url = url .. "epoch_end=" .. info.last_seen.epoch .. "&"
   end
   
   -- Add parameters for hist flow filter
   url = url .. "aggregated=false&"
   url = url .. "count=traffic_presence&"
   url = url .. "query_preset=&"
   
   -- Add MAC addr for hist filtering
   local encoded_mac = string.gsub(mac, ":", "%%3A")
   url = url .. "mac=" .. encoded_mac .. "%3Beq"
   
   return "<a href=\"" .. url .. "\">" .. mac .. "</a>"
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
         local manufacturer = get_manufacturer_mac(info.cli_mac)
         local mac = historical_flow_utils.get_historical_mac(info.cli_mac, info)
         if not isEmptyString(manufacturer) then
            mac = string.format("%s (%s)", mac, manufacturer)
         end
         label = label .. " [ " .. mac .. " ]"
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
         local manufacturer = get_manufacturer_mac(info.srv_mac)
         local mac = historical_flow_utils.get_historical_mac(info.srv_mac, info)
         if not isEmptyString(manufacturer) then
            mac = string.format("%s (%s)", mac, manufacturer)
         end
         label = label .. " [ " .. mac .. " ]"
      end
   end

   return label
end

-- #####################################

function historical_flow_utils.getHistoricalProtocolLabel(record, add_hyperlinks)
  local json = require "dkjson"
  local label = ""

  local info = historical_flow_utils.format_clickhouse_record(record)
  local alert_json = json.decode(info["json"] or '') or {}
  
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
   label = label .. "[Confidence: " .. format_confidence_badge(alert_json.proto.confidence) .. "]"
  end

  return label
end

-- #####################################

function historical_flow_utils.simpleColumnFormatter(records, label)
   local extended_flow_columns = historical_flow_utils.get_extended_flow_columns()
   local process_records = records["results"] or {}

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
      flowfilter = column_options["flowfilter"]
    }
  end

  return data
end

-- #####################################

-- Given a flow returned from clickhouse, transform into the flow_alert format
function historical_flow_utils.convertFlowToAlert(flow)
   local alert = {}
   local alert_entities = require "alert_entities"

   if flow and table.len(flow) > 0 then
      local cli_ip = flow.IPV4_SRC_ADDR
      local srv_ip = flow.IPV4_DST_ADDR
      if cli_ip == '0.0.0.0' then
         cli_ip = flow.IPV6_SRC_ADDR
      end
      if srv_ip == '0.0.0.0' then
         srv_ip = flow.IPV4_DST_ADDR
      end
      alert = {
         cli2srv_bytes = flow.SRC2DST_BYTES,
         info = flow.INFO,
         tstamp_end_epoch = flow.LAST_SEEN,
         src2dst_tcp_flags = flow.SRC2DST_TCP_FLAGS,
         src2dst_dscp = flow.SRC2DST_DSCP,
         probe_ip = flow.PROBE_IP,
         tstamp_epoch = flow.FIRST_SEEN,
         cli_host_pool_id = flow.SRC_HOST_POOL_ID,
         alerts_map = flow.ALERTS_MAP,
         tstamp_end = flow.LAST_SEEN,
         srv_port = flow.IP_DST_PORT,
         cli_name = flow.SRC_LABEL,
         require_attention = flow.REQUIRE_ATTENTION,
         output_snmp = flow.OUTPUT_SNMP,
         interface_id = flow.INTERFACE_ID,
         first_seen = flow.FIRST_SEEN,
         user_label = flow.USER_LABEL,
         duration = flow.LAST_SEEN - flow.FIRST_SEEN,
         user_label_tstamp = flow.USER_LABEL_TSTAMP,
         minor_connection_state = flow.MINOR_CONNECTION_STATE,
         l7_proto = flow.L7_PROTO,
         major_connection_state = flow.MAJOR_CONNECTION_STATE,
         src_asn = flow.SRC_ASN,
         srv2cli_bytes = flow.DST2SRC_BYTES,
         srv_ip = srv_ip,
         ip_version = flow.IP_PROTOCOL_VERSION,
         severity = flow.SEVERITY,
         --community_id = flow.COMMUNITY_ID,
         cli_fingerprint = flow.CLIENT_FINGERPRINT,
         --tcp_fingerprint = flow.TCP_FINGERPRINT,
         srv_network = flow.DST_NETWORK_ID,
         is_cli_victim = flow.IS_CLI_VICTIM,
         l7_cat = flow.L7_CATEGORY,
         flow_risk_bitmap = flow.FLOW_RISK,
         is_srv_attacker = flow.IS_SRV_ATTACKER,
         is_srv_victim = flow.IS_SRV_VICTIM,
         score = flow.SCORE,
         qoe_score = flow.QOE_SCORE,
         l7_master_proto = flow.L7_PROTO_MASTER,
         vlan_id = flow.VLAN_ID,
         srv_location = flow.SERVER_LOCATION,
         srv_host_pool_id = flow.DST_HOST_POOL_ID,
         dst2src_dscp = flow.DST2SRC_DSCP,
         total_bytes = flow.TOTAL_BYTES,
         cli_network = flow.SRC_NETWORK_ID,
         is_cli_attacker = flow.IS_CLI_ATTACKER,
         cli_location = flow.CLIENT_LOCATION,
         srv_blacklisted = flow.IS_SRV_BLACKLISTED,
         tstamp = flow.tstamp,
         cli_port = flow.IP_SRC_PORT,
         proto = flow.PROTOCOL,
         cli_blacklisted = flow.IS_CLI_BLACKLISTED,
         srv_name = flow.DST_LABEL,
         packets = flow.PACKETS,
         ["flow_alerts_view.total_bytes"] = flow.TOTAL_BYTES,
         cli_ip = cli_ip,
         ntopng_instance_name = flow.NTOPNG_INSTANCE_NAME,
         alert_status = flow.ALERT_STATUS,
         input_snmp = flow.INPUT_SNMP,
         dst_asn = flow.DST_ASN,
         alert_json = flow.ALERT_JSON,
         dst2src_tcp_flags = flow.DST2SRC_TCP_FLAGS,
         entity_id = alert_entities.flow.entity_id,
      }
   end

   return alert
end

-- #####################################

-- Given a flow returned from clickhouse, transform into the flow_alert format
function historical_flow_utils.convertToLiveFlowFormat(historical_flow)
   -- TODO: currently only used for modbus, add here when needed the other info
   local flow = {}
   if historical_flow["PROTOCOL_INFO_JSON"] then
      require "flow_utils"
      local json = require "dkjson"
      local proto_info = json.decode(historical_flow["PROTOCOL_INFO_JSON"])
      if proto_info and proto_info.proto then
         local modbus_info = formatModbusInfo(proto_info.proto)
         local s7comm_info = formatS7CommInfo(proto_info.proto)
         local profinet_info = formatProfinetInfo(proto_info.proto)
         flow.modbus = modbus_info
         flow.s7comm = s7comm_info
         flow.profinet = profinet_info
         flow.bgp = proto_info.bgp
      end
   end

   return flow
end

-- #####################################

return historical_flow_utils

