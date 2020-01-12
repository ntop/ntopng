--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"
require "voip_utils"
require "graph_utils"
local tcp_flow_state_utils = require("tcp_flow_state_utils")
local format_utils = require("format_utils")
local flow_consts = require "flow_consts"
local json = require("dkjson")

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")
   require "snmp_utils"
end

local json = require ("dkjson")

-- #######################

function formatInterfaceId(id, idx, snmpdevice)
   if(id == 65535) then
      return("Unknown")
   else
      if(snmpdevice ~= nil) then
	 return('<A HREF="/lua/flows_stats.lua?deviceIP='..snmpdevice..'&'..idx..'='..id..'">'..id..'</A>')
      else
	 return(id)
      end
   end
end

-- #######################

-- Extracts the information serialized into status_info from the flow
-- user scripts
function flow2statusinfo(flow)
   local status_info = flow["status_info"]

   if(status_info and (string.sub(status_info, 1, 1) == "{")) then
      local res = json.decode(status_info)

      if(res ~= nil) then
         return(res)
      end
   end

   return(status_info)
end

-- #######################

function getFlowsFilter()
   -- Pagination
   local sortColumn  = _GET["sortColumn"]
   local sortOrder   = _GET["sortOrder"]
   local currentPage = _GET["currentPage"]
   local perPage     = _GET["perPage"]

   -- Other Filters
   local port        = _GET["port"]
   local application = _GET["application"]
   local category    = _GET["category"]
   local network_id  = _GET["network"]
   local traffic_profile = _GET["traffic_profile"]
   local traffic_type = _GET["traffic_type"]
   local flowhosts_type = _GET["flowhosts_type"]
   local ipversion    = _GET["version"]
   local l4proto      = _GET["l4proto"]
   local vlan        = _GET["vlan"]
   local username = _GET["username"]
   local host   = _GET["host"]
   local pid_name = _GET["pid_name"]
   local container   = _GET["container"]
   local pod         = _GET["pod"]
   local icmp_type   = _GET["icmp_type"]
   local icmp_code   = _GET["icmp_cod"]
   local flow_status = _GET["flow_status"]
   local deviceIP    = _GET["deviceIP"]
   local inIfIdx     = _GET["inIfIdx"]
   local outIfIdx    = _GET["outIfIdx"]
   local asn         = _GET["asn"]
   local tcp_state   = _GET["tcp_flow_state"]

   if sortColumn == nil or sortColumn == "column_" or sortColumn == "" then
      sortColumn = getDefaultTableSort("flows")
   elseif sortColumn ~= "column_" and  sortColumn ~= "" then
      tablePreferences("sort_flows", sortColumn)
   else
      sortColumn = "column_client"
   end

   if sortOrder == nil then
      sortOrder = getDefaultTableSortOrder("flows")
   elseif sortColumn ~= "column_" and sortColumn ~= "" then
      tablePreferences("sort_order_flows", sortOrder)
   end

   if currentPage == nil then
      currentPage = 1
   else
      currentPage = tonumber(currentPage)
   end

   if perPage == nil then
      perPage = getDefaultTableSize()
   else
      perPage = tonumber(perPage)
      tablePreferences("rows_number",perPage)
   end

   if port ~= nil then
      port = tonumber(port)
   end

   if network_id ~= nil then
      network_id = tonumber(network_id)
   end

   local to_skip = (currentPage - 1) * perPage

   local a2z = false
   if sortOrder == "desc" then
      a2z = false
   else a2z = true
   end

   local pageinfo = {
      ["perPage"] = perPage, ["currentPage"] = currentPage,
      ["sortOrder"] = sortOrder or "", ["sortColumn"] = sortColumn or "",
      ["toSkip"] = to_skip, ["maxHits"] = perPage,
      ["a2zSortOrder"] = a2z,
      ["hostFilter"] = host,
      ["portFilter"] = port,
      ["LocalNetworkFilter"] = network_id,
   }

   if application ~= nil and application ~= "" then
      pageinfo["l7protoFilter"] = interface.getnDPIProtoId(application)

   end

   if category ~= nil and category ~= "" then
      pageinfo["l7categoryFilter"] = interface.getnDPICategoryId(category)
   end

   if traffic_profile ~= nil then
      pageinfo["trafficProfileFilter"] = traffic_profile
   end

   if not isEmptyString(flowhosts_type) then
      if flowhosts_type == "local_origin_remote_target" then
	 pageinfo["clientMode"] = "local"
	 pageinfo["serverMode"] = "remote"
      elseif flowhosts_type == "local_only" then
	 pageinfo["clientMode"] = "local"
	 pageinfo["serverMode"] = "local"
      elseif flowhosts_type == "remote_origin_local_target" then
	 pageinfo["clientMode"] = "remote"
	 pageinfo["serverMode"] = "local"
      elseif flowhosts_type == "remote_only" then
	 pageinfo["clientMode"] = "remote"
	 pageinfo["serverMode"] = "remote"
      end
   end

   if not isEmptyString(traffic_type) then
      if traffic_type:contains("unicast") then
	 pageinfo["unicast"] = true
      else
	 pageinfo["unicast"] = false
      end

      if traffic_type:contains("one_way") then
	 pageinfo["unidirectional"] = true
      end
   end

   if not isEmptyString(flow_status) then
      if flow_status == "normal" then
	 pageinfo["alertedFlows"] = false
	 pageinfo["misbehavingFlows"] = false
	 pageinfo["filteredFlows"] = false
      elseif flow_status == "misbehaving" then
	 pageinfo["misbehavingFlows"] = true
      elseif flow_status == "alerted" then
	 pageinfo["alertedFlows"] = true
      elseif flow_status == "filtered" then
	 pageinfo["filteredFlows"] = true
      else
	 pageinfo["statusFilter"] = tonumber(flow_status)
      end
   end

   if not isEmptyString(ipversion) then
      pageinfo["ipVersion"] = tonumber(ipversion)
   end

   if not isEmptyString(l4proto) then
      pageinfo["L4Protocol"] = tonumber(l4proto)
   end

   if not isEmptyString(vlan) then
      pageinfo["vlanIdFilter"] = tonumber(vlan)
   end

   if not isEmptyString(username) then
      pageinfo["usernameFilter"] = username
   end

   if not isEmptyString(pid_name) then
      pageinfo["pidnameFilter"] = pid_name
   end

   if not isEmptyString(container) then
      pageinfo["container"] = container
   end

   if not isEmptyString(pod) then
      pageinfo["pod"] = pod
   end

   if not isEmptyString(deviceIP) then
      pageinfo["deviceIpFilter"] = deviceIP

      if not isEmptyString(inIfIdx) then
	 pageinfo["inIndexFilter"] = tonumber(inIfIdx)
      end

      if not isEmptyString(outIfIdx) then
	 pageinfo["outIndexFilter"] = tonumber(outIfIdx)
      end
   end

   if not isEmptyString(asn) then
      pageinfo["asnFilter"] = tonumber(asn)
   end

   pageinfo["icmp_type"] = tonumber(icmp_type)
   pageinfo["icmp_code"] = tonumber(icmp_code)

   if not isEmptyString(tcp_state) then
      pageinfo["tcpFlowStateFilter"] = tcp_state
   end

   return pageinfo
end

-- #######################

function handleCustomFlowField(key, value, snmpdevice)
   if key == 'TCP_FLAGS' then
      return(formatTcpFlags(value))
   elseif key == 'INPUT_SNMP' then
      return(formatInterfaceId(value, "inIfIdx", snmpdevice))
   elseif key == 'OUTPUT_SNMP' then
      return(formatInterfaceId(value, "outIfIdx", snmpdevice))
   elseif key == 'EXPORTER_IPV4_ADDRESS' or 
          key == 'NPROBE_IPV4_ADDRESS' then
      local res = getResolvedAddress(hostkey2hostinfo(value))

      local ret = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..value.."\">"

      if((res == "") or (res == nil)) then
	 ret = ret .. ipaddr
      else
	 ret = ret .. res
      end

      return(ret .. "</A>")
   elseif key == 'FLOW_USER_NAME' then
      elems = string.split(value, ';')

      if((elems ~= nil) and (#elems == 6)) then
          r = '<table class="table table-bordered table-striped">'
	  imsi = elems[1]
	  mcc = string.sub(imsi, 1, 3)

	  if(flow_consts.mobile_country_code[mcc] ~= nil) then
    	    mcc_name = " ["..flow_consts.mobile_country_code[mcc].."]"
	  else
   	    mcc_name = ""
	  end

          r = r .. "<th>"..i18n("flow_details.imsi").."</th><td>"..elems[1]..mcc_name
	  r = r .. " <A HREF='http://www.numberingplans.com/?page=analysis&sub=imsinr'><i class='fas fa-info'></i></A></td></tr>"
	  r = r .. "<th>"..i18n("flow_details.nsapi").."</th><td>".. elems[2].."</td></tr>"
	  r = r .. "<th>"..i18n("flow_details.gsm_cell_lac").."</th><td>".. elems[3].."</td></tr>"
	  r = r .. "<th>"..i18n("flow_details.gsm_cell_identifier").."</th><td>".. elems[4].."</td></tr>"
	  r = r .. "<th>"..i18n("flow_details.sac_service_area_code").."</th><td>".. elems[5].."</td></tr>"
	  r = r .. "<th>"..i18n("ip_address").."</th><td>".. ntop.inet_ntoa(elems[6]).."</td></tr>"
	  r = r .. "</table>"
	  return(r)
      else
         return(value)
      end
   elseif key == 'SIP_TRYING_TIME' or 
          key == 'SIP_RINGING_TIME' or 
          key == 'SIP_INVITE_TIME' or 
          key == 'SIP_INVITE_OK_TIME' or 
          key == 'SIP_INVITE_FAILURE_TIME' or 
          key == 'SIP_BYE_TIME' or 
          key == 'SIP_BYE_OK_TIME' or 
          key == 'SIP_CANCEL_TIME' or 
          key == 'SIP_CANCEL_OK_TIME' then
      if(value ~= '0') then
         return(formatEpoch(value))
      else
         return "0"
      end
   elseif key == 'RTP_IN_JITTER' or 
          key == 'RTP_OUT_JITTER' then
      if(value ~= nil and value ~= '0') then
         return(value/1000)
      else
         return 0
      end
   elseif key == 'RTP_IN_MAX_DELTA' or 
          key == 'RTP_OUT_MAX_DELTA' or 
          key == 'RTP_MOS' or 
          key == 'RTP_R_FACTOR' or 
          key == 'RTP_IN_MOS' or 
          key == 'RTP_OUT_MOS' or 
          key == 'RTP_IN_R_FACTOR' or
          key == 'RTP_OUT_R_FACTOR' or
          key == 'RTP_IN_TRANSIT' or 
          key == 'RTP_OUT_TRANSIT' then
      if(value ~= nil and value ~= '0') then
         return(value/100)
      else
         return 0
      end
   end

   -- Unformatted value

   if (type(value) == "boolean") then
      if (value) then 
         value = i18n("yes") 
      else 
         value = i18n("no") 
      end
   end

   return value
end


-- #######################

function formatTcpFlags(flags)
   if(flags == 0) then
      return("")
   end

   rsp = "<A HREF=\"http://en.wikipedia.org/wiki/Transmission_Control_Protocol\">"
   if((flags & 1) == 2)  then rsp = rsp .. " SYN "  end
   if((flags & 16) == 16) then rsp = rsp .. " ACK "  end
   if((flags & 1) == 1)  then rsp = rsp .. " FIN "  end
   if((flags & 4) == 4)  then rsp = rsp .. " RST "  end
   if((flags & 8) == 8 )  then rsp = rsp .. " PUSH " end

   return(rsp .. "</A>")
end

-- #######################

-- See Utils::l4proto2name()
l4_protocols = {
   ['IP'] = 0,
   ['ICMP'] = 1,
   ['IGMP'] = 2,
   ['TCP'] = 6,
   ['UDP'] = 17,
   ['IPv6'] = 41,
   ['RSVP'] = 46,
   ['GRE'] = 47,
   ['ESP'] = 50,
   ['IPv6-ICMP'] = 58,
   ['OSPF'] = 89,
   ['PIM'] = 103,
   ['VRRP'] = 112,
   ['HIP'] = 139,
}

function getL4ProtoName(proto_id)
  local proto_id = tonumber(proto_id)

  for k,v in pairs(l4_protocols) do
    if v == proto_id then
      return k
    end
  end

  return nil
end
 
 -- #######################
 
local dns_types = {
  ['A'] = 1,
  ['NS'] = 2,
  ['MD'] = 3,
  ['MF'] = 4,
  ['CNAME'] = 5,
  ['SOA'] = 6,
  ['MB'] = 7,
  ['MG'] = 8,
  ['MR'] = 9,
  ['NULL'] = 10,
  ['WKS'] = 11,
  ['PTR'] = 12,
  ['HINFO'] = 13,
  ['MINFO'] = 14,
  ['MX'] = 15,
  ['TXT'] = 16,
  ['AAAA'] = 28,
  ['A6'] = 38, 
  ['SPF'] = 99,
  ['AXFR'] = 252,
  ['MAILB'] = 253,
  ['MAILA'] = 254,
  ['ANY'] = 255,
}

-- #######################

function get_dns_type(dns_type_name)
   if dns_types[dns_type_name] then
      return dns_types[dns_type_name]
   else
      return 0
   end
end

-- #######################

function extractSIPCaller(caller)
   local i
   local j
   -- find string between \" and \"
   i = string.find(caller, "\\\"")
   if(i ~= nil) then
     j = string.find(caller, "\\\"",i+2)
     if(j ~= nil) then
       return string.sub(caller, i+2, j-1)
     end
   end
   -- find string between " and "
   i = string.find(caller, "\"")
   if(i ~= nil) then
     j = string.find(caller, "\"",i+1)
     if(j ~= nil) then
       return string.sub(caller, i+1, j-1)
     end
   end
   -- find string between : and @
   i = string.find(caller, ":")
   if(i ~= nil) then
     j = string.find(caller, "@",i+1)
     if(j ~= nil) then
       return string.sub(caller, i+1, j-1)
     end
   end
   return caller
 end

-- #######################

function map_failure_resp_code(fail_resp_code_string)
  if (fail_resp_code_string ~= nil) then
    if(fail_resp_code_string == "200") then
      return "OK"
    end
    if(fail_resp_code_string == "100") then
      return "TRYING"
    end
    if(fail_resp_code_string == "180") then
      return "RINGING"
    end
    if(tonumber(fail_resp_code_string) > 399) then
      return "FAILURE"
    end
  end
  return fail_resp_code_string
end


-- #######################

function getAlertTimeBounds(alert)
    local epoch_begin
    local epoch_end
    local half_interval = 1800
    local alert_tstamp = alert.alert_tstamp

    if alert.first_switched and alert.last_switched then
      epoch_begin = alert.first_switched - half_interval
      epoch_end = alert.last_switched + half_interval
   else
      epoch_begin = alert_tstamp - half_interval
      epoch_end = alert_tstamp + half_interval
   end

   return math.floor(epoch_begin), math.floor(epoch_end)
end

-- #######################

local function formatFlowHost(flow, cli_or_srv, historical_bounds, hyperlink_suffix)
  local host_name = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(flow, cli_or_srv)

  if historical_bounds then
    host_name = host_name .. string.format("&page=historical&epoch_begin=%u&epoch_end=%u&detail_view=top_l7_contacts", historical_bounds[1], historical_bounds[2])
  else
    host_name = host_name .. hyperlink_suffix
  end
  host_name = host_name.."\">"..shortenString(flowinfo2hostname(flow,cli_or_srv))

  if(flow[cli_or_srv .. ".systemhost"] == true) then
     host_name = host_name.." <i class='fas fa-flag' aria-hidden='true'></i>"
  end
  if(flow[cli_or_srv ..  ".blacklisted"] == true) then
     host_name = host_name.." <i class='fas fa-ban' aria-hidden='true' title='Blacklisted'></i>"
  end
  host_name = host_name.."</A>"

  return host_name
end

local function formatFlowPort(flow, cli_or_srv, port, historical_bounds)
    if not historical_bounds then
	return "<A HREF=\""..ntop.getHttpPrefix().."/lua/port_details.lua?port=" ..port.. "\">"..port.."</A>"
    end

    -- TODO port filter
    local port_url = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(flow,cli_or_srv)
    port_url = port_url .. string.format("&page=historical&epoch_begin=%u&epoch_end=%u&detail_view=flows&port=%u", historical_bounds[1], historical_bounds[2], port)
    port_url = port_url .. "\">" .. port .. "</A>"
    return port_url
end

function getFlowLabel(flow, show_macs, add_hyperlinks, historical_bounds, hyperlink_suffix, add_flag)
   if flow == nil then return "" end
   hyperlink_suffix = hyperlink_suffix or ""

   local cli_name = flowinfo2hostname(flow, "cli", true)
   local srv_name = flowinfo2hostname(flow, "srv", true)

   if((not isIPv4(cli_name)) and (not isIPv6(cli_name))) then cli_name = shortenString(cli_name) end
   if((not isIPv4(srv_name)) and (not isIPv6(srv_name))) then srv_name = shortenString(srv_name) end

   local cli_port
   local srv_port
   if flow["cli.port"] and flow["cli.port"] > 0 then cli_port = flow["cli.port"] end
   if flow["srv.port"] and flow["srv.port"] > 0 then srv_port = flow["srv.port"] end

   local srv_mac
   if(not isEmptyString(flow["srv.mac"]) and flow["srv.mac"] ~= "00:00:00:00:00:00") then
      srv_mac = flow["srv.mac"]
   end

   local cli_mac
   if(flow["cli.mac"] ~= nil and flow["cli.mac"]~= "" and flow["cli.mac"] ~= "00:00:00:00:00:00") then
      cli_mac = flow["cli.mac"]
   end

   if add_hyperlinks then
      cli_name = formatFlowHost(flow, "cli", historical_bounds, hyperlink_suffix)
      srv_name = formatFlowHost(flow, "srv", historical_bounds, hyperlink_suffix)

      if cli_port then
	 cli_port = formatFlowPort(flow, "cli", cli_port, historical_bounds)
      end

      if srv_port then
	 srv_port = formatFlowPort(flow, "srv", srv_port, historical_bounds)
      end

      if cli_mac then
	 cli_mac = "<A HREF=\""..ntop.getHttpPrefix().."/lua/hosts_stats.lua?mac=" ..cli_mac.."\">" ..cli_mac.."</A>"
      end

      if srv_mac then
	 srv_mac = "<A HREF=\""..ntop.getHttpPrefix().."/lua/hosts_stats.lua?mac=" ..srv_mac.."\">" ..srv_mac.."</A>"
      end

   end

   local label = ""

   if not isEmptyString(cli_name) then
      label = label..cli_name
   end

   if add_flag then
      local info = interface.getHostInfo(flow["cli.ip"], flow["cli.vlan"])

      if(info ~= nil) then
         label = label .. getFlag(info["country"])
      end
   end

   if cli_port then
      label = label..":"..cli_port
   end

   if show_macs and cli_mac then
      label = label.." [ "..cli_mac.." ]"
   end

   label = label.." <i class=\"fas fa-exchange-alt fa-lg\"  aria-hidden=\"true\"></i> "

   if not isEmptyString(srv_name) then
      label = label..srv_name
   end

   if add_flag then
      local info = interface.getHostInfo(flow["srv.ip"], flow["srv.vlan"])

      if(info ~= nil) then
         label = label .. getFlag(info["country"])
      end
   end

   if srv_port then
      label = label..":"..srv_port
   end

   if show_macs and srv_mac then
      label = label.." [ "..srv_mac.." ]"
   end

   return label
end

-- #######################

function getFlowKey(name)
   local s = flow_consts.flow_fields_description[name]

   if(s == nil) then
      -- Try to decode the name as <PEN>.<FIELD>
      -- then try to look up the name or directly the field
      -- in the rtemplate (pen is ignored).
      -- TODO: currently rtemplate is flat and PENs are ignored, we should add PEN there

      local pen, field = name:match("^(%d+)%.(%d+)$")
      local v = (rtemplate[tonumber(name)] or rtemplate[tonumber(field)])
      if(v == nil) then
	 return(name)
      end

      s = flow_consts.flow_fields_description[v]
   end
   
   if(s ~= nil) then
      s = string.gsub(s, "<", "&lt;")
      s = string.gsub(s, ">", "&gt;")
      return(s)
   else
      return(name)
   end
end

-- #######################

function fieldIDToFieldName(id)
  local id_num
  local name
  local pen_id = string.split(id, "%.")

  if pen_id then
    id_num = tonumber(pen_id[2])
  else
    id_num = tonumber(id)
  end

  if id_num then
    name = rtemplate[id_num]
  else
    name = id
  end

  return name
end

-- #######################

function isFieldProtocol(protocol, field)
   if not field or not protocol then 
      return false 
   end

   local key_name = fieldIDToFieldName(field)

   if not key_name then 
      return false 
   end

   if starts(key_name, protocol) then
      return true
   end
      
   return false
end

-- #######################

function removeProtocolFields(protocol, array)
   elements_to_remove = {}
   n = 0
   for key,value in pairs(array) do
     if(isFieldProtocol(protocol,key)) then
       elements_to_remove[n] = key
       n=n+1
     end
   end
   for key,value in pairs(elements_to_remove) do
     if(value ~= nil) then
       array[value] = nil
     end
   end
   return array
end

-- #######################

function isFlowValueDefined(info, field)
   if(info[field] ~= nil) then
      return true
   else
      for key,value in pairs(info) do
         local key_name = fieldIDToFieldName(key)
	 if(key_name == field) then
            return true
	 end
      end
   end

   return false
end

-- #######################

function getFlowValue(info, field)
   local return_value = "0"
   local value_original = "0"

   if(info[field] ~= nil) then
      return_value = handleCustomFlowField(field, info[field])
      value_original = info[field]
   else
      for key,value in pairs(info) do
         local key_name = fieldIDToFieldName(key)
	 if(key_name == field) then
	    return_value = handleCustomFlowField(key_name, value)
	    value_original = value
	 end
      end
   end
   
   return_value = string.gsub(return_value, "<", "&lt;")
   return_value = string.gsub(return_value, ">", "&gt;")
   return_value = string.gsub(return_value, "\"", "\\\"")

   -- io.write(field.." = ["..return_value..","..value_original.."]\n")
   return return_value , value_original
end

-- #######################

function mapCallState(call_state)
--  return call_state
  if(call_state == "CALL_STARTED") then return(i18n("flow_details.call_started"))
  elseif(call_state == "CALL_IN_PROGRESS") then return(i18n("flow_details.ongoing_call"))
  elseif(call_state == "CALL_COMPLETED") then return("<font color=green>"..i18n("flow_details.call_completed").."</font>")
  elseif(call_state == "CALL_ERROR") then return("<font color=red>"..i18n("flow_details.call_error").."</font>")
  elseif(call_state == "CALL_CANCELED") then return("<font color=orange>"..i18n("flow_details.call_canceled").."</font>")
  else return(call_state)
  end
end

-- #######################

function isThereProtocol(protocol, info)
   local found = 0
   
   for key,value in pairs(info) do
      if isFieldProtocol(protocol, key) then
	 found = 1
	 break
      end
   end
   
   return found
end

-- #######################

function isThereSIPCall(info)
  local retVal = 0
  local call_state = getFlowValue(info, "SIP_CALL_STATE")

  if((call_state ~= nil) and (call_state ~= "")) then
     retVal = 1     
  end
  
  return retVal
end

-- #######################

function getSIPInfo(infoPar)
  local called_party = ""
  local calling_party = ""
  local sip_found_flow
  local returnString = ""

  local infoFlow, posFlow, errFlow = json.decode(infoPar["moreinfo.json"], 1, nil)

  if (infoFlow ~= nil) then
    sip_found_flow = isThereSIPCall(infoFlow)
    if(sip_found_flow == 1) then
      called_party = getFlowValue(infoFlow, "SIP_CALLED_PARTY")
      calling_party = getFlowValue(infoFlow, "SIP_CALLING_PARTY")
      called_party = string.gsub(called_party, "\\\"","\"")
      calling_party = string.gsub(calling_party, "\\\"","\"")
      called_party = extractSIPCaller(called_party)
      calling_party = extractSIPCaller(calling_party)
      if(((called_party == nil) or (called_party == "")) and ((calling_party == nil) or (calling_party == ""))) then
        returnString = ""
      else
        returnString =  calling_party .. " <i class='fas fa-exchange-alt fa-sm' aria-hidden='true'></i> " .. called_party
      end
    end
  end
  return returnString
end

-- #######################

function getRTPInfo(infoPar)
  local call_id
  local returnString = ""

  local infoFlow, posFlow, errFlow = json.decode(infoPar["moreinfo.json"], 1, nil)

  if infoFlow ~= nil then
     call_id = getFlowValue(infoFlow, "RTP_SIP_CALL_ID")
     if tostring(call_id) ~= "" then
	call_id = "<i class='fas fa-phone fa-sm' aria-hidden='true' title='SIP Call-ID'></i>&nbsp;"..call_id
     else
	call_id = ""
     end
     returnString = call_id
  end

  return returnString
end

-- #######################

function getSIPTableRows(info)
   local string_table = ""
   local call_id = ""
   local call_id_ico = "<i class='fas fa-phone' aria-hidden='true'></i>&nbsp;"
   local called_party = ""
   local calling_party = ""
   local rtp_codecs = ""
   local sip_rtp_src_addr = 0
   local sip_rtp_dst_addr = 0
   local print_second = 0
   local print_second_2 = 0
   -- check if there is a SIP field
   sip_found = isThereProtocol("SIP", info)

   if(sip_found == 1) then
     sip_found = isThereSIPCall(info)
   end
   if(sip_found == 1) then
     string_table = string_table.."<tr><th colspan=3 class=\"info\" >"..i18n("flow_details.sip_protocol_information").."</th></tr>\n"
     call_id = getFlowValue(info, "SIP_CALL_ID")
     if((call_id == nil) or (call_id == "")) then
       string_table = string_table.."<tr id=\"call_id_tr\" style=\"display: none;\"><th width=33%> "..i18n("flow_details.call_id").." "..call_id_ico.."</th><td colspan=2><div id=call_id></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"call_id_tr\" style=\"display: table-row;\"><th width=33%> "..i18n("flow_details.call_id").." "..call_id_ico.."</th><td colspan=2><div id=call_id>" .. call_id .. "</div></td></tr>\n"
     end

     called_party = getFlowValue(info, "SIP_CALLED_PARTY")
     calling_party = getFlowValue(info, "SIP_CALLING_PARTY")
     called_party = string.gsub(called_party, "\\\"","\"")
     calling_party = string.gsub(calling_party, "\\\"","\"")
     called_party = extractSIPCaller(called_party)
     calling_party = extractSIPCaller(calling_party)
     if(((called_party == nil) or (called_party == "")) and ((calling_party == nil) or (calling_party == ""))) then
       string_table = string_table.."<tr id=\"called_calling_tr\" style=\"display: none;\"><th>"..i18n("flow_details.call_initiator").." <i class=\"fas fa-exchange-alt fa-lg\"></i> "..i18n("flow_details.called_party").."</th><td colspan=2><div id=calling_called_party></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"called_calling_tr\" style=\"display: table-row;\"><th>"..i18n("flow_details.call_initiator").." <i class=\"fas fa-exchange-alt fa-lg\"></i> "..i18n("flow_details.called_party").."</th><td colspan=2><div id=calling_called_party>" .. calling_party .. " <i class=\"fas fa-exchange-alt fa-lg\"></i> " .. called_party .. "</div></td></tr>\n"
     end

     rtp_codecs = getFlowValue(info, "SIP_RTP_CODECS")
     if((rtp_codecs == nil) or (rtp_codecs == "")) then
       string_table = string_table.."<tr id=\"rtp_codecs_tr\" style=\"display: none;\"><th width=33%>"..i18n("flow_details.rtp_codecs").."</th><td colspan=2> <div id=rtp_codecs></></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"rtp_codecs_tr\" style=\"display: table-row;\"><th width=33%>"..i18n("flow_details.rtp_codecs").."</th><td colspan=2> <div id=rtp_codecs>" .. rtp_codecs .. "</></td></tr>\n"
     end



     local string_table_1 = ""
     local string_table_2 = ""
     local string_table_3 = ""
     local string_table_4 = ""
     local string_table_5 = ""
     local show_rtp_stream = 0
     if((getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR")~="")) then
       sip_rtp_src_addr = 1
       string_table_1 = getFlowValue(info, "SIP_RTP_IPV4_SRC_ADDR")
       if (string_table_1 ~= "0.0.0.0") then
         sip_rtp_src_address_ip = string_table_1
         interface.select(ifname)
         rtp_host = interface.getHostInfo(string_table_1)
         if(rtp_host ~= nil) then
           string_table_1 = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..string_table_1.. "\">"
           string_table_1 = string_table_1..sip_rtp_src_address_ip
           string_table_1 = string_table_1.."</A>"
         end
       end
       show_rtp_stream = 1
     end

     if((getFlowValue(info, "SIP_RTP_L4_SRC_PORT")~=nil) and (getFlowValue(info, "SIP_RTP_L4_SRC_PORT")~="") and (sip_rtp_src_addr == 1)) then
       --string_table = string_table ..":"..getFlowValue(info, "SIP_RTP_L4_SRC_PORT")
	--string_table_2 = ":"..getFlowValue(info, "SIP_RTP_L4_SRC_PORT")
	sip_rtp_src_port = getFlowValue(info, "SIP_RTP_L4_SRC_PORT")
	string_table_2 = ":<A HREF=\""..ntop.getHttpPrefix().."/lua/port_details.lua?port="..sip_rtp_src_port.. "\">"
	string_table_2 = string_table_2..sip_rtp_src_port
	string_table_2 = string_table_2.."</A>"
	show_rtp_stream = 1
     end
     if((sip_rtp_src_addr == 1) or ((getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=""))) then
       --string_table = string_table.." <i class=\"fas fa-exchange-alt fa-lg\"></i> "
       string_table_3 = " <i class=\"fas fa-exchange-alt fa-lg\"></i> "
       show_rtp_stream = 1
     end
     if((getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~=nil) and (getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")~="")) then
       sip_rtp_dst_addr = 1
       string_table_4 = getFlowValue(info, "SIP_RTP_IPV4_DST_ADDR")
       if (string_table_4 ~= "0.0.0.0") then
         sip_rtp_dst_address_ip = string_table_4
         interface.select(ifname)
         rtp_host = interface.getHostInfo(string_table_4)
         if(rtp_host ~= nil) then
           string_table_4 = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..string_table_4.. "\">"
           string_table_4 = string_table_4..sip_rtp_dst_address_ip
           string_table_4 = string_table_4.."</A>"
         end
       end
       show_rtp_stream = 1
     end

     if((getFlowValue(info, "SIP_RTP_L4_DST_PORT")~=nil) and (getFlowValue(info, "SIP_RTP_L4_DST_PORT")~="") and (sip_rtp_dst_addr == 1)) then
	--string_table = string_table ..":"..getFlowValue(info, "SIP_RTP_L4_DST_PORT")
	--string_table_5 = ":"..getFlowValue(info, "SIP_RTP_L4_DST_PORT")
	sip_rtp_dst_port = getFlowValue(info, "SIP_RTP_L4_DST_PORT")
	string_table_5 = ":<A HREF=\""..ntop.getHttpPrefix().."/lua/port_details.lua?port="..sip_rtp_dst_port.. "\">"
	string_table_5 = string_table_5..sip_rtp_dst_port
	string_table_5 = string_table_5.."</A>"
	show_rtp_stream = 1
     end

     if (show_rtp_stream == 1) then
       string_table = string_table.."<tr id=\"rtp_stream_tr\" style=\"display: table-row;\"><th width=33%>"..i18n("flow_details.rtp_stream_peers").." (src <i class=\"fas fa-exchange-alt fa-lg\"></i> dst)</th><td colspan=2><div id=rtp_stream>"
     else
       string_table = string_table.."<tr id=\"rtp_stream_tr\" style=\"display: none;\"><th width=33%>"..i18n("flow_details.rtp_stream_peers").." (src <i class=\"fas fa-exchange-alt fa-lg\"></i> dst)</th><td colspan=2><div id=rtp_stream>"
     end
     string_table = string_table..string_table_1..string_table_2..string_table_3..string_table_4..string_table_5

     local rtp_flow_key  = interface.getFlowKey(sip_rtp_src_address_ip or "", tonumber(sip_rtp_src_port) or 0,
						sip_rtp_dst_address_ip or "", tonumber(sip_rtp_dst_port) or 0,
						17 --[[ UDP --]])
     -- TODO: fix
     if tonumber(rtp_flow_key) ~= nil and interface.findFlowByKeyAndHashId(tonumber(rtp_flow_key), 0) ~= nil then
	string_table = string_table..'&nbsp;'
	string_table = string_table.."<A HREF=\""..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key="..rtp_flow_key
	string_table = string_table.."&label="..sip_rtp_src_address_ip..":"..sip_rtp_src_port
	string_table = string_table.." <-> "
	string_table = string_table..sip_rtp_dst_address_ip..":"..sip_rtp_dst_port.."\">"
	string_table = string_table..'<span class="badge badge-info">'..i18n("flow_details.rtp_flow")..'</span></a>'
     end
     string_table = string_table.."</div></td></tr>\n"

     val, val_original = getFlowValue(info, "SIP_REASON_CAUSE")
     if(val_original ~= "0") then
        string_table = string_table.."<tr id=\"cbf_reason_cause_tr\" style=\"display: table-row;\"><th width=33%> "..i18n("flow_details.cancel_bye_failure_reason_cause").." </th><td colspan=2><div id=reason_cause>"
        string_table = string_table..val
     else
        string_table = string_table.."<tr id=\"cbf_reason_cause_tr\" style=\"display: none;\"><th width=33%> "..i18n("flow_details.cancel_bye_failure_reason_cause").." </th><td colspan=2><div id=reason_cause>"
     end
     string_table = string_table.."</div></td></tr>\n"
     if isFlowValueDefined(info, "SIP_C_IP") then
       string_table = string_table.."<tr id=\"sip_c_ip_tr\" style=\"display: table-row;\"><th width=33%> "..i18n("flow_details.c_ip_addresses").." </th><td colspan=2><div id=c_ip>" .. getFlowValue(info, "SIP_C_IP") .. "</div></td></tr>\n"
     end

     if((getFlowValue(info, "SIP_CALL_STATE") == nil) or (getFlowValue(info, "SIP_CALL_STATE") == "")) then
       string_table = string_table.."<tr id=\"sip_call_state_tr\" style=\"display: none;\"><th width=33%> "..i18n("flow_details.call_state").." </th><td colspan=2><div id=call_state></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"sip_call_state_tr\" style=\"display: table-row;\"><th width=33%> "..i18n("flow_details.call_state").." </th><td colspan=2><div id=call_state>" .. mapCallState(getFlowValue(info, "SIP_CALL_STATE")) .. "</div></td></tr>\n"
     end
   end
   return string_table
end

-- #######################

function getRTPTableRows(info)
   local string_table = ""
   -- check if there is a RTP field
   local rtp_found = isThereProtocol("RTP", info)

   if(rtp_found == 1) then
      -- SSRC
      string_table = string_table.."<tr><th colspan=3 class=\"info\" >"..i18n("flow_details.rtp_protocol_information").."</th></tr>\n"
      if isFlowValueDefined(info, "RTP_SSRC") then
	 sync_source_var = getFlowValue(info, "RTP_SSRC")
	 if((sync_source_var == nil) or (sync_source_var == "")) then
	    sync_source_hide = "style=\"display: none;\""
	 else
	    sync_source_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table.."<tr id=\"sync_source_id_tr\" "..sync_source_hide.." ><th> "..i18n("flow_details.sync_source_id").." </th><td colspan=2><div id=sync_source_id>" .. sync_source_var .. "</td></tr>\n"
      end
      
      -- ROUND-TRIP-TIME
      if isFlowValueDefined(info, "RTP_RTT") then	 
	 local rtp_rtt_var = getFlowValue(info, "RTP_RTT")
	 if((rtp_rtt_var == nil) or (rtp_rtt_var == "")) then
	    rtp_rtt_hide = "style=\"display: none;\""
	 else
	    rtp_rtt_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"rtt_id_tr\" "..rtp_rtt_hide.."><th>"..i18n("flow_details.round_trip_time").."</th><td colspan=2><span id=rtp_rtt>"
	 if((rtp_rtt_var ~= nil) and (rtp_rtt_var ~= "")) then
	    string_table = string_table .. rtp_rtt_var .. " ms "
	 end
	 string_table = string_table .. "</span> <span id=rtp_rtt_trend></span></td></tr>\n"
      end

      -- RTP-IN-TRASIT
      if isFlowValueDefined(info, "RTP_IN_TRANSIT") then	 
	 local rtp_in_transit = getFlowValue(info, "RTP_IN_TRANSIT")/100
	 local rtp_out_transit = getFlowValue(info, "RTP_OUT_TRANSIT")/100
	 if(((rtp_in_transit == nil) or (rtp_in_transit == "")) and ((rtp_out_transit == nil) or (rtp_out_transit == ""))) then
	    rtp_transit_hide = "style=\"display: none;\""
	 else
	    rtp_transit_hide = "style=\"display: table-row;\""
	 end
	 
	 string_table = string_table .. "<tr id=\"rtp_transit_id_tr\" "..rtp_transit_hide.."><th>"..i18n("flow_details.rtp_transit_in_out").."</th><td><div id=rtp_transit_in>"..getFlowValue(info, "RTP_IN_TRANSIT").."</div></td><td><div id=rtp_transit_out>"..getFlowValue(info, "RTP_OUT_TRANSIT").."</div></td></tr>\n"
      end
      
      -- TONES
      if isFlowValueDefined(info, "RTP_DTMF_TONES") then	 
	 local rtp_dtmf_var = getFlowValue(info, "RTP_DTMF_TONES")
	 if((rtp_dtmf_var == nil) or (rtp_dtmf_var == "")) then
	    rtp_dtmf_hide = "style=\"display: none;\""
	 else
	    rtp_dtmf_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"dtmf_id_tr\" ".. rtp_dtmf_hide .."><th>"..i18n("flow_details.dtmf_tones_sent").."</th><td colspan=2><span id=dtmf_tones>"..rtp_dtmf_var.."</span></td></tr>\n"
      end
	 
      -- FIRST REQUEST
      if isFlowValueDefined(info, "RTP_FIRST_SEQ") then         
	 local first_flow_sequence_var = getFlowValue(info, "RTP_FIRST_SEQ")
	 local last_flow_sequence_var = getFlowValue(info, "RTP_FIRST_SEQ")
	 if(((first_flow_sequence_var == nil) or (first_flow_sequence_var == "")) and ((last_flow_sequence_var == nil) or (last_flow_sequence_var == ""))) then
	    first_last_flow_sequence_hide = "style=\"display: none;\""
	 else
	    first_last_flow_sequence_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"first_last_flow_sequence_id_tr\" "..first_last_flow_sequence_hide.."><th>"..i18n("flow_details.first_last_flow_sequence").."</th><td><div id=first_flow_sequence>"..first_flow_sequence_var.."</div></td><td><div id=last_flow_sequence>"..last_flow_sequence_var.."</div></td></tr>\n"
      end
      
      -- CALL-ID
      if isFlowValueDefined(info, "RTP_SIP_CALL_ID") then	 
	 local sip_call_id_var = getFlowValue(info, "RTP_SIP_CALL_ID")
	 if((sip_call_id_var == nil) or (sip_call_id_var == "")) then
	    sip_call_id_hide = "style=\"display: none;\""
	 else
	    sip_call_id_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"sip_call_id_tr\" "..sip_call_id_hide.."><th> "..i18n("flow_details.sip_call_id").." <i class='fas fa-phone fa-sm' aria-hidden='true' title='SIP Call-ID'></i>&nbsp;</th><td colspan=2><div id=rtp_sip_call_id>" .. sip_call_id_var .. "</div></td></tr>\n"
      end
      
      -- TWO-WAY CALL-QUALITY INDICATORS
      string_table = string_table.."<tr><th>"..i18n("flow_details.call_quality_indicators").."</th><th>"..i18n("flow_details.forward").."</th><th>"..i18n("flow_details.reverse").."</th></tr>"
      -- JITTER
      if isFlowValueDefined(info, "RTP_IN_JITTER") then	 
	 local rtp_in_jitter = getFlowValue(info, "RTP_IN_JITTER")/100
	 local rtp_out_jitter = getFlowValue(info, "RTP_OUT_JITTER")/100
	 if(((rtp_in_jitter == nil) or (rtp_in_jitter == "")) and ((rtp_out_jitter == nil) or (rtp_out_jitter == ""))) then
	    rtp_out_jitter_hide = "style=\"display: none;\""
	 else
	    rtp_out_jitter_hide = "style=\"display: table-row;\""
	 end	 
	 string_table = string_table .. "<tr id=\"jitter_id_tr\" "..rtp_out_jitter_hide.."><th style=\"text-align:right\">"..i18n("flow_details.jitter").."</th><td><span id=jitter_in>"
	 
	 if((rtp_in_jitter ~= nil) and (rtp_in_jitter ~= "")) then
	    string_table = string_table .. rtp_in_jitter.." ms "
	 end
	 string_table = string_table .. "</span> <span id=jitter_in_trend></span></td><td><span id=jitter_out>"
	 
	 if((rtp_out_jitter ~= nil) and (rtp_out_jitter ~= "")) then
	    string_table = string_table .. rtp_out_jitter.." ms "
	 end
	 string_table = string_table .. "</span> <span id=jitter_out_trend></span></td></tr>\n"
      end
      
      -- PACKET LOSS
      if isFlowValueDefined(info, "RTP_IN_PKT_LOST") then	 
	 local rtp_in_pkt_lost = getFlowValue(info, "RTP_IN_PKT_LOST")
	 local rtp_out_pkt_lost = getFlowValue(info, "RTP_OUT_PKT_LOST")
	 if(((rtp_in_pkt_lost == nil) or (rtp_in_pkt_lost == "")) and ((rtp_out_pkt_lost == nil) or (rtp_out_pkt_lost == ""))) then
	    rtp_packet_loss_hide = "style=\"display: none;\""
	 else
	    rtp_packet_loss_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"rtp_packet_loss_id_tr\" "..rtp_packet_loss_hide.."><th style=\"text-align:right\">"..i18n("flow_details.lost_packets").."</th><td><span id=packet_lost_in>"
	 
	 if((rtp_in_pkt_lost ~= nil) and (rtp_in_pkt_lost ~= "")) then
	    string_table = string_table .. formatPackets(rtp_in_pkt_lost)
	 end
	 string_table = string_table .. "</span> <span id=packet_lost_in_trend></span></td><td><span id=packet_lost_out>"
	 
	 if((rtp_out_pkt_lost ~= nil) and (rtp_out_pkt_lost ~= "")) then
	    string_table = string_table .. formatPackets(rtp_out_pkt_lost)
	 end
	 string_table = string_table .. " </span> <span id=packet_lost_out_trend></span></td></tr>\n"
      end
      
      -- PACKET DROPS
      if isFlowValueDefined(info, "RTP_IN_PKT_DROP") then	 
	 local rtp_in_pkt_drop = getFlowValue(info, "RTP_IN_PKT_DROP")
	 local rtp_out_pkt_drop = getFlowValue(info, "RTP_OUT_PKT_DROP")
	 if(((rtp_in_pkt_drop == nil) or (rtp_in_pkt_drop == "")) and ((rtp_out_pkt_drop == nil) or (rtp_out_pkt_drop == ""))) then
	    rtp_pkt_drop_hide = "style=\"display: none;\""
	 else
	    rtp_pkt_drop_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"packet_drop_id_tr\" "..rtp_pkt_drop_hide.."><th style=\"text-align:right\">"..i18n("flow_details.dropped_packets").."</th><td><span id=packet_drop_in>"
	 if((rtp_in_pkt_drop ~= nil) and (rtp_in_pkt_drop ~= "")) then
	    string_table = string_table .. formatPackets(rtp_in_pkt_drop)
	 end
	 string_table = string_table .. "</span> <span id=packet_drop_in_trend></span></td><td><span id=packet_drop_out>"
	 
	 if((rtp_out_pkt_drop ~= nil) and (rtp_out_pkt_drop ~= "")) then
	    string_table = string_table .. formatPackets(rtp_out_pkt_drop)
	 end
	 string_table = string_table .. " </span> <span id=packet_drop_out_trend></span></td></tr>\n"
      end
      
      -- MAXIMUM DELTA BETWEEN CONSECUTIVE PACKETS
      if isFlowValueDefined(info, "RTP_IN_MAX_DELTA") then	 
	 local rtp_in_max_delta = getFlowValue(info, "RTP_IN_MAX_DELTA")
	 local rtp_out_max_delta = getFlowValue(info, "RTP_OUT_MAX_DELTA")
	 if(((rtp_in_max_delta == nil) or (rtp_in_max_delta == "")) and ((rtp_out_max_delta == nil) or (rtp_out_max_delta == ""))) then
	    rtp_max_delta_hide = "style=\"display: none;\""
	 else
	    rtp_max_delta_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"delta_time_id_tr\" "..rtp_max_delta_hide.."><th style=\"text-align:right\">"..i18n("flow_details.max_packet_interarrival_time").."</th><td><span id=max_delta_time_in>"
	 if((rtp_in_max_delta ~= nil) and (rtp_in_max_delta ~= "")) then
	    string_table = string_table .. rtp_in_max_delta .. " ms "
	 end
	 string_table = string_table .. "</span> <span id=max_delta_time_in_trend></span></td><td><span id=max_delta_time_out>"
	 if((rtp_out_max_delta ~= nil) and (rtp_out_max_delta ~= "")) then
	    string_table = string_table .. rtp_out_max_delta .. " ms "
	 end
	 string_table = string_table .. "</span> <span id=max_delta_time_out_trend></span></td></tr>\n"
      end
      
      -- PAYLOAD TYPE
      if isFlowValueDefined(info, "RTP_IN_PAYLOAD_TYPE") then	 
	 local rtp_payload_in_var  = formatRtpPayloadType(getFlowValue(info, "RTP_IN_PAYLOAD_TYPE"))
	 local rtp_payload_out_var = formatRtpPayloadType(getFlowValue(info, "RTP_OUT_PAYLOAD_TYPE"))
	 if(((rtp_payload_in_var == nil) or (rtp_payload_in_var == "")) and ((rtp_payload_out_var == nil) or (rtp_payload_out_var == ""))) then
	    rtp_payload_hide = "style=\"display: none;\""
	 else
	    rtp_payload_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"payload_id_tr\" "..rtp_payload_hide.."><th style=\"text-align:right\">"..i18n("flow_details.payload_type").."</th><td><div id=payload_type_in>"..rtp_payload_in_var.."</div></td><td><div id=payload_type_out>"..rtp_payload_out_var.."</div></td></tr>\n"
      end

      -- MOS
      if isFlowValueDefined(info, "RTP_IN_MOS") then		 
	 local rtp_in_mos = getFlowValue(info, "RTP_IN_MOS")
	 local rtp_out_mos = getFlowValue(info, "RTP_OUT_MOS")

	 if(rtp_in_mos == nil or rtp_in_mos == "") and (rtp_out_mos == nil or rtp_out_mos == "") then
	    quality_mos_hide = "style=\"display: none;\""
	 else
	    quality_mos_hide = "style=\"display: table-row;\""
	 end

	 string_table = string_table..
           "<tr id=\"quality_mos_id_tr\" ".. quality_mos_hide ..">"..
             "<th style=\"text-align:right\">"..i18n("flow_details.pseudo_mos").."</th>"..
             "<td><span id=mos_in_signal></span><span id=mos_in>"

	 if((rtp_in_mos ~= nil) and (rtp_in_mos ~= "")) then
	    string_table = string_table .. MosPercentageBar(rtp_in_mos)
	 end

	 string_table = string_table .. "</span> <span id=mos_in_trend></span></td>"
	 
	 string_table = string_table .. "<td><span id=mos_out_signal></span><span id=mos_out>"
	 if((rtp_out_mos ~= nil) and (rtp_out_mos ~= "")) then
	    string_table = string_table .. MosPercentageBar(rtp_out_mos)
	 end

	 string_table = string_table.."</span> <span id=mos_out_trend></span>"..
           "</td></tr>"
      end
      
      -- R_FACTOR
      if isFlowValueDefined(info, "RTP_IN_R_FACTOR") then
	 local rtp_in_r_factor = getFlowValue(info, "RTP_IN_R_FACTOR")/100
	 local rtp_out_r_factor = getFlowValue(info, "RTP_OUT_R_FACTOR")/100
	 
	 if(rtp_in_r_factor == nil or rtp_in_r_factor == "" or rtp_in_r_factor == "0") and (rtp_out_r_factor == nil or rtp_out_r_factor == "" or rtp_out_r_factor == "0") then
	    quality_r_factor_hide = "style=\"display: none;\""
	 else
	    quality_r_factor_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"quality_r_factor_id_tr\" ".. quality_r_factor_hide .."><th style=\"text-align:right\">"..i18n("flow_details.r_factor").."</th><td><span id=r_factor_in_signal></span><span id=r_factor_in>"
	 if((rtp_in_r_factor ~= nil) and (rtp_in_r_factor ~= "")) then
	    string_table = string_table .. RFactorPercentageBar(rtp_in_r_factor)
	 end
	 string_table = string_table .. "</span> <span id=r_factor_in_trend></span></td>"
	 
	 string_table = string_table .. "<td><span id=r_factor_out_signal></span><span id=r_factor_out>"
	 if((rtp_out_r_factor ~= nil) and (rtp_out_r_factor ~= "")) then
	    string_table = string_table .. RFactorPercentageBar(rtp_out_r_factor)
	 end
	 string_table = string_table .. "</span> <span id=r_factor_out_trend></span></td></tr>"
      end
   end
   return string_table
end

-- #######################

function getFlowQuota(ifid, info, as_client)
  local pool_id, quota_source

  if as_client then
    pool_id = info["cli.pool_id"]
    quota_source = info["cli.quota_source"]
  else
    pool_id = info["srv.pool_id"]
    quota_source = info["srv.quota_source"]
  end

  local master_proto, app_proto = splitProtocol(info["proto.ndpi"])
  app_proto = app_proto or master_proto

  local pools_stats = interface.getHostPoolsStats()
  local pool_stats = pools_stats and pools_stats[tonumber(pool_id)]
  local quota_and_protos = shaper_utils.getPoolProtoShapers(ifid, pool_id)

  if pool_stats ~= nil then
    local key = nil

    if quota_source == "policy_source_protocol" then
	proto_stats = pool_stats.ndpi

	-- determine if the quota is on the app or master proto
	if(quota_and_protos[master_proto] ~= nil) then
	    key = master_proto
	else
	    key = app_proto
	end
    elseif quota_source == "policy_source_category" then
	key = flow["proto.ndpi_cat"]
	proto_stats = nil
	category_stats = pool_stats.ndpi_categories
    elseif quota_source == "policy_source_pool" then
	key = "Default"
	proto_stats = nil
	category_stats = {default = pool_stats.cross_application}
    end

    if key ~= nil then
	local proto_info = nil
	if key ~= "Default" then
	    proto_info = quota_and_protos[key]
	else
	    proto_info = shaper_utils.getCrossApplicationShaper(ifid, pool_id)
	end

	if proto_info ~= nil then
	  return proto_info, proto_stats, category_stats
	end
    end
  end

  return nil
end

-- #######################

function printFlowQuota(ifid, info, as_client)
  local flow_quota, proto_stats, category_stats = getFlowQuota(ifid, info, as_client)
 
  if flow_quota ~= nil then
    print("<table style='width:100%; table-layout: fixed;'><tr>")
    print(string.gsub(printProtocolQuota(flow_quota, proto_stats, category_stats, {traffic=true, time=true}, true), "\n", ""))
    print("</tr></table>")
  else
    print(i18n("shaping.no_quota_applied"))
  end
end

-- #######################

function printFlowSNMPInfo(snmpdevice, input_idx, output_idx)
   local available_devices = get_snmp_devices()
   if available_devices == nil then available_devices = {} end

   for dev, _ in pairs(available_devices) do
      local snmp_device = require "snmp_device"
      snmp_device.init(dev)

      if dev == snmpdevice then
	 local community = get_snmp_community(dev)
	 local port_indexes = get_snmp_device_port_indexes(dev, community)
	 if port_indexes == nil then port_indexes = {} end

	 local snmpurl = "<A HREF='" .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_device_details.lua?host="..dev.. "'>"..dev.."</A>"

	 local snmp_interfaces = snmp_device.get_device()["interfaces"]
	 local inputurl, outputurl

	 local function prepare_interface_url(idx, port)
	    local ifurl

	    if port then
	       local label = port["index"]

	       if port["name"] and port["name"] ~= "" then
		  label = shortenString(port["name"])
	       end

	       ifurl = "<A HREF='" .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_interface_details.lua?host="..dev.."&snmp_port_idx="..port["index"].."'>"..label.."</A>"
	    else
	       ifurl = idx
	    end

	    return ifurl
	 end
 
	 local inputurl = prepare_interface_url(input_idx, snmp_interfaces[input_idx])
	 local outputurl = prepare_interface_url(output_idx, snmp_interfaces[output_idx])

	 print("<tr><th rowspan='2'>"..i18n("details.flow_snmp_localization").."</th><th>"..i18n("snmp.snmp_device").."</th><th>"..i18n("details.input_device_port").." / "..i18n("details.output_device_port").."</th></tr>")
	 print("<tr><td>"..snmpurl.."</td><td>"..inputurl.." / "..outputurl.."</td></tr>")
	 break
      end
   end

end

-- #######################

function printBlockFlowJs()
  print[[
  var block_flow_csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

  function block_flow(flow_key, flow_hash_id) {
    var url = "]] print(ntop.getHttpPrefix()) print[[/lua/pro/nedge/block_flow.lua";
    $.ajax({
      type: 'GET',
      url: url,
      cache: false,
      data: {
        csrf: block_flow_csrf,
        flow_key: flow_key,
        flow_hash_id: flow_hash_id,
      },
      success: function(content) {
        var data = jQuery.parseJSON(content);
        var row_id = flow_key + "_" + flow_hash_id;
        block_flow_csrf = data.csrf;
        if (data.status == "BLOCKED") {
          $('#'+row_id+'_info').find('.block-badge')
            .removeClass('badge-secondary')
            .addClass('badge-danger')
            .attr('title', ']] print(i18n("flow_details.flow_traffic_is_dropped")) print[[');
          $('#'+row_id+'_application, #'+row_id+'_l4, #'+row_id+'_client, #'+row_id+'_server')
            .css("text-decoration", "line-through");
        }
      },
      error: function(content) {
        console.log("error");
      }
    });
  }
  ]]
end

-- #######################

function printL4ProtoDropdown(base_url, page_params, l4_protocols)
   local l4proto = _GET["l4proto"]
   local l4proto_filter
   if not isEmptyString(l4proto) then
      l4proto_filter = '<span class="fas fa-filter"></span>'
   else
      l4proto_filter = ''
   end

   local l4proto_params = table.clone(page_params)
   l4proto_params["l4proto"] = nil
   -- Used to possibly remove tcp state filters when selecting a non-TCP l4 protocol
   local l4proto_params_non_tcp = table.clone(l4proto_params)
   if l4proto_params_non_tcp["tcp_flow_state"] then
      l4proto_params_non_tcp["tcp_flow_state"] = nil
   end

   print[[\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.l4_protocol")) print[[]] print(l4proto_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, l4proto_params_non_tcp)) print[[">]] print(i18n("flows_page.all_l4_protocols")) print[[</a></li>]]

    if l4_protocols then
       for key, value in pairsByKeys(l4_protocols, asc) do
	  print[[<li]]

	  if tonumber(l4proto) == key then
	     print(' class="active"')
	  end

	  print[[><a class="dropdown-item" href="]]

	  local l4_table = ternary(key ~= 6, l4proto_params_non_tcp, l4proto_params)

	  l4_table["l4proto"] = key
	  print(getPageUrl(base_url, l4_table))

	  print[[">]] print(l4_proto_to_string(key)) print [[ (]] print(string.format("%d", value.count)) print [[)</a></li>]]
      end
    end

    print[[</ul>]]
end

-- #######################

local function printDropdownEntries(entries, base_url, param_arr, param_filter, curr_filter)
   for _, htype in ipairs(entries) do
      if type(htype) == "string" then
        -- plain html
        print(htype)
        goto continue
      end

      param_arr[param_filter] = htype[1]
      print[[<li]]

      if htype[1] == curr_filter then print(' class="active"') end

      print[[><a class="dropdown-item" href="]] print(getPageUrl(base_url, param_arr)) print[[">]] print(htype[2]) print[[</a></li>]]
      ::continue::
   end
end

local function getParamFilter(page_params, param_name)
    if page_params[param_name] then
	return '<span class="fas fa-filter"></span>'
    end

    return ''
end

function printActiveFlowsDropdown(base_url, page_params, ifstats, flowstats, is_ebpf_flows)
    -- Local / Remote hosts selector
    local flowhosts_type_params = table.clone(page_params)
    flowhosts_type_params["flowhosts_type"] = nil

    print[['\
       <div class="btn-group">\
	  <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.hosts")) print(getParamFilter(page_params, "flowhosts_type")) print[[<span class="caret"></span></button>\
	  <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
	     <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, flowhosts_type_params)) print[[">]] print(i18n("flows_page.all_hosts")) print[[</a></li>\]]
       printDropdownEntries({
	  {"local_only", i18n("flows_page.local_only")},
	  {"remote_only", i18n("flows_page.remote_only")},
	  {"local_origin_remote_target", i18n("flows_page.local_cli_remote_srv")},
	  {"remote_origin_local_target", i18n("flows_page.local_srv_remote_cli")}
       }, base_url, flowhosts_type_params, "flowhosts_type", page_params.flowhosts_type)
    print[[\
	  </ul>\
       </div>\
    ']]

    -- Status selector
    local flow_status_params = table.clone(page_params)
    flow_status_params["flow_status"] = nil

    print[[, '\
       <div class="btn-group">\
	  <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("status")) print(getParamFilter(page_params, "flow_status")) print[[<span class="caret"></span></button>\
	  <ul class="dropdown-menu" role="menu">\
	  <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, flow_status_params)) print[[">]] print(i18n("flows_page.all_flows")) print[[</a></li>\]]

       local entries = {
	  {"normal", i18n("flows_page.normal")},
	  {"misbehaving", i18n("flows_page.all_misbehaving")},
	  {"alerted", i18n("flows_page.all_alerted")},
       }

       local status_stats = flowstats["status"]
       local first = true
       for _, s in pairsByKeys(flow_consts.status_types) do
          local t = s.status_id

          if(t > 0) then
             if status_stats[t] and status_stats[t].count > 0 then
               if first then
                 entries[#entries + 1] = '<li role="separator" class="divider"></li>'
                 entries[#entries + 1] = '<li class="dropdown-header">'.. i18n("flow_details.mibehaving_flows") ..'</li>'
                 first = false
               end
               entries[#entries + 1] = {string.format("%u", t), i18n(s.i18n_title) .. " ("..status_stats[t].count..")"}
             end
          end
       end

       if isBridgeInterface(ifstats) then
	  entries[#entries + 1] = {"filtered", i18n("flows_page.blocked")}
       end
     
       printDropdownEntries(entries, base_url, flow_status_params, "flow_status", page_params.flow_status)
    print[[\
	  </ul>\
       </div>\
    ']]

    if not is_ebpf_flows then
       if page_params["l4proto"] and page_params["l4proto"] == "6" then
	  -- TCP flow state filter
	  local tcp_state_params = table.clone(page_params)
	  tcp_state_params["tcp_flow_state"] = nil

	  print[[, '\
	   <div class="btn-group">\
	      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.tcp_state")) print(getParamFilter(page_params, "tcp_flow_state")) print[[<span class="caret"></span></button>\
	      <ul class="dropdown-menu" role="menu">\
	      <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, tcp_state_params)) print[[">]] print(i18n("flows_page.all_flows")) print[[</a></li>\]]

	  local entries = {}
	  for _, entry in pairs({"established", "connecting", "closed", "reset"}) do
	     entries[#entries + 1] = {entry, tcp_flow_state_utils.state2i18n(entry)}
	  end

	  printDropdownEntries(entries, base_url, tcp_state_params, "tcp_flow_state", page_params.tcp_flow_state)
	  print[[\
	      </ul>\
	   </div>\
	']]
       end

       -- Unidirectional flows selector
	local traffic_type_params = table.clone(page_params)
	traffic_type_params["traffic_type"] = nil

	print[[, '\
	   <div class="btn-group">\
	      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.direction")) print(getParamFilter(page_params, "traffic_type")) print[[<span class="caret"></span></button>\
	      <ul class="dropdown-menu" role="menu">\
		 <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("flows_page.all_flows")) print[[</a></li>\]]
	printDropdownEntries({
	      {"unicast", i18n("flows_page.non_multicast")},
	      {"broadcast_multicast", i18n("flows_page.multicast")},
	      {"one_way_unicast", i18n("flows_page.one_way_non_multicast")},
	      {"one_way_broadcast_multicast", i18n("flows_page.one_way_multicast")},
	   }, base_url, traffic_type_params, "traffic_type", page_params.traffic_type)
	print[[\
	      </ul>\
	   </div>\
	']]
    else -- is_ebpf_flows
	if not page_params.container then
	    -- POD filter
	    local pods = interface.getPodsStats()
	    local pods_params = table.clone(page_params)
	    pods_params["pod"] = nil

	    if not table.empty(pods) then
		print[[, '\
	       <div class="btn-group">\
		  <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("containers_stats.pod")) print(getParamFilter(page_params, "pod")) print[[<span class="caret"></span></button>\
		  <ul class="dropdown-menu" role="menu">\
		  ]]
		local entries = {}

		for pod_id, pod in pairsByKeys(pods) do
		    entries[#entries + 1] = {pod_id, shortenString(pod_id)}
		end

		print[[<li><a class="dropdown-item" href="]] print(getPageUrl(base_url, pods_params)) print[[">]] print(i18n("containers_stats.all_pods")) print[[</a></li>\]]
		printDropdownEntries(entries, base_url, pods_params, "pod", page_params.pod)

		print[[\
		  </ul>\
	       </div>\
	    ']]
	    end
	end

	if not page_params.pod then
	    -- Container filter
	    local containers = interface.getContainersStats()
	    local container_params = table.clone(page_params)
	    container_params["container"] = nil

	    if not table.empty(containers) then
		print[[, '\
	       <div class="btn-group">\
		  <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("containers_stats.container")) print(getParamFilter(page_params, "container")) print[[<span class="caret"></span></button>\
		  <ul class="dropdown-menu" role="menu">\
		  ]]
		local entries = {}

		for container_id, container in pairsByKeys(containers) do
		    entries[#entries + 1] = {container_id, format_utils.formatContainer(container.info)}
		end

		print[[<li><a class="dropdown-item" href="]] print(getPageUrl(base_url, container_params)) print[[">]] print(i18n("containers_stats.all_containers")) print[[</a></li>\]]
		printDropdownEntries(entries, base_url, container_params, "container", page_params.container)

		print[[\
		  </ul>\
	       </div>\
	    ']]
	    end
	end
    end

    -- L7 Application
    print(', \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("report.applications")..' ' .. getParamFilter(page_params, "application") .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="flow_dropdown">')
    print('<li><a class="dropdown-item" href="')

    local application_filter_params = table.clone(page_params)
    application_filter_params["application"] = nil
    print(getPageUrl(base_url, application_filter_params))
    print('">'..i18n("flows_page.all_proto")..'</a></li>')

    for key, value in pairsByKeys(flowstats["ndpi"], asc) do
       local class_active = ''
       if(key == page_params.application) then

	  class_active = ' class="active"'
       end
       print('<li '..class_active..'><a class="dropdown-item" href="')
       application_filter_params["application"] = key
       print(getPageUrl(base_url, application_filter_params))
       print('">'..key..'</a></li>')
    end

    print("</ul> </div>'")

    -- L7 Application Category
    print(', \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("users.categories")..' ' .. getParamFilter(page_params, "category") .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="flow_dropdown">')
    print('<li><a class="dropdown-item" href="')
    local category_filter_params = table.clone(page_params)
    category_filter_params["category"] = nil
    print(getPageUrl(base_url, category_filter_params))
    print('">'..i18n("flows_page.all_categories")..'</a></li>')
    local ndpicatstats = ifstats["ndpi_categories"]

    for key, value in pairsByKeys(ndpicatstats, asc) do
       local class_active = ''
       if(key == page_params.category) then
	  class_active = ' class="active"'
       end
       print('<li '..class_active..'><a class="dropdown-item" href="')
       category_filter_params["category"] = key
       print(getPageUrl(base_url, category_filter_params))
       print('">'..key..'</a></li>')
    end

    print("</ul> </div>'")

    -- Ip version selector
    local ipversion_params = table.clone(page_params)
    ipversion_params["version"] = nil

    print[[, '<div class="btn-group float-right">]]
    printIpVersionDropdown(base_url, ipversion_params)
    print [[</div>']]

    -- L4 protocol selector
    local l4proto_params = table.clone(page_params)
    l4proto_params["l4proto"] = nil

    print[[, '<div class="btn-group float-right">]]
    printL4ProtoDropdown(base_url, l4proto_params, flowstats["l4_protocols"])
    print [[</div>']]

    -- VLAN selector
    local vlan_params = table.clone(page_params)
    if ifstats.vlan then
       print[[, '<div class="btn-group float-right">]]
       printVLANFilterDropdown(base_url, vlan_params)
       print[[</div>']]
    end

    if ntop.isPro() then
      local hashname = "ntopng.prefs.profiles"
      local profiles = ntop.getHashKeysCache(hashname) or {}
      local profiles_defined = false

      for k,_ in pairsByKeys(profiles) do 
         profiles_defined = true
         break
      end

      if profiles_defined then
        -- Traffic Profiles
        print(', \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("traffic_profiles.traffic_profiles")..' ' .. getParamFilter(page_params, "traffic_profile") .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="flow_dropdown">')
        print('<li><a class="dropdown-item" href="')
        local traffic_profile_filter_params = table.clone(page_params)
        traffic_profile_filter_params["traffic_profile"] = nil
        print(getPageUrl(base_url, traffic_profile_filter_params))
        print('">'..i18n("traffic_profiles.all_profiles")..'</a></li>')

        for key,_ in pairsByKeys(profiles) do
	  local class_active = ''
	  if(key == page_params.traffic_profile) then
	    class_active = ' class="active"'
	  end
	  print('<li '..class_active..'><a class="dropdown-item" href="')
	  traffic_profile_filter_params["traffic_profile"] = key
	  print(getPageUrl(base_url, traffic_profile_filter_params))
	  print('">'..key..'</a></li>')
        end

        print("</ul> </div>'")
      end
    end

    if ntop.isPro() and interface.isPacketInterface() == false then
       printFlowDevicesFilterDropdown(base_url, vlan_params)
    end
end

-- #######################

function getFlowsTableTitle()
   local status_type
   if _GET["flow_status"] then
      local flow_status_id = tonumber(_GET["flow_status"])

      if(flow_status_id ~= nil) then
	 status_type = flow_consts.getStatusTitle(_GET["flow_status"])
      else
	 status_type = _GET["flow_status"]
      end
   end

   local filter = (_GET["application"] or _GET["category"] or _GET["vhost"] or status_type or "")
   local active_msg = ""
   local filter_msg = ""

   if not isEmptyString(filter) then
      filter_msg = i18n("flows_page."..filter)
      if isEmptyString(filter_msg) then
	 filter_msg = firstToUpper(filter)
      end
   end

   if not interface.isPacketInterface() then
      active_msg = i18n("flows_page.recently_active_flows", {filter=filter_msg})
   elseif interface.isPcapDumpInterface() then
      active_msg = i18n("flows_page.flows", {filter=filter_msg})
   else
      active_msg = i18n("flows_page.active_flows", {filter=filter_msg})
   end

   if(_GET["network_name"] ~= nil) then
      active_msg = active_msg .. i18n("network", {network=_GET["network_name"]})
   end

   if(_GET["inIfIdx"] ~= nil) then
      active_msg = active_msg .. " ["..i18n("flows_page.inIfIdx").." ".._GET["inIfIdx"].."]"
   end

   if(_GET["outIfIdx"] ~= nil) then
      active_msg = active_msg .. " ["..i18n("flows_page.outIfIdx").." ".._GET["outIfIdx"].."]"
   end

   if(_GET["deviceIP"] ~= nil) then
      active_msg = active_msg .. " ["..i18n("flows_page.device_ip").." ".._GET["deviceIP"].."]"
   end

   if(_GET["container"] ~= nil) then
      active_msg = active_msg .. " ["..i18n("containers_stats.container").." ".. format_utils.formatContainerFromId(_GET["container"]).."]"
   end

   if(_GET["pod"] ~= nil) then
      active_msg = active_msg .. " ["..i18n("containers_stats.pod").." ".. shortenString(_GET["pod"]) .."]"
   end

   if((_GET["icmp_type"] ~= nil) and (_GET["icmp_cod"] ~= nil)) then
      local is_v4 = true
      if(_GET["version"] ~= nil) then
      	 is_v4 = (_GET["version"] == "4")
      end

      local icmp_utils = require "icmp_utils"
      local icmp_label = icmp_utils.get_icmp_label(ternary(is_v4, 4, 6), _GET["icmp_type"], _GET["icmp_cod"])

      active_msg = active_msg .. " ["..icmp_label.."]"
   end

   if(_GET["tcp_flow_state"] ~= nil) then
      active_msg = active_msg .. " ["..tcp_flow_state_utils.state2i18n(_GET["tcp_flow_state"]).."]"
   end

   return active_msg
end

-- #######################

-- A one line flow description
-- This uses the information from flow.getInfo()
function shortFlowLabel(flow)
  local info = ""

  if not isEmptyString(flow["info"]) then
    info = " [" .. flow["info"] .. "]"
  end

  return(string.format("[%s] %s %s:%d -> %s:%s%s",
    flow["proto.ndpi"], flow["proto.l4"],
    flow["cli.ip"], flow["cli.port"],
    flow["srv.ip"], flow["srv.port"],
    info
  ))
end

-- #######################
