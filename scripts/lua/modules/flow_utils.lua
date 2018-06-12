--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"
require "voip_utils"
require "graph_utils"

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")
   require "snmp_utils"
end

local json = require ("dkjson")

-- http://www.itu.int/itudoc/itu-t/ob-lists/icc/e212_685.pdf
local mobile_country_code = {
["202"] = "Greece",
["204"] = "Netherlands (Kingdom of the)",
["206"] = "Belgium",
["208"] = "France",
["212"] = "Monaco (Principality of)",
["213"] = "Andorra (Principality of)",
["214"] = "Spain",
["216"] = "Hungary (Republic of)",
["218"] = "Bosnia and Herzegovina",
["219"] = "Croatia (Republic of)",
["220"] = "Serbia and Montenegro",
["222"] = "Italy",
["225"] = "Vatican City State",
["226"] = "Romania",
["228"] = "Switzerland (Confederation of)",
["230"] = "Czech Republic",
["231"] = "Slovak Republic",
["232"] = "Austria",
["234"] = "United Kingdom",
["235"] = "United Kingdom",
["238"] = "Denmark",
["240"] = "Sweden",
["242"] = "Norway",
["244"] = "Finland",
["246"] = "Lithuania (Republic of)",
["247"] = "Latvia (Republic of)",
["248"] = "Estonia (Republic of)",
["250"] = "Russian Federation",
["255"] = "Ukraine",
["257"] = "Belarus (Republic of)",
["259"] = "Moldova (Republic of)",
["260"] = "Poland (Republic of)",
["262"] = "Germany (Federal Republic of)",
["266"] = "Gibraltar",
["268"] = "Portugal",
["270"] = "Luxembourg",
["272"] = "Ireland",
["274"] = "Iceland",
["276"] = "Albania (Republic of)",
["278"] = "Malta",
["280"] = "Cyprus (Republic of)",
["282"] = "Georgia",
["283"] = "Armenia (Republic of)",
["284"] = "Bulgaria (Republic of)",
["286"] = "Turkey",
["288"] = "Faroe Islands",
["290"] = "Greenland (Denmark)",
["292"] = "San Marino (Republic of)",
["293"] = "Slovenia (Republic of)",
["294"] = "The Former Yugoslav Republic of Macedonia",
["295"] = "Liechtenstein (Principality of)",
["302"] = "Canada",
["308"] = "Saint Pierre and Miquelon",
["310"] = "United States of America",
["311"] = "United States of America",
["312"] = "United States of America",
["313"] = "United States of America",
["314"] = "United States of America",
["315"] = "United States of America",
["316"] = "United States of America",
["330"] = "Puerto Rico",
["332"] = "United States Virgin Islands",
["334"] = "Mexico",
["338"] = "Jamaica",
["340"] = "Martinique / Guadeloupe",
["342"] = "Barbados",
["344"] = "Antigua and Barbuda",
["346"] = "Cayman Islands",
["348"] = "British Virgin Islands",
["350"] = "Bermuda",
["352"] = "Grenada",
["354"] = "Montserrat",
["356"] = "Saint Kitts and Nevis",
["358"] = "SaintLucia",
["360"] = "Saint Vincent and the Grenadines",
["362"] = "Netherlands Antilles",
["363"] = "Aruba",
["364"] = "Bahamas (Commonwealth of the)",
["365"] = "Anguilla",
["366"] = "Dominica (Commonwealth of)",
["368"] = "Cuba",
["370"] = "Dominican Republic",
["372"] = "Haiti (Republic of)",
["374"] = "Trinidad and Tobago",
["376"] = "Turks and Caicos Islands",
["400"] = "Azerbaijani Republic",
["401"] = "Kazakhstan (Republic of)",
["402"] = "Bhutan (Kingdom of)",
["404"] = "India (Republic of)",
["410"] = "Pakistan (Islamic Republic of)",
["412"] = "Afghanistan",
["413"] = "Sri Lanka (Democratic Socialist Republic of)",
["414"] = "Myanmar (Union of)",
["415"] = "Lebanon",
["416"] = "Jordan (Hashemite Kingdom of)",
["417"] = "Syrian Arab Republic",
["418"] = "Iraq (Republic of)",
["419"] = "Kuwait (State of)",
["420"] = "Saudi Arabia (Kingdom of)",
["421"] = "Yemen (Republic of)",
["422"] = "Oman (Sultanate of)",
["424"] = "United Arab Emirates",
["425"] = "Israel (State of)",
["426"] = "Bahrain (Kingdom of)",
["427"] = "Qatar (State of)",
["428"] = "Mongolia",
["429"] = "Nepal",
["430"] = "United Arab Emirates b",
["431"] = "United Arab Emirates b",
["432"] = "Iran (Islamic Republic of)",
["434"] = "Uzbekistan (Republic of)",
["436"] = "Tajikistan (Republic of)",
["437"] = "Kyrgyz Republic",
["438"] = "Turkmenistan",
["440"] = "Japan",
["441"] = "Japan",
["450"] = "Korea (Republic of)",
["452"] = "Viet Nam (Socialist Republic of)",
["454"] = "Hongkong China",
["455"] = "Macao China",
["456"] = "Cambodia (Kingdom of)",
["457"] = "Lao People's Democratic Republic",
["460"] = "China (People's Republic of)",
["461"] = "China (People's Republic of)",
["466"] = "Taiwan",
["467"] = "Democratic People's Republic of Korea",
["470"] = "Bangladesh (People's Republic of)",
["472"] = "Maldives (Republic of)",
["502"] = "Malaysia",
["505"] = "Australia",
["510"] = "Indonesia (Republic of)",
["514"] = "Democratique Republic of Timor-Leste",
["515"] = "Philippines (Republic of the)",
["520"] = "Thailand",
["525"] = "Singapore (Republic of)",
["528"] = "Brunei Darussalam",
["530"] = "New Zealand",
["534"] = "Northern Mariana Islands (Commonwealth of the)",
["535"] = "Guam",
["536"] = "Nauru (Republic of)",
["537"] = "Papua New Guinea",
["539"] = "Tonga (Kingdom of)",
["540"] = "Solomon Islands",
["541"] = "Vanuatu (Republic of)",
["542"] = "Fiji (Republic of)",
["543"] = "Wallis and Futuna",
["544"] = "American Samoa",
["545"] = "Kiribati (Republic of)",
["546"] = "New Caledonia",
["547"] = "French Polynesia",
["548"] = "Cook Islands",
["549"] = "Samoa (Independent State of)",
["550"] = "Micronesia (Federated States of)",
["551"] = "Marshall Islands (Republic of the)",
["552"] = "Palau (Republic of)",
["602"] = "Egypt (Arab Republic of)",
["603"] = "Algeria (People's Democratic Republic of)",
["604"] = "Morocco (Kingdom of)",
["605"] = "Tunisia",
["606"] = "Libya",
["607"] = "Gambia (Republic of the)",
["608"] = "Senegal (Republic of)",
["609"] = "Mauritania (Islamic Republic of)",
["610"] = "Mali (Republic of)",
["611"] = "Guinea (Republic of)",
["612"] = "Cote d'Ivoire (Republic of)",
["613"] = "Burkina Faso",
["614"] = "Niger (Republic of the)",
["615"] = "Togolese Republic",
["616"] = "Benin (Republic of)",
["617"] = "Mauritius (Republic of)",
["618"] = "Liberia (Republic of)",
["619"] = "Sierra Leone",
["620"] = "Ghana",
["621"] = "Nigeria (Federal Republic of)",
["622"] = "Chad (Republic of)",
["623"] = "Central African Republic",
["624"] = "Cameroon (Republic of)",
["625"] = "Cape Verde (Republic of)",
["626"] = "Sao Tome and Principe (Democratic Republic of)",
["627"] = "Equatorial Guinea (Republic of)",
["628"] = "Gabonese Republic",
["629"] = "Congo (Republic of the)",
["630"] = "Democratic Republic of the Congo",
["631"] = "Angola (Republic of)",
["632"] = "Guinea-Bissau (Republic of)",
["633"] = "Seychelles (Republic of)",
["634"] = "Sudan (Republic of the)",
["635"] = "Rwandese Republic",
["636"] = "Ethiopia (Federal Democratic Republic of)",
["637"] = "Somali Democratic Republic",
["638"] = "Djibouti (Republic of)",
["639"] = "Kenya (Republic of)",
["640"] = "Tanzania (United Republic of)",
["641"] = "Uganda (Republic of)",
["642"] = "Burundi (Republic of)",
["643"] = "Mozambique (Republic of)",
["645"] = "Zambia (Republic of)",
["646"] = "Madagascar (Republic of)",
["647"] = "Reunion (French Department of)",
["648"] = "Zimbabwe (Republic of)",
["649"] = "Namibia (Republic of)",
["650"] = "Malawi",
["651"] = "Lesotho (Kingdom of)",
["652"] = "Botswana (Republic of)",
["653"] = "Swaziland (Kingdom of)",
["654"] = "Comoros (Union of the)",
["655"] = "South Africa (Republic of)",
["657"] = "Eritrea",
["702"] = "Belize",
["704"] = "Guatemala (Republic of)",
["706"] = "El Salvador (Republic of)",
["708"] = "Honduras (Republic of)",
["710"] = "Nicaragua",
["712"] = "Costa Rica",
["714"] = "Panama (Republic of)",
["716"] = "Peru",
["722"] = "Argentine Republic",
["724"] = "Brazil (Federative Republic of)",
["730"] = "Chile",
["732"] = "Colombia (Republic of)",
["734"] = "Venezuela (Bolivarian Republic of)",
["736"] = "Bolivia (Republic of)",
["738"] = "Guyana",
["740"] = "Ecuador",
["742"] = "French Guiana (French Department of)",
["744"] = "Paraguay (Republic of)",
["746"] = "Suriname (Republic of)",
["748"] = "Uruguay (Eastern Republic of)",
["412"] = "Afghanistan",
["276"] = "Albania (Republic of)",
["603"] = "Algeria (People's Democratic Republic of)",
["544"] = "American Samoa",
["213"] = "Andorra (Principality of)",
["631"] = "Angola (Republic of)",
["365"] = "Anguilla",
["344"] = "Antigua and Barbuda",
["722"] = "Argentine Republic",
["283"] = "Armenia (Republic of)",
["363"] = "Aruba",
["505"] = "Australia",
["232"] = "Austria",
["400"] = "Azerbaijani Republic",
["364"] = "Bahamas (Commonwealth of the)",
["426"] = "Bahrain (Kingdom of)",
["470"] = "Bangladesh (People's Republic of)",
["342"] = "Barbados",
["257"] = "Belarus (Republic of)",
["206"] = "Belgium",
["702"] = "Belize",
["616"] = "Benin (Republic of)",
["350"] = "Bermuda",
["402"] = "Bhutan (Kingdom of)",
["736"] = "Bolivia (Republic of)",
["218"] = "Bosnia and Herzegovina",
["652"] = "Botswana (Republic of)",
["724"] = "Brazil (Federative Republic of)",
["348"] = "British Virgin Islands",
["528"] = "Brunei Darussalam",
["284"] = "Bulgaria (Republic of)",
["613"] = "Burkina Faso",
["642"] = "Burundi (Republic of)",
["456"] = "Cambodia (Kingdom of)",
["624"] = "Cameroon (Republic of)",
["302"] = "Canada",
["625"] = "Cape Verde (Republic of)",
["346"] = "Cayman Islands",
["623"] = "Central African Republic",
["622"] = "Chad (Republic of)",
["730"] = "Chile",
["461"] = "China (People's Republic of)",
["460"] = "China (People's Republic of)",
["732"] = "Colombia (Republic of)",
["654"] = "Comoros (Union of the)",
["629"] = "Congo (Republic of the)",
["548"] = "Cook Islands",
["712"] = "Costa Rica",
["612"] = "Cote d'Ivoire (Republic of)",
["219"] = "Croatia (Republic of)",
["368"] = "Cuba",
["280"] = "Cyprus (Republic of)",
["230"] = "Czech Republic",
["467"] = "Democratic People's Republic of Korea",
["630"] = "Democratic Republic of the Congo",
["514"] = "Democratique Republic of Timor-Leste",
["238"] = "Denmark",
["638"] = "Djibouti (Republic of)",
["366"] = "Dominica (Commonwealth of)",
["370"] = "Dominican Republic",
["740"] = "Ecuador",
["602"] = "Egypt (Arab Republic of)",
["706"] = "El Salvador (Republic of)",
["627"] = "Equatorial Guinea (Republic of)",
["657"] = "Eritrea",
["248"] = "Estonia (Republic of)",
["636"] = "Ethiopia (Federal Democratic Republic of)",
["288"] = "Faroe Islands",
["542"] = "Fiji (Republic of)",
["244"] = "Finland",
["208"] = "France",
["742"] = "French Guiana (French Department of)",
["547"] = "French Polynesia",
["628"] = "Gabonese Republic",
["607"] = "Gambia (Republic of the)",
["282"] = "Georgia",
["262"] = "Germany (Federal Republic of)",
["620"] = "Ghana",
["266"] = "Gibraltar",
["202"] = "Greece",
["290"] = "Greenland (Denmark)",
["352"] = "Grenada",
["340"] = "Guadeloupe (French Department of)",
["535"] = "Guam",
["704"] = "Guatemala (Republic of)",
["611"] = "Guinea (Republic of)",
["632"] = "Guinea-Bissau (Republic of)",
["738"] = "Guyana",
["372"] = "Haiti (Republic of)",
["708"] = "Honduras (Republic of)",
["454"] = "Hongkong China",
["216"] = "Hungary (Republic of)",
["274"] = "Iceland",
["404"] = "India (Republic of)",
["510"] = "Indonesia (Republic of)",
["901"] = "International Mobile shared code c",
["432"] = "Iran (Islamic Republic of)",
["418"] = "Iraq (Republic of)",
["272"] = "Ireland",
["425"] = "Israel (State of)",
["222"] = "Italy",
["338"] = "Jamaica",
["441"] = "Japan",
["440"] = "Japan",
["416"] = "Jordan (Hashemite Kingdom of)",
["401"] = "Kazakhstan (Republic of)",
["639"] = "Kenya (Republic of)",
["545"] = "Kiribati (Republic of)",
["450"] = "Korea (Republic of)",
["419"] = "Kuwait (State of)",
["437"] = "Kyrgyz Republic",
["457"] = "Lao People's Democratic Republic",
["247"] = "Latvia (Republic of)",
["415"] = "Lebanon",
["651"] = "Lesotho (Kingdom of)",
["618"] = "Liberia (Republic of)",
["606"] = "Libya",
["295"] = "Liechtenstein (Principality of)",
["246"] = "Lithuania (Republic of)",
["270"] = "Luxembourg",
["455"] = "Macao China",
["646"] = "Madagascar (Republic of)",
["650"] = "Malawi",
["502"] = "Malaysia",
["472"] = "Maldives (Republic of)",
["610"] = "Mali (Republic of)",
["278"] = "Malta",
["551"] = "Marshall Islands (Republic of the)",
["340"] = "Martinique (French Department of)",
["609"] = "Mauritania (Islamic Republic of)",
["617"] = "Mauritius (Republic of)",
["334"] = "Mexico",
["550"] = "Micronesia (Federated States of)",
["259"] = "Moldova (Republic of)",
["212"] = "Monaco (Principality of)",
["428"] = "Mongolia",
["354"] = "Montserrat",
["604"] = "Morocco (Kingdom of)",
["643"] = "Mozambique (Republic of)",
["414"] = "Myanmar (Union of)",
["649"] = "Namibia (Republic of)",
["536"] = "Nauru (Republic of)",
["429"] = "Nepal",
["204"] = "Netherlands (Kingdom of the)",
["362"] = "Netherlands Antilles",
["546"] = "New Caledonia",
["530"] = "New Zealand",
["710"] = "Nicaragua",
["614"] = "Niger (Republic of the)",
["621"] = "Nigeria (Federal Republic of)",
["534"] = "Northern Mariana Islands (Commonwealth of the)",
["242"] = "Norway",
["422"] = "Oman (Sultanate of)",
["410"] = "Pakistan (Islamic Republic of)",
["552"] = "Palau (Republic of)",
["714"] = "Panama (Republic of)",
["537"] = "Papua New Guinea",
["744"] = "Paraguay (Republic of)",
["716"] = "Peru",
["515"] = "Philippines (Republic of the)",
["260"] = "Poland (Republic of)",
["268"] = "Portugal",
["330"] = "Puerto Rico",
["427"] = "Qatar (State of)",
["8XX"] = "Reserved a 0XX Reserved a 1XX Reserved a",
["647"] = "Reunion (French Department of) 226 Romania",
["250"] = "Russian Federation",
["635"] = "Rwandese Republic",
["356"] = "Saint Kitts and Nevis",
["358"] = "SaintLucia",
["308"] = "Saint Pierre and Miquelon",
["360"] = "Saint Vincent and the Grenadines",
["549"] = "Samoa (Independent State of)",
["292"] = "San Marino (Republic of)",
["626"] = "Sao Tome and Principe (Democratic Republic of)",
["420"] = "Saudi Arabia (Kingdom of)",
["608"] = "Senegal (Republic of)",
["220"] = "Serbia and Montenegro",
["633"] = "Seychelles (Republic of)",
["619"] = "Sierra Leone",
["525"] = "Singapore (Republic of)",
["231"] = "Slovak Republic",
["293"] = "Slovenia (Republic of)",
["540"] = "Solomon Islands",
["637"] = "Somali Democratic Republic",
["655"] = "South Africa (Republic of)",
["214"] = "Spain",
["413"] = "Sri Lanka (Democratic Socialist Republic of)",
["634"] = "Sudan (Republic of the)",
["746"] = "Suriname (Republic of)",
["653"] = "Swaziland (Kingdom of)",
["240"] = "Sweden",
["228"] = "Switzerland (Confederation of)",
["417"] = "Syrian Arab Republic",
["466"] = "Taiwan",
["436"] = "Tajikistan (Republic of)",
["640"] = "Tanzania (United Republic of)",
["520"] = "Thailand",
["294"] = "The Former Yugoslav Republic of Macedonia",
["615"] = "Togolese Republic",
["539"] = "Tonga (Kingdom of)",
["374"] = "Trinidad and Tobago",
["605"] = "Tunisia",
["286"] = "Turkey",
["438"] = "Turkmenistan",
["376"] = "Turks and Caicos Islands",
["641"] = "Uganda (Republic of)",
["255"] = "Ukraine",
["424"] = "United Arab Emirates",
["430"] = "United Arab Emirates b",
["431"] = "United Arab Emirates b",
["235"] = "United Kingdom",
["234"] = "United Kingdom",
["310"] = "United States of America",
["316"] = "United States of America",
["311"] = "United States of America",
["312"] = "United States of America",
["313"] = "United States of America",
["314"] = "United States of America",
["315"] = "United States of America",
["332"] = "United States Virgin Islands",
["748"] = "Uruguay (Eastern Republic of)",
["434"] = "Uzbekistan (Republic of)",
["541"] = "Vanuatu (Republic of)",
["225"] = "Vatican City State",
["734"] = "Venezuela (Bolivarian Republic of)",
["452"] = "Viet Nam (Socialist Republic of)",
["543"] = "Wallis and Futuna",
["421"] = "Yemen (Republic of)",
["645"] = "Zambia (Republic of)",
["648"] = "Zimbabwe (Republic of)",
}

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

function handleCustomFlowField(key, value, snmpdevice)
   if((key == 'TCP_FLAGS') or (key == '6')) then
      return(formatTcpFlags(value))
   elseif((key == 'INPUT_SNMP') or (key == '10')) then
      return(formatInterfaceId(value, "inIfIdx", snmpdevice))
   elseif((key == 'OUTPUT_SNMP') or (key == '14')) then
      return(formatInterfaceId(value, "outIfIdx", snmpdevice))
   elseif((key == 'EXPORTER_IPV4_ADDRESS') or (key == 'NPROBE_IPV4_ADDRESS') or (key == '130') or (key == '57943')) then
      local res = getResolvedAddress(hostkey2hostinfo(value))

      local ret = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..value.."\">"

      if((res == "") or (res == nil)) then
	 ret = ret .. ipaddr
      else
	 ret = ret .. res
      end

      return(ret .. "</A>")
   elseif((key == 'FLOW_USER_NAME') or (key == '57593')) then
      elems = string.split(value, ';')

      if((elems ~= nil) and (#elems == 6)) then
          r = '<table class="table table-bordered table-striped">'
	  imsi = elems[1]
	  mcc = string.sub(imsi, 1, 3)

	  if(mobile_country_code[mcc] ~= nil) then
    	    mcc_name = " ["..mobile_country_code[mcc].."]"
	  else
   	    mcc_name = ""
	  end

          r = r .. "<th>"..i18n("flow_details.imsi").."</th><td>"..elems[1]..mcc_name
	  r = r .. " <A HREF='http://www.numberingplans.com/?page=analysis&sub=imsinr'><i class='fa fa-info'></i></A></td></tr>"
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
  elseif((rtemplate[tonumber(key)] == 'SIP_TRYING_TIME') or (rtemplate[tonumber(key)] == 'SIP_RINGING_TIME') or (rtemplate[tonumber(key)] == 'SIP_INVITE_TIME') or (rtemplate[tonumber(key)] == 'SIP_INVITE_OK_TIME') or (rtemplate[tonumber(key)] == 'SIP_INVITE_FAILURE_TIME') or (rtemplate[tonumber(key)] == 'SIP_BYE_TIME') or (rtemplate[tonumber(key)] == 'SIP_BYE_OK_TIME') or (rtemplate[tonumber(key)] == 'SIP_CANCEL_TIME') or (rtemplate[tonumber(key)] == 'SIP_CANCEL_OK_TIME')) then
    if(value ~= '0') then
      return(formatEpoch(value))
    else
      return "0"
    end
  elseif((rtemplate[tonumber(key)] == 'RTP_IN_JITTER') or (rtemplate[tonumber(key)] == 'RTP_OUT_JITTER')) then
    if(value ~= nil and value ~= '0') then
      return(value/1000)
    else
      return 0
    end
   elseif((rtemplate[tonumber(key)] == 'RTP_IN_MAX_DELTA') or (rtemplate[tonumber(key)] == 'RTP_OUT_MAX_DELTA') or (rtemplate[tonumber(key)] == 'RTP_MOS') or (rtemplate[tonumber(key)] == 'RTP_R_FACTOR') or (rtemplate[tonumber(key)] == 'RTP_IN_MOS') or (rtemplate[tonumber(key)] == 'RTP_OUT_MOS') or (rtemplate[tonumber(key)] == 'RTP_IN_R_FACTOR') or (rtemplate[tonumber(key)] == 'RTP_OUT_R_FACTOR') or (rtemplate[tonumber(key)] == 'RTP_IN_TRANSIT') or (rtemplate[tonumber(key)] == 'RTP_OUT_TRANSIT')) then
    if(value ~= nil and value ~= '0') then
      return(value/100)
    else
      return 0
    end
  end

  -- Unformatted value
  return value
end


-- #######################

function formatTcpFlags(flags)
   if(flags == 0) then
      return("")
   end

   rsp = "<A HREF=\"http://en.wikipedia.org/wiki/Transmission_Control_Protocol\">"
   if(bit.band(flags, 1) == 2)  then rsp = rsp .. " SYN "  end
   if(bit.band(flags, 16) == 16) then rsp = rsp .. " ACK "  end
   if(bit.band(flags, 1) == 1)  then rsp = rsp .. " FIN "  end
   if(bit.band(flags, 4) == 4)  then rsp = rsp .. " RST "  end
   if(bit.band(flags, 8) == 8 )  then rsp = rsp .. " PUSH " end

   return(rsp .. "</A>")
end

-- #######################

-- IMPORTANT: keep it in sync with ParserInterface::ParserInterface()

local flow_fields_description = {
    ["IN_BYTES"] = i18n("flow_fields_description.in_bytes"),
    ["IN_PKTS"] = i18n("flow_fields_description.in_pkts"),
    ["PROTOCOL"] = i18n("flow_fields_description.protocol"),
    ["PROTOCOL_MAP"] = i18n("flow_fields_description.protocol_map"),
    ["SRC_TOS"] = i18n("flow_fields_description.src_tos"),
    ["TCP_FLAGS"] = i18n("flow_fields_description.tcp_flags"),
    ["L4_SRC_PORT"] = i18n("flow_fields_description.l4_src_port"),
    ["L4_SRC_PORT_MAP"] = i18n("flow_fields_description.l4_src_port_map"),
    ["IPV4_SRC_ADDR"] = i18n("flow_fields_description.ipv4_src_addr"),
    ["IPV4_SRC_MASK"] = i18n("flow_fields_description.ipv4_src_mask"),
    ["INPUT_SNMP"] = i18n("flow_fields_description.input_snmp"),
    ["L4_DST_PORT"] = i18n("flow_fields_description.l4_dst_port"),
    ["L4_DST_PORT_MAP"] = i18n("flow_fields_description.l4_dst_port_map"),
    ["L4_SRV_PORT"] = i18n("flow_fields_description.l4_srv_port"),
    ["L4_SRV_PORT_MAP"] = i18n("flow_fields_description.l4_srv_port_map"),
    ["IPV4_DST_ADDR"] = i18n("flow_fields_description.ipv4_dst_addr"),
    ["IPV4_DST_MASK"] = i18n("flow_fields_description.ipv4_dst_mask"),
    ["OUTPUT_SNMP"] = i18n("flow_fields_description.output_snmp"),
    ["IPV4_NEXT_HOP"] = i18n("flow_fields_description.ipv4_next_hop"),
    ["SRC_AS"] = i18n("flow_fields_description.src_as"),
    ["DST_AS"] = i18n("flow_fields_description.dst_as"),
    ["LAST_SWITCHED"] = i18n("flow_fields_description.last_switched"),
    ["FIRST_SWITCHED"] = i18n("flow_fields_description.first_switched"),
    ["OUT_BYTES"] = i18n("flow_fields_description.out_bytes"),
    ["OUT_PKTS"] = i18n("flow_fields_description.out_pkts"),
    ["IPV6_SRC_ADDR"] = i18n("flow_fields_description.ipv6_src_addr"),
    ["IPV6_DST_ADDR"] = i18n("flow_fields_description.ipv6_dst_addr"),
    ["IPV6_SRC_MASK"] = i18n("flow_fields_description.ipv6_src_mask"),
    ["IPV6_DST_MASK"] = i18n("flow_fields_description.ipv6_dst_mask"),
    ["ICMP_TYPE"] = i18n("flow_fields_description.icmp_type"),
    ["SAMPLING_INTERVAL"] = i18n("flow_fields_description.sampling_interval"),
    ["SAMPLING_ALGORITHM"] = i18n("flow_fields_description.sampling_algorithm"),
    ["FLOW_ACTIVE_TIMEOUT"] = i18n("flow_fields_description.flow_active_timeout"),
    ["FLOW_INACTIVE_TIMEOUT"] = i18n("flow_fields_description.flow_inactive_timeout"),
    ["ENGINE_TYPE"] = i18n("flow_fields_description.engine_type"),
    ["ENGINE_ID"] = i18n("flow_fields_description.engine_id"),
    ["TOTAL_BYTES_EXP"] = i18n("flow_fields_description.total_bytes_exp"),
    ["TOTAL_PKTS_EXP"] = i18n("flow_fields_description.total_pkts_exp"),
    ["TOTAL_FLOWS_EXP"] = i18n("flow_fields_description.total_flows_exp"),
    ["MIN_TTL"] = i18n("flow_fields_description.min_ttl"),
    ["MAX_TTL"] = i18n("flow_fields_description.max_ttl"),
    ["DST_TOS"] = i18n("flow_fields_description.dst_tos"),
    ["IN_SRC_MAC"] = i18n("flow_fields_description.in_src_mac"),
    ["OUT_SRC_MAC"] = i18n("flow_fields_description.out_src_mac"),
    ["SRC_VLAN"] = i18n("flow_fields_description.src_vlan"),
    ["DST_VLAN"] = i18n("flow_fields_description.dst_vlan"),
    ["DOT1Q_SRC_VLAN"] = i18n("flow_fields_description.dot1q_src_vlan"),
    ["DOT1Q_DST_VLAN"] = i18n("flow_fields_description.dot1q_dst_vlan"),
    ["IP_PROTOCOL_VERSION"] = i18n("flow_fields_description.ip_protocol_version"),
    ["DIRECTION"] = i18n("flow_fields_description.direction"),
    ["IPV6_NEXT_HOP"] = i18n("flow_fields_description.ipv6_next_hop"),
    ["MPLS_LABEL_1"] = i18n("flow_fields_description.mpls_label_1"),
    ["MPLS_LABEL_2"] = i18n("flow_fields_description.mpls_label_2"),
    ["MPLS_LABEL_3"] = i18n("flow_fields_description.mpls_label_3"),
    ["MPLS_LABEL_4"] = i18n("flow_fields_description.mpls_label_4"),
    ["MPLS_LABEL_5"] = i18n("flow_fields_description.mpls_label_5"),
    ["MPLS_LABEL_6"] = i18n("flow_fields_description.mpls_label_6"),
    ["MPLS_LABEL_7"] = i18n("flow_fields_description.mpls_label_7"),
    ["MPLS_LABEL_8"] = i18n("flow_fields_description.mpls_label_8"),
    ["MPLS_LABEL_9"] = i18n("flow_fields_description.mpls_label_9"),
    ["MPLS_LABEL_10"] = i18n("flow_fields_description.mpls_label_10"),
    ["IN_DST_MAC"] = i18n("flow_fields_description.in_dst_mac"),
    ["OUT_DST_MAC"] = i18n("flow_fields_description.out_dst_mac"),
    ["APPLICATION_ID"] = i18n("flow_fields_description.application_id"),
    ["PACKET_SECTION_OFFSET"] = i18n("flow_fields_description.packet_section_offset"),
    ["SAMPLED_PACKET_SIZE"] = i18n("flow_fields_description.sampled_packet_size"),
    ["SAMPLED_PACKET_ID"] = i18n("flow_fields_description.sampled_packet_id"),
    ["EXPORTER_IPV4_ADDRESS"] = i18n("flow_fields_description.exporter_ipv4_address"),
    ["EXPORTER_IPV6_ADDRESS"] = i18n("flow_fields_description.exporter_ipv6_address"),
    ["FLOW_ID"] = i18n("flow_fields_description.flow_id"),
    ["FLOW_START_SEC"] = i18n("flow_fields_description.flow_start_sec"),
    ["FLOW_END_SEC"] = i18n("flow_fields_description.flow_end_sec"),
    ["FLOW_START_MILLISECONDS"] = i18n("flow_fields_description.flow_start_milliseconds"),
    ["FLOW_START_MICROSECONDS"] = i18n("flow_fields_description.flow_start_microseconds"),
    ["FLOW_END_MILLISECONDS"] = i18n("flow_fields_description.flow_end_milliseconds"),
    ["FLOW_END_MICROSECONDS"] = i18n("flow_fields_description.flow_end_microseconds"),
    ['FIREWALL_EVENT'] = i18n("flow_fields_description.firewall_event"),
    ["BIFLOW_DIRECTION"] = i18n("flow_fields_description.biflow_direction"),
    ["INGRESS_VRFID"] = i18n("flow_fields_description.ingress_vrfid"),
    ["FLOW_DURATION_MILLISECONDS"] = i18n("flow_fields_description.flow_duration_milliseconds"),
    ["FLOW_DURATION_MICROSECONDS"] = i18n("flow_fields_description.flow_duration_microseconds"),
    ["ICMP_IPV4_TYPE"] = i18n("flow_fields_description.icmp_ipv4_type"),
    ["ICMP_IPV4_CODE"] = i18n("flow_fields_description.icmp_ipv4_code"),
    ["POST_NAT_SRC_IPV4_ADDR"] = i18n("flow_fields_description.post_nat_src_ipv4_addr"),
    ["POST_NAT_DST_IPV4_ADDR"] = i18n("flow_fields_description.post_nat_dst_ipv4_addr"),
    ["POST_NAPT_SRC_TRANSPORT_PORT"] = i18n("flow_fields_description.post_napt_src_transport_port"),
    ["POST_NAPT_DST_TRANSPORT_PORT"] = i18n("flow_fields_description.post_napt_dst_transport_port"),
    ["OBSERVATION_POINT_TYPE"] = i18n("flow_fields_description.observation_point_type"),
    ["OBSERVATION_POINT_ID"] = i18n("flow_fields_description.observation_point_id"),
    ["SELECTOR_ID"] = i18n("flow_fields_description.selector_id"),
    ["IPFIX_SAMPLING_ALGORITHM"] = i18n("flow_fields_description.ipfix_sampling_algorithm"),
    ["SAMPLING_SIZE"] = i18n("flow_fields_description.sampling_size"),
    ["SAMPLING_POPULATION"] = i18n("flow_fields_description.sampling_population"),
    ["FRAME_LENGTH"] = i18n("flow_fields_description.frame_length"),
    ["PACKETS_OBSERVED"] = i18n("flow_fields_description.packets_observed"),
    ["PACKETS_SELECTED"] = i18n("flow_fields_description.packets_selected"),
    ["SELECTOR_NAME"] = i18n("flow_fields_description.selector_name"),
    ["APPLICATION_NAME"] = i18n("flow_fields_description.application_name"),
    ["USER_NAME"] = i18n("flow_fields_description.user_name"),
    ["SRC_FRAGMENTS"] = i18n("flow_fields_description.src_fragments"),
    ["DST_FRAGMENTS"] = i18n("flow_fields_description.dst_fragments"),
    ["CLIENT_NW_LATENCY_MS"] = i18n("flow_fields_description.client_nw_latency_ms"),
    ["SERVER_NW_LATENCY_MS"] = i18n("flow_fields_description.server_nw_latency_ms"),
    ["APPL_LATENCY_MS"] = i18n("flow_fields_description.appl_latency_ms"),
    ["NPROBE_IPV4_ADDRESS"] = i18n("flow_fields_description.nprobe_ipv4_address"),
    ["SRC_TO_DST_MAX_THROUGHPUT"] = i18n("flow_fields_description.src_to_dst_max_throughput"),
    ["SRC_TO_DST_MIN_THROUGHPUT"] = i18n("flow_fields_description.src_to_dst_min_throughput"),
    ["SRC_TO_DST_AVG_THROUGHPUT"] = i18n("flow_fields_description.src_to_dst_avg_throughput"),
    ["DST_TO_SRC_MAX_THROUGHPUT"] = i18n("flow_fields_description.dst_to_src_max_throughput"),
    ["DST_TO_SRC_MIN_THROUGHPUT"] = i18n("flow_fields_description.dst_to_src_min_throughput"),
    ["DST_TO_SRC_AVG_THROUGHPUT"] = i18n("flow_fields_description.dst_to_src_avg_throughput"),
    ["NUM_PKTS_UP_TO_128_BYTES"] = i18n("flow_fields_description.num_pkts_up_to_128_bytes"),
    ["NUM_PKTS_128_TO_256_BYTES"] = i18n("flow_fields_description.num_pkts_128_to_256_bytes"),
    ["NUM_PKTS_256_TO_512_BYTES"] = i18n("flow_fields_description.num_pkts_256_to_512_bytes"),
    ["NUM_PKTS_512_TO_1024_BYTES"] = i18n("flow_fields_description.num_pkts_512_to_1024_bytes"),
    ["NUM_PKTS_1024_TO_1514_BYTES"] = i18n("flow_fields_description.num_pkts_1024_to_1514_bytes"),
    ["NUM_PKTS_OVER_1514_BYTES"] = i18n("flow_fields_description.num_pkts_over_1514_bytes"),
    ["CUMULATIVE_ICMP_TYPE"] = i18n("flow_fields_description.cumulative_icmp_type"),
    ["SRC_IP_COUNTRY"] = i18n("flow_fields_description.src_ip_country"),
    ["SRC_IP_CITY"] = i18n("flow_fields_description.src_ip_city"),
    ["DST_IP_COUNTRY"] = i18n("flow_fields_description.dst_ip_country"),
    ["DST_IP_CITY"] = i18n("flow_fields_description.dst_ip_city"),
    ["SRC_IP_LONG"] = i18n("flow_fields_description.src_ip_long"),
    ["SRC_IP_LAT"] = i18n("flow_fields_description.src_ip_lat"),
    ["DST_IP_LONG"] = i18n("flow_fields_description.dst_ip_long"),
    ["DST_IP_LAT"] = i18n("flow_fields_description.dst_ip_lat"),
    ["FLOW_PROTO_PORT"] = i18n("flow_fields_description.flow_proto_port"),
    ["UPSTREAM_TUNNEL_ID"] = i18n("flow_fields_description.upstream_tunnel_id"),
    ["UPSTREAM_SESSION_ID"] = i18n("flow_fields_description.upstream_session_id"),
    ["LONGEST_FLOW_PKT"] = i18n("flow_fields_description.longest_flow_pkt"),
    ["SHORTEST_FLOW_PKT"] = i18n("flow_fields_description.shortest_flow_pkt"),
    ["RETRANSMITTED_IN_BYTES"] = i18n("flow_fields_description.retransmitted_in_bytes"),
    ["RETRANSMITTED_IN_PKTS"] = i18n("flow_fields_description.retransmitted_in_pkts"),
    ["RETRANSMITTED_OUT_BYTES"] = i18n("flow_fields_description.retransmitted_out_bytes"),
    ["RETRANSMITTED_OUT_PKTS"] = i18n("flow_fields_description.retransmitted_out_pkts"),
    ["OOORDER_IN_PKTS"] = i18n("flow_fields_description.ooorder_in_pkts"),
    ["OOORDER_OUT_PKTS"] = i18n("flow_fields_description.ooorder_out_pkts"),
    ["UNTUNNELED_PROTOCOL"] = i18n("flow_fields_description.untunneled_protocol"),
    ["UNTUNNELED_IPV4_SRC_ADDR"] = i18n("flow_fields_description.untunneled_ipv4_src_addr"),
    ["UNTUNNELED_L4_SRC_PORT"] = i18n("flow_fields_description.untunneled_l4_src_port"),
    ["UNTUNNELED_IPV4_DST_ADDR"] = i18n("flow_fields_description.untunneled_ipv4_dst_addr"),
    ["UNTUNNELED_L4_DST_PORT"] = i18n("flow_fields_description.untunneled_l4_dst_port"),
    ["L7_PROTO"] = i18n("flow_fields_description.l7_proto"),
    ["L7_PROTO_NAME"] = i18n("flow_fields_description.l7_proto_name"),
    ["DOWNSTREAM_TUNNEL_ID"] = i18n("flow_fields_description.downstream_tunnel_id"),
    ["DOWNSTREAM_SESSION_ID"] = i18n("flow_fields_description.downstream_session_id"),
    ["SSL_SERVER_NAME"] = i18n("flow_fields_description.ssl_server_name"),
    ["BITTORRENT_HASH"] = i18n("flow_fields_description.bittorrent_hash"),
    ["FLOW_USER_NAME"] = i18n("flow_fields_description.flow_user_name"),
    ["FLOW_SERVER_NAME"] = i18n("flow_fields_description.flow_server_name"),
    ["PLUGIN_NAME"] = i18n("flow_fields_description.plugin_name"),
    ["UNTUNNELED_IPV6_SRC_ADDR"] = i18n("flow_fields_description.untunneled_ipv6_src_addr"),
    ["UNTUNNELED_IPV6_DST_ADDR"] = i18n("flow_fields_description.untunneled_ipv6_dst_addr"),
    ["NUM_PKTS_TTL_EQ_1"] = i18n("flow_fields_description.num_pkts_ttl_eq_1"),
    ["NUM_PKTS_TTL_2_5"] = i18n("flow_fields_description.num_pkts_ttl_2_5"),
    ["NUM_PKTS_TTL_5_32"] = i18n("flow_fields_description.num_pkts_ttl_5_32"),
    ["NUM_PKTS_TTL_32_64"] = i18n("flow_fields_description.num_pkts_ttl_32_64"),
    ["NUM_PKTS_TTL_64_96"] = i18n("flow_fields_description.num_pkts_ttl_64_96"),
    ["NUM_PKTS_TTL_96_128"] = i18n("flow_fields_description.num_pkts_ttl_96_128"),
    ["NUM_PKTS_TTL_128_160"] = i18n("flow_fields_description.num_pkts_ttl_128_160"),
    ["NUM_PKTS_TTL_160_192"] = i18n("flow_fields_description.num_pkts_ttl_160_192"),
    ["NUM_PKTS_TTL_192_224"] = i18n("flow_fields_description.num_pkts_ttl_192_224"),
    ["NUM_PKTS_TTL_224_255"] = i18n("flow_fields_description.num_pkts_ttl_224_255"),
    ["IN_SRC_OSI_SAP"] = i18n("flow_fields_description.in_src_osi_sap"),
    ["OUT_DST_OSI_SAP"] = i18n("flow_fields_description.out_dst_osi_sap"),
    ["DURATION_IN"] = i18n("flow_fields_description.duration_in"),
    ["DURATION_OUT"] = i18n("flow_fields_description.duration_out"),
    ["TCP_WIN_MIN_IN"] = i18n("flow_fields_description.tcp_win_min_in"),
    ["TCP_WIN_MAX_IN"] = i18n("flow_fields_description.tcp_win_max_in"),
    ["TCP_WIN_MSS_IN"] = i18n("flow_fields_description.tcp_win_mss_in"),
    ["TCP_WIN_SCALE_IN"] = i18n("flow_fields_description.tcp_win_scale_in"),
    ["TCP_WIN_MIN_OUT"] = i18n("flow_fields_description.tcp_win_min_out"),
    ["TCP_WIN_MAX_OUT"] = i18n("flow_fields_description.tcp_win_max_out"),
    ["TCP_WIN_MSS_OUT"] = i18n("flow_fields_description.tcp_win_mss_out"),
    ["TCP_WIN_SCALE_OUT"] = i18n("flow_fields_description.tcp_win_scale_out"),
    ["PAYLOAD_HASH"] = i18n("flow_fields_description.payload_hash"),
    ["SRC_AS_MAP"] = i18n("flow_fields_description.src_as_map"),
    ["DST_AS_MAP"] = i18n("flow_fields_description.dst_as_map"),

    -- BGP Update Listener
    ["SRC_AS_PATH_1"] = i18n("flow_fields_description.src_as_path_1"),
    ["SRC_AS_PATH_2"] = i18n("flow_fields_description.src_as_path_2"),
    ["SRC_AS_PATH_3"] = i18n("flow_fields_description.src_as_path_3"),
    ["SRC_AS_PATH_4"] = i18n("flow_fields_description.src_as_path_4"),
    ["SRC_AS_PATH_5"] = i18n("flow_fields_description.src_as_path_5"),
    ["SRC_AS_PATH_6"] = i18n("flow_fields_description.src_as_path_6"),
    ["SRC_AS_PATH_7"] = i18n("flow_fields_description.src_as_path_7"),
    ["SRC_AS_PATH_8"] = i18n("flow_fields_description.src_as_path_8"),
    ["SRC_AS_PATH_9"] = i18n("flow_fields_description.src_as_path_9"),
    ["SRC_AS_PATH_10"] = i18n("flow_fields_description.src_as_path_10"),
    ["DST_AS_PATH_1"] = i18n("flow_fields_description.dst_as_path_1"),
    ["DST_AS_PATH_2"] = i18n("flow_fields_description.dst_as_path_2"),
    ["DST_AS_PATH_3"] = i18n("flow_fields_description.dst_as_path_3"),
    ["DST_AS_PATH_4"] = i18n("flow_fields_description.dst_as_path_4"),
    ["DST_AS_PATH_5"] = i18n("flow_fields_description.dst_as_path_5"),
    ["DST_AS_PATH_6"] = i18n("flow_fields_description.dst_as_path_6"),
    ["DST_AS_PATH_7"] = i18n("flow_fields_description.dst_as_path_7"),
    ["DST_AS_PATH_8"] = i18n("flow_fields_description.dst_as_path_8"),
    ["DST_AS_PATH_9"] = i18n("flow_fields_description.dst_as_path_9"),
    ["DST_AS_PATH_10"] = i18n("flow_fields_description.dst_as_path_10"),

    -- DHCP Protocol
    ["DHCP_CLIENT_MAC"] = i18n("flow_fields_description.dhcp_client_mac"),
    ["DHCP_CLIENT_IP"] = i18n("flow_fields_description.dhcp_client_ip"),
    ["DHCP_CLIENT_NAME"] = i18n("flow_fields_description.dhcp_client_name"),
    ["DHCP_REMOTE_ID"] = i18n("flow_fields_description.dhcp_remote_id"),
    ["DHCP_SUBSCRIBER_ID"] = i18n("flow_fields_description.dhcp_subscriber_id"),
    ["DHCP_MESSAGE_TYPE"] = i18n("flow_fields_description.dhcp_message_type"),

    -- Diameter Protocol
    ["DIAMETER_REQ_MSG_TYPE"] = i18n("flow_fields_description.diameter_req_msg_type"),
    ["DIAMETER_RSP_MSG_TYPE"] = i18n("flow_fields_description.diameter_rsp_msg_type"),
    ["DIAMETER_REQ_ORIGIN_HOST"] = i18n("flow_fields_description.diameter_req_origin_host"),
    ["DIAMETER_RSP_ORIGIN_HOST"] = i18n("flow_fields_description.diameter_rsp_origin_host"),
    ["DIAMETER_REQ_USER_NAME"] = i18n("flow_fields_description.diameter_req_user_name"),
    ["DIAMETER_RSP_RESULT_CODE"] = i18n("flow_fields_description.diameter_rsp_result_code"),
    ["DIAMETER_EXP_RES_VENDOR_ID"] = i18n("flow_fields_description.diameter_exp_res_vendor_id"),
    ["DIAMETER_EXP_RES_RESULT_CODE"] = i18n("flow_fields_description.diameter_exp_res_result_code"),
    ["DIAMETER_HOP_BY_HOP_ID"] = i18n("flow_fields_description.diameter_hop_by_hop_id"),
    ["DIAMETER_CLR_CANCEL_TYPE"] = i18n("flow_fields_description.diameter_clr_cancel_type"),
    ["DIAMETER_CLR_FLAGS"] = i18n("flow_fields_description.diameter_clr_flags"),

    -- DNS/LLMNR Protocol
    ["DNS_QUERY"] = i18n("flow_fields_description.dns_query"),
    ["DNS_QUERY_ID"] = i18n("flow_fields_description.dns_query_id"),
    ["DNS_QUERY_TYPE"] = i18n("flow_fields_description.dns_query_type"),
    ["DNS_RET_CODE"] = i18n("flow_fields_description.dns_ret_code"),
    ["DNS_NUM_ANSWERS"] = i18n("flow_fields_description.dns_num_answers"),
    ["DNS_TTL_ANSWER"] = i18n("flow_fields_description.dns_ttl_answer"),
    ["DNS_RESPONSE"] = i18n("flow_fields_description.dns_response"),

    -- FTP Protocol
    ["FTP_LOGIN"] = i18n("flow_fields_description.ftp_login"),
    ["FTP_PASSWORD"] = i18n("flow_fields_description.ftp_password"),
    ["FTP_COMMAND"] = i18n("flow_fields_description.ftp_command"),
    ["FTP_COMMAND_RET_CODE"] = i18n("flow_fields_description.ftp_command_ret_code"),

    -- GTPv0 Signaling Protocol
    ["GTPV0_REQ_MSG_TYPE"] = i18n("flow_fields_description.gtpv0_req_msg_type"),
    ["GTPV0_RSP_MSG_TYPE"] = i18n("flow_fields_description.gtpv0_rsp_msg_type"),
    ["GTPV0_TID"] = i18n("flow_fields_description.gtpv0_tid"),
    ["GTPV0_APN_NAME"] = i18n("flow_fields_description.gtpv0_apn_name"),
    ["GTPV0_END_USER_IP"] = i18n("flow_fields_description.gtpv0_end_user_ip"),
    ["GTPV0_END_USER_MSISDN"] = i18n("flow_fields_description.gtpv0_end_user_msisdn"),
    ["GTPV0_RAI_MCC"] = i18n("flow_fields_description.gtpv0_rai_mcc"),
    ["GTPV0_RAI_MNC"] = i18n("flow_fields_description.gtpv0_rai_mnc"),
    ["GTPV0_RAI_CELL_LAC"] = i18n("flow_fields_description.gtpv0_rai_cell_lac"),
    ["GTPV0_RAI_CELL_RAC"] = i18n("flow_fields_description.gtpv0_rai_cell_rac"),
    ["GTPV0_RESPONSE_CAUSE"] = i18n("flow_fields_description.gtpv0_response_cause"),

    -- GTPv1 Signaling Protocol
    ["GTPV1_REQ_MSG_TYPE"] = i18n("flow_fields_description.gtpv1_req_msg_type"),
    ["GTPV1_RSP_MSG_TYPE"] = i18n("flow_fields_description.gtpv1_rsp_msg_type"),
    ["GTPV1_C2S_TEID_DATA"] = i18n("flow_fields_description.gtpv1_c2s_teid_data"),
    ["GTPV1_C2S_TEID_CTRL"] = i18n("flow_fields_description.gtpv1_c2s_teid_ctrl"),
    ["GTPV1_S2C_TEID_DATA"] = i18n("flow_fields_description.gtpv1_s2c_teid_data"),
    ["GTPV1_S2C_TEID_CTRL"] = i18n("flow_fields_description.gtpv1_s2c_teid_ctrl"),
    ["GTPV1_END_USER_IP"] = i18n("flow_fields_description.gtpv1_end_user_ip"),
    ["GTPV1_END_USER_IMSI"] = i18n("flow_fields_description.gtpv1_end_user_imsi"),
    ["GTPV1_END_USER_MSISDN"] = i18n("flow_fields_description.gtpv1_end_user_msisdn"),
    ["GTPV1_END_USER_IMEI"] = i18n("flow_fields_description.gtpv1_end_user_imei"),
    ["GTPV1_APN_NAME"] = i18n("flow_fields_description.gtpv1_apn_name"),
    ["GTPV1_RAT_TYPE"] = i18n("flow_fields_description.gtpv1_rat_type"),
    ["GTPV1_RAI_MCC"] = i18n("flow_fields_description.gtpv1_rai_mcc"),
    ["GTPV1_RAI_MNC"] = i18n("flow_fields_description.gtpv1_rai_mnc"),
    ["GTPV1_RAI_LAC"] = i18n("flow_fields_description.gtpv1_rai_lac"),
    ["GTPV1_RAI_RAC"] = i18n("flow_fields_description.gtpv1_rai_rac"),
    ["GTPV1_ULI_MCC"] = i18n("flow_fields_description.gtpv1_uli_mcc"),
    ["GTPV1_ULI_MNC"] = i18n("flow_fields_description.gtpv1_uli_mnc"),
    ["GTPV1_ULI_CELL_LAC"] = i18n("flow_fields_description.gtpv1_uli_cell_lac"),
    ["GTPV1_ULI_CELL_CI"] = i18n("flow_fields_description.gtpv1_uli_cell_ci"),
    ["GTPV1_ULI_SAC"] = i18n("flow_fields_description.gtpv1_uli_sac"),
    ["GTPV1_RESPONSE_CAUSE"] = i18n("flow_fields_description.gtpv1_response_cause"),

    -- GTPv2 Signaling Protocol
    ["GTPV2_REQ_MSG_TYPE"] = i18n("flow_fields_description.gtpv2_req_msg_type"),
    ["GTPV2_RSP_MSG_TYPE"] = i18n("flow_fields_description.gtpv2_rsp_msg_type"),
    ["GTPV2_C2S_S1U_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_c2s_s1u_gtpu_teid"),
    ["GTPV2_C2S_S1U_GTPU_IP"] = i18n("flow_fields_description.gtpv2_c2s_s1u_gtpu_ip"),
    ["GTPV2_S2C_S1U_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_s2c_s1u_gtpu_teid"),
    ["GTPV2_S5_S8_GTPC_TEID"] = i18n("flow_fields_description.gtpv2_s5_s8_gtpc_teid"),
    ["GTPV2_S2C_S1U_GTPU_IP"] = i18n("flow_fields_description.gtpv2_s2c_s1u_gtpu_ip"),
    ["GTPV2_C2S_S5_S8_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_gtpu_teid"),
    ["GTPV2_S2C_S5_S8_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_gtpu_teid"),
    ["GTPV2_C2S_S5_S8_GTPU_IP"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_gtpu_ip"),
    ["GTPV2_S2C_S5_S8_GTPU_IP"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_gtpu_ip"),
    ["GTPV2_END_USER_IMSI"] = i18n("flow_fields_description.gtpv2_end_user_imsi"),
    ["GTPV2_END_USER_MSISDN"] = i18n("flow_fields_description.gtpv2_end_user_msisdn"),
    ["GTPV2_APN_NAME"] = i18n("flow_fields_description.gtpv2_apn_name"),
    ["GTPV2_ULI_MCC"] = i18n("flow_fields_description.gtpv2_uli_mcc"),
    ["GTPV2_ULI_MNC"] = i18n("flow_fields_description.gtpv2_uli_mnc"),
    ["GTPV2_ULI_CELL_TAC"] = i18n("flow_fields_description.gtpv2_uli_cell_tac"),
    ["GTPV2_ULI_CELL_ID"] = i18n("flow_fields_description.gtpv2_uli_cell_id"),
    ["GTPV2_RESPONSE_CAUSE"] = i18n("flow_fields_description.gtpv2_response_cause"),
    ["GTPV2_RAT_TYPE"] = i18n("flow_fields_description.gtpv2_rat_type"),
    ["GTPV2_PDN_IP"] = i18n("flow_fields_description.gtpv2_pdn_ip"),
    ["GTPV2_END_USER_IMEI"] = i18n("flow_fields_description.gtpv2_end_user_imei"),
    ["GTPV2_C2S_S5_S8_GTPC_IP"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_gtpc_ip"),
    ["GTPV2_S2C_S5_S8_GTPC_IP"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_gtpc_ip"),
    ["GTPV2_C2S_S5_S8_SGW_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_sgw_gtpu_teid"),
    ["GTPV2_S2C_S5_S8_SGW_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_sgw_gtpu_teid"),
    ["GTPV2_C2S_S5_S8_SGW_GTPU_IP"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_sgw_gtpu_ip"),
    ["GTPV2_S2C_S5_S8_SGW_GTPU_IP"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_sgw_gtpu_ip"),

    -- HTTP Protocol
    ["HTTP_URL"] = i18n("flow_fields_description.http_url"),
    ["HTTP_METHOD"] = i18n("flow_fields_description.http_method"),
    ["HTTP_RET_CODE"] = i18n("flow_fields_description.http_ret_code"),
    ["HTTP_REFERER"] = i18n("flow_fields_description.http_referer"),
    ["HTTP_UA"] = i18n("flow_fields_description.http_ua"),
    ["HTTP_MIME"] = i18n("flow_fields_description.http_mime"),
    ["HTTP_HOST"] = i18n("flow_fields_description.http_host"),
    ["HTTP_SITE"] = i18n("flow_fields_description.http_site"),
    ["HTTP_X_FORWARDED_FOR"] = i18n("flow_fields_description.http_x_forwarded_for"),
    ["HTTP_VIA"] = i18n("flow_fields_description.http_via"),

    -- IMAP Protocol
    ["IMAP_LOGIN"] = i18n("flow_fields_description.imap_login"),

    -- MySQL Plugin
    ["MYSQL_SERVER_VERSION"] = i18n("flow_fields_description.mysql_server_version"),
    ["MYSQL_USERNAME"] = i18n("flow_fields_description.mysql_username"),
    ["MYSQL_DB"] = i18n("flow_fields_description.mysql_db"),
    ["MYSQL_QUERY"] = i18n("flow_fields_description.mysql_query"),
    ["MYSQL_RESPONSE"] = i18n("flow_fields_description.mysql_response"),
    ["MYSQL_APPL_LATENCY_USEC"] = i18n("flow_fields_description.mysql_appl_latency_usec"),

    -- NETBIOS Protocol
    ["NETBIOS_QUERY_NAME"] = i18n("flow_fields_description.netbios_query_name"),
    ["NETBIOS_QUERY_TYPE"] = i18n("flow_fields_description.netbios_query_type"),
    ["NETBIOS_RESPONSE"] = i18n("flow_fields_description.netbios_response"),
    ["NETBIOS_QUERY_OS"] = i18n("flow_fields_description.netbios_query_os"),

    -- Oracle Protocol
    ["ORACLE_USERNAME"] = i18n("flow_fields_description.oracle_username"),
    ["ORACLE_QUERY"] = i18n("flow_fields_description.oracle_query"),
    ["ORACLE_RSP_CODE"] = i18n("flow_fields_description.oracle_rsp_code"),
    ["ORACLE_RSP_STRING"] = i18n("flow_fields_description.oracle_rsp_string"),
    ["ORACLE_QUERY_DURATION"] = i18n("flow_fields_description.oracle_query_duration"),

    -- OP3 Protocol
    ["POP_USER"] = i18n("flow_fields_description.pop_user"),

    -- System process information
    ["SRC_PROC_PID"] = i18n("flow_fields_description.src_proc_pid"),
    ["SRC_PROC_NAME"] = i18n("flow_fields_description.src_proc_name"),
    ["SRC_PROC_UID"] = i18n("flow_fields_description.src_proc_uid"),
    ["SRC_PROC_USER_NAME"] = i18n("flow_fields_description.src_proc_user_name"),
    ["SRC_FATHER_PROC_PID"] = i18n("flow_fields_description.src_father_proc_pid"),
    ["SRC_FATHER_PROC_NAME"] = i18n("flow_fields_description.src_father_proc_name"),
    ["SRC_PROC_ACTUAL_MEMORY"] = i18n("flow_fields_description.src_proc_actual_memory"),
    ["SRC_PROC_PEAK_MEMORY"] = i18n("flow_fields_description.src_proc_peak_memory"),
    ["SRC_PROC_AVERAGE_CPU_LOAD"] = i18n("flow_fields_description.src_proc_average_cpu_load"),
    ["SRC_PROC_NUM_PAGE_FAULTS"] = i18n("flow_fields_description.src_proc_num_page_faults"),
    ["SRC_PROC_PCTG_IOWAIT"] = i18n("flow_fields_description.src_proc_pctg_iowait"),
    ["DST_PROC_PID"] = i18n("flow_fields_description.dst_proc_pid"),
    ["DST_PROC_NAME"] = i18n("flow_fields_description.dst_proc_name"),
    ["DST_PROC_UID"] = i18n("flow_fields_description.dst_proc_uid"),
    ["DST_PROC_USER_NAME"] = i18n("flow_fields_description.dst_proc_user_name"),
    ["DST_FATHER_PROC_PID"] = i18n("flow_fields_description.dst_father_proc_pid"),
    ["DST_FATHER_PROC_NAME"] = i18n("flow_fields_description.dst_father_proc_name"),
    ["DST_PROC_ACTUAL_MEMORY"] = i18n("flow_fields_description.dst_proc_actual_memory"),
    ["DST_PROC_PEAK_MEMORY"] = i18n("flow_fields_description.dst_proc_peak_memory"),
    ["DST_PROC_AVERAGE_CPU_LOAD"] = i18n("flow_fields_description.dst_proc_average_cpu_load"),
    ["DST_PROC_NUM_PAGE_FAULTS"] = i18n("flow_fields_description.dst_proc_num_page_faults"),
    ["DST_PROC_PCTG_IOWAIT"] = i18n("flow_fields_description.dst_proc_pctg_iowait"),

    -- Radius Protocol
    ["RADIUS_REQ_MSG_TYPE"] = i18n("flow_fields_description.radius_req_msg_type"),
    ["RADIUS_RSP_MSG_TYPE"] = i18n("flow_fields_description.radius_rsp_msg_type"),
    ["RADIUS_USER_NAME"] = i18n("flow_fields_description.radius_user_name"),
    ["RADIUS_CALLING_STATION_ID"] = i18n("flow_fields_description.radius_calling_station_id"),
    ["RADIUS_CALLED_STATION_ID"] = i18n("flow_fields_description.radius_called_station_id"),
    ["RADIUS_NAS_IP_ADDR"] = i18n("flow_fields_description.radius_nas_ip_addr"),
    ["RADIUS_NAS_IDENTIFIER"] = i18n("flow_fields_description.radius_nas_identifier"),
    ["RADIUS_USER_IMSI"] = i18n("flow_fields_description.radius_user_imsi"),
    ["RADIUS_USER_IMEI"] = i18n("flow_fields_description.radius_user_imei"),
    ["RADIUS_FRAMED_IP_ADDR"] = i18n("flow_fields_description.radius_framed_ip_addr"),
    ["RADIUS_ACCT_SESSION_ID"] = i18n("flow_fields_description.radius_acct_session_id"),
    ["RADIUS_ACCT_STATUS_TYPE"] = i18n("flow_fields_description.radius_acct_status_type"),
    ["RADIUS_ACCT_IN_OCTETS"] = i18n("flow_fields_description.radius_acct_in_octets"),
    ["RADIUS_ACCT_OUT_OCTETS"] = i18n("flow_fields_description.radius_acct_out_octets"),
    ["RADIUS_ACCT_IN_PKTS"] = i18n("flow_fields_description.radius_acct_in_pkts"),
    ["RADIUS_ACCT_OUT_PKTS"] = i18n("flow_fields_description.radius_acct_out_pkts"),

    -- RTP Plugin
    ["RTP_SSRC"] = i18n("flow_fields_description.rtp_ssrc"),
    ["RTP_FIRST_SEQ"] = i18n("flow_fields_description.rtp_first_seq"),
    ["RTP_FIRST_TS"] = i18n("flow_fields_description.rtp_first_ts"),
    ["RTP_LAST_SEQ"] = i18n("flow_fields_description.rtp_last_seq"),
    ["RTP_LAST_TS"] = i18n("flow_fields_description.rtp_last_ts"),
    ["RTP_IN_JITTER"] = i18n("flow_fields_description.rtp_in_jitter"),
    ["RTP_OUT_JITTER"] = i18n("flow_fields_description.rtp_out_jitter"),
    ["RTP_IN_PKT_LOST"] = i18n("flow_fields_description.rtp_in_pkt_lost"),
    ["RTP_OUT_PKT_LOST"] = i18n("flow_fields_description.rtp_out_pkt_lost"),
    ["RTP_IN_PKT_DROP"] = i18n("flow_fields_description.rtp_in_pkt_drop"),
    ["RTP_OUT_PKT_DROP"] = i18n("flow_fields_description.rtp_out_pkt_drop"),
    ["RTP_IN_PAYLOAD_TYPE"] = i18n("flow_fields_description.rtp_in_payload_type"),
    ["RTP_OUT_PAYLOAD_TYPE"] = i18n("flow_fields_description.rtp_out_payload_type"),
    ["RTP_IN_MAX_DELTA"] = i18n("flow_fields_description.rtp_in_max_delta"),
    ["RTP_OUT_MAX_DELTA"] = i18n("flow_fields_description.rtp_out_max_delta"),
    ["RTP_SIP_CALL_ID"] = i18n("flow_fields_description.rtp_sip_call_id"),
    ["RTP_MOS"] = i18n("flow_fields_description.rtp_mos"),
    ["RTP_IN_MOS"] = i18n("flow_fields_description.rtp_in_mos"),
    ["RTP_OUT_MOS"] = i18n("flow_fields_description.rtp_out_mos"),
    ["RTP_R_FACTOR"] = i18n("flow_fields_description.rtp_r_factor"),
    ["RTP_IN_R_FACTOR"] = i18n("flow_fields_description.rtp_in_r_factor"),
    ["RTP_OUT_R_FACTOR"] = i18n("flow_fields_description.rtp_out_r_factor"),
    ["RTP_IN_TRANSIT"] = i18n("flow_fields_description.rtp_in_transit"),
    ["RTP_OUT_TRANSIT"] = i18n("flow_fields_description.rtp_out_transit"),
    ["RTP_RTT"] = i18n("flow_fields_description.rtp_rtt"),
    ["RTP_DTMF_TONES"] = i18n("flow_fields_description.rtp_dtmf_tones"),

    -- S1AP Protocol
    ["S1AP_ENB_UE_S1AP_ID"] = i18n("flow_fields_description.s1ap_enb_ue_s1ap_id"),
    ["S1AP_MME_UE_S1AP_ID"] = i18n("flow_fields_description.s1ap_mme_ue_s1ap_id"),
    ["S1AP_MSG_EMM_TYPE_MME_TO_ENB"] = i18n("flow_fields_description.s1ap_msg_emm_type_mme_to_enb"),
    ["S1AP_MSG_ESM_TYPE_MME_TO_ENB"] = i18n("flow_fields_description.s1ap_msg_esm_type_mme_to_enb"),
    ["S1AP_MSG_EMM_TYPE_ENB_TO_MME"] = i18n("flow_fields_description.s1ap_msg_emm_type_enb_to_mme"),
    ["S1AP_MSG_ESM_TYPE_ENB_TO_MME"] = i18n("flow_fields_description.s1ap_msg_esm_type_enb_to_mme"),
    ["S1AP_CAUSE_ENB_TO_MME"] = i18n("flow_fields_description.s1ap_cause_enb_to_mme"),
    ["S1AP_DETAILED_CAUSE_ENB_TO_MME"] = i18n("flow_fields_description.s1ap_detailed_cause_enb_to_mme"),

    -- SIP Plugin
    ["SIP_CALL_ID"] = i18n("flow_fields_description.sip_call_id"),
    ["SIP_CALLING_PARTY"] = i18n("flow_fields_description.sip_calling_party"),
    ["SIP_CALLED_PARTY"] = i18n("flow_fields_description.sip_called_party"),
    ["SIP_RTP_CODECS"] = i18n("flow_fields_description.sip_rtp_codecs"),
    ["SIP_INVITE_TIME"] = i18n("flow_fields_description.sip_invite_time"),
    ["SIP_TRYING_TIME"] = i18n("flow_fields_description.sip_trying_time"),
    ["SIP_RINGING_TIME"] = i18n("flow_fields_description.sip_ringing_time"),
    ["SIP_INVITE_OK_TIME"] = i18n("flow_fields_description.sip_invite_ok_time"),
    ["SIP_INVITE_FAILURE_TIME"] = i18n("flow_fields_description.sip_invite_failure_time"),
    ["SIP_BYE_TIME"] = i18n("flow_fields_description.sip_bye_time"),
    ["SIP_BYE_OK_TIME"] = i18n("flow_fields_description.sip_bye_ok_time"),
    ["SIP_CANCEL_TIME"] = i18n("flow_fields_description.sip_cancel_time"),
    ["SIP_CANCEL_OK_TIME"] = i18n("flow_fields_description.sip_cancel_ok_time"),
    ["SIP_RTP_IPV4_SRC_ADDR"] = i18n("flow_fields_description.sip_rtp_ipv4_src_addr"),
    ["SIP_RTP_L4_SRC_PORT"] = i18n("flow_fields_description.sip_rtp_l4_src_port"),
    ["SIP_RTP_IPV4_DST_ADDR"] = i18n("flow_fields_description.sip_rtp_ipv4_dst_addr"),
    ["SIP_RTP_L4_DST_PORT"] = i18n("flow_fields_description.sip_rtp_l4_dst_port"),
    ["SIP_RESPONSE_CODE"] = i18n("flow_fields_description.sip_response_code"),
    ["SIP_REASON_CAUSE"] = i18n("flow_fields_description.sip_reason_cause"),
    ["SIP_C_IP"] = i18n("flow_fields_description.sip_c_ip"),
    ["SIP_CALL_STATE"] = i18n("flow_fields_description.sip_call_state"),

    -- SMTP Protocol
    ["SMTP_MAIL_FROM"] = i18n("flow_fields_description.smtp_mail_from"),
    ["SMTP_RCPT_TO"] = i18n("flow_fields_description.smtp_rcpt_to"),

    -- SSDP Protocol
    ["SSDP_HOST"] = i18n("flow_fields_description.ssdp_host"),
    ["SSDP_USN"] = i18n("flow_fields_description.ssdp_usn"),
    ["SSDP_SERVER"] = i18n("flow_fields_description.ssdp_server"),
    ["SSDP_TYPE"] = i18n("flow_fields_description.ssdp_type"),
    ["SSDP_METHOD"] = i18n("flow_fields_description.ssdp_method"),
 }

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

function getFlowLabel(flow, show_macs, add_hyperlinks)
   if flow == nil then return "" end

   local cli_name = shortenString(flowinfo2hostname(flow, "cli"))
   local srv_name = shortenString(flowinfo2hostname(flow, "srv"))

   local cli_port
   local srv_port
   if flow["cli.port"] > 0 then cli_port = flow["cli.port"] end
   if flow["srv.port"] > 0 then srv_port = flow["srv.port"] end

   local srv_mac
   if(not isEmptyString(flow["srv.mac"]) and flow["srv.mac"] ~= "00:00:00:00:00:00") then
      srv_mac = flow["srv.mac"]
   end

   local cli_mac
   if(flow["cli.mac"] ~= nil and flow["cli.mac"]~= "" and flow["cli.mac"] ~= "00:00:00:00:00:00") then
      cli_mac = flow["cli.mac"]
   end

   if add_hyperlinks then
      cli_name = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(flow,"cli") .. "\">"
      cli_name = cli_name..shortenString(flowinfo2hostname(flow,"cli"))
      if(flow["cli.systemhost"] == true) then
	 cli_name = cli_name.." <i class='fa fa-flag' aria-hidden='true'></i>"
      end
      if(flow["cli.blacklisted"] == true) then
	 cli_name = cli_name.." <i class='fa fa-ban' aria-hidden='true' title='Blacklisted'></i>"
      end
      cli_name = cli_name.."</A>"

      srv_name = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(flow,"srv") .. "\">"
      srv_name = srv_name..shortenString(flowinfo2hostname(flow,"srv"))
      if(flow["srv.systemhost"] == true) then
	 srv_name = srv_name.." <i class='fa fa-flag' aria-hidden='true'></i>"
      end
      if(flow["srv.blacklisted"] == true) then
	 srv_name = srv_name.." <i class='fa fa-ban' aria-hidden='true' title='Blacklisted'></i>"
      end
      srv_name = srv_name.."</A>"

      if cli_port then
	 cli_port = "<A HREF=\""..ntop.getHttpPrefix().."/lua/port_details.lua?port=" ..cli_port.. "\">"..cli_port.."</A>"
      end

      if srv_port then
	 srv_port = "<A HREF=\""..ntop.getHttpPrefix().."/lua/port_details.lua?port=" ..srv_port.. "\">"..srv_port.."</A>"
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

   if cli_port then
      label = label..":"..cli_port
   end

   if show_macs and cli_mac then
      label = label.." [ "..cli_mac.." ]"
   end

   label = label.." <i class=\"fa fa-exchange fa-lg\"  aria-hidden=\"true\"></i> "

   if not isEmptyString(srv_name) then
      label = label..srv_name
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
   local s = flow_fields_description[name]

   if(s == nil) then
      v = rtemplate[tonumber(name)]
      if(v == nil) then return(name) end
      
      s = flow_fields_description[v]
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

function isFieldProtocol(protocol, field)
   if((field ~= nil) and (protocol ~= nil)) then
      if(starts(field, protocol)) then
	 return true
      end
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

function getFlowValue(info, field)
   local return_value = "0"
   local value_original = "0"

   if(info[field] ~= nil) then
      return_value = info[field]
      value_original = info[field]
   else
      for key,value in pairs(info) do
	 if(rtemplate[tonumber(key)] == field) then
	    return_value = handleCustomFlowField(key, value)
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
      if(isFieldProtocol(protocol, key)) then	
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
        returnString =  calling_party .. " <i class='fa fa-exchange fa-sm' aria-hidden='true'></i> " .. called_party
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
	call_id = "<i class='fa fa-phone fa-sm' aria-hidden='true' title='SIP Call-ID'></i>&nbsp;"..call_id
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
   local call_id_ico = "<i class='fa fa-phone' aria-hidden='true'></i>&nbsp;"
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
       string_table = string_table.."<tr id=\"called_calling_tr\" style=\"display: none;\"><th>"..i18n("flow_details.call_initiator").." <i class=\"fa fa-exchange fa-lg\"></i> "..i18n("flow_details.called_party").."</th><td colspan=2><div id=calling_called_party></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"called_calling_tr\" style=\"display: table-row;\"><th>"..i18n("flow_details.call_initiator").." <i class=\"fa fa-exchange fa-lg\"></i> "..i18n("flow_details.called_party").."</th><td colspan=2><div id=calling_called_party>" .. calling_party .. " <i class=\"fa fa-exchange fa-lg\"></i> " .. called_party .. "</div></td></tr>\n"
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
       --string_table = string_table.." <i class=\"fa fa-exchange fa-lg\"></i> "
       string_table_3 = " <i class=\"fa fa-exchange fa-lg\"></i> "
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
       string_table = string_table.."<tr id=\"rtp_stream_tr\" style=\"display: table-row;\"><th width=33%>"..i18n("flow_details.rtp_stream_peers").." (src <i class=\"fa fa-exchange fa-lg\"></i> dst)</th><td colspan=2><div id=rtp_stream>"
     else
       string_table = string_table.."<tr id=\"rtp_stream_tr\" style=\"display: none;\"><th width=33%>"..i18n("flow_details.rtp_stream_peers").." (src <i class=\"fa fa-exchange fa-lg\"></i> dst)</th><td colspan=2><div id=rtp_stream>"
     end
     string_table = string_table..string_table_1..string_table_2..string_table_3..string_table_4..string_table_5

     local rtp_flow_key  = interface.getFlowKey(sip_rtp_src_address_ip or "", tonumber(sip_rtp_src_port) or 0,
						sip_rtp_dst_address_ip or "", tonumber(sip_rtp_dst_port) or 0,
						17 --[[ UDP --]])
     if tonumber(rtp_flow_key) ~= nil and interface.findFlowByKey(tonumber(rtp_flow_key)) ~= nil then
	string_table = string_table..'&nbsp;'
	string_table = string_table.."<A HREF=\""..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key="..rtp_flow_key
	string_table = string_table.."&label="..sip_rtp_src_address_ip..":"..sip_rtp_src_port
	string_table = string_table.." <-> "
	string_table = string_table..sip_rtp_dst_address_ip..":"..sip_rtp_dst_port.."\">"
	string_table = string_table..'<span class="label label-info">'..i18n("flow_details.rtp_flow")..'</span></a>'
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
     if(info["SIP_C_IP"]  ~= nil) then
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
   local rtp_found = isThereProtocol("RTP_IN_MAX_DELTA", info)

   if(rtp_found == 1) then
      -- SSRC
      string_table = string_table.."<tr><th colspan=3 class=\"info\" >"..i18n("flow_details.rtp_protocol_information").."</th></tr>\n"
      if(info["RTP_SSRC"] ~= nil) then
	 sync_source_var = getFlowValue(info, "RTP_SSRC")
	 if((sync_source_var == nil) or (sync_source_var == "")) then
	    sync_source_hide = "style=\"display: none;\""
	 else
	    sync_source_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table.."<tr id=\"sync_source_id_tr\" "..sync_source_hide.." ><th> "..i18n("flow_details.sync_source_id").." </th><td colspan=2><div id=sync_source_id>" .. sync_source_var .. "</td></tr>\n"
      end
      
      -- ROUND-TRIP-TIME
      if(info["RTP_RTT"] ~= nil) then	 
	 rtp_rtt_var = getFlowValue(info, "RTP_RTT")
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
      if(info["RTP_IN_TRANSIT"] ~= nil) then	 
	 rtp_in_transit = getFlowValue(info, "RTP_IN_TRANSIT")/100
	 rtp_out_transit = getFlowValue(info, "RTP_OUT_TRANSIT")/100
	 if(((rtp_in_transit == nil) or (rtp_in_transit == "")) and ((rtp_out_transit == nil) or (rtp_out_transit == ""))) then
	    rtp_transit_hide = "style=\"display: none;\""
	 else
	    rtp_transit_hide = "style=\"display: table-row;\""
	 end
	 
	 string_table = string_table .. "<tr id=\"rtp_transit_id_tr\" "..rtp_transit_hide.."><th>"..i18n("flow_details.rtp_transit_in_out").."</th><td><div id=rtp_transit_in>"..getFlowValue(info, "RTP_IN_TRANSIT").."</div></td><td><div id=rtp_transit_out>"..getFlowValue(info, "RTP_OUT_TRANSIT").."</div></td></tr>\n"
      end
      
      -- TONES
      if(info["RTP_DTMF_TONES"] ~= nil) then	 
	 rtp_dtmf_var = getFlowValue(info, "RTP_DTMF_TONES")
	 if((rtp_dtmf_var == nil) or (rtp_dtmf_var == "")) then
	    rtp_dtmf_hide = "style=\"display: none;\""
	 else
	    rtp_dtmf_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"dtmf_id_tr\" ".. rtp_dtmf_hide .."><th>"..i18n("flow_details.dtmf_tones_sent").."</th><td colspan=2><span id=dtmf_tones>"..rtp_dtmf_var.."</span></td></tr>\n"
      end
	 
      -- FIRST REQUEST
      if(info["RTP_FIRST_SEQ"] ~= nil) then         
	 first_flow_sequence_var = getFlowValue(info, "RTP_FIRST_SEQ")
	 last_flow_sequence_var = getFlowValue(info, "RTP_FIRST_SEQ")
	 if(((first_flow_sequence_var == nil) or (first_flow_sequence_var == "")) and ((last_flow_sequence_var == nil) or (last_flow_sequence_var == ""))) then
	    first_last_flow_sequence_hide = "style=\"display: none;\""
	 else
	    first_last_flow_sequence_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"first_last_flow_sequence_id_tr\" "..first_last_flow_sequence_hide.."><th>"..i18n("flow_details.first_last_flow_sequence").."</th><td><div id=first_flow_sequence>"..first_flow_sequence_var.."</div></td><td><div id=last_flow_sequence>"..last_flow_sequence_var.."</div></td></tr>\n"
      end
      
      -- CALL-ID
      if(info["RTP_SIP_CALL_ID"] ~= nil) then	 
	 sip_call_id_var = getFlowValue(info, "RTP_SIP_CALL_ID")
	 if((sip_call_id_var == nil) or (sip_call_id_var == "")) then
	    sip_call_id_hide = "style=\"display: none;\""
      else
	 sip_call_id_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"sip_call_id_tr\" "..sip_call_id_hide.."><th> "..i18n("flow_details.sip_call_id").." <i class='fa fa-phone fa-sm' aria-hidden='true' title='SIP Call-ID'></i>&nbsp;</th><td colspan=2><div id=rtp_sip_call_id>" .. sip_call_id_var .. "</div></td></tr>\n"
      end
      
      -- TWO-WAY CALL-QUALITY INDICATORS
      string_table = string_table.."<tr><th>"..i18n("flow_details.call_quality_indicators").."</th><th>"..i18n("flow_details.forward").."</th><th>"..i18n("flow_details.reverse").."</th></tr>"
      -- JITTER
      if(info["RTP_IN_JITTER"] ~= nil) then	 
	 rtp_in_jitter = getFlowValue(info, "RTP_IN_JITTER")/100
	 rtp_out_jitter = getFlowValue(info, "RTP_OUT_JITTER")/100
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
      if(info["RTP_IN_PKT_LOST"] ~= nil) then	 
	 rtp_in_pkt_lost = getFlowValue(info, "RTP_IN_PKT_LOST")
	 rtp_out_pkt_lost = getFlowValue(info, "RTP_OUT_PKT_LOST")
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
      if(info["RTP_IN_PKT_DROP"] ~= nil) then	 
	 rtp_in_pkt_drop = getFlowValue(info, "RTP_IN_PKT_DROP")
	 rtp_out_pkt_drop = getFlowValue(info, "RTP_OUT_PKT_DROP")
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
      if(info["RTP_IN_MAX_DELTA"] ~= nil) then	 
	 rtp_in_max_delta = getFlowValue(info, "RTP_IN_MAX_DELTA")
	 rtp_out_max_delta = getFlowValue(info, "RTP_OUT_MAX_DELTA")
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
      if(info["RTP_IN_PAYLOAD_TYPE"] ~= nil) then	 
	 rtp_payload_in_var  = formatRtpPayloadType(getFlowValue(info, "RTP_IN_PAYLOAD_TYPE"))
	 rtp_payload_out_var = formatRtpPayloadType(getFlowValue(info, "RTP_OUT_PAYLOAD_TYPE"))
	 if(((rtp_payload_in_var == nil) or (rtp_payload_in_var == "")) and ((rtp_payload_out_var == nil) or (rtp_payload_out_var == ""))) then
	    rtp_payload_hide = "style=\"display: none;\""
	 else
	    rtp_payload_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"payload_id_tr\" "..rtp_payload_hide.."><th style=\"text-align:right\">"..i18n("flow_details.payload_type").."</th><td><div id=payload_type_in>"..rtp_payload_in_var.."</div></td><td><div id=payload_type_out>"..rtp_payload_out_var.."</div></td></tr>\n"
      end
	    
      -- MOS
      if(info["RTP_IN_MOS"] ~= nil) then		 
	 rtp_in_mos = getFlowValue(info, "RTP_IN_MOS")/100
	 rtp_out_mos = getFlowValue(info, "RTP_OUT_MOS")/100
	 if(rtp_in_mos == nil or rtp_in_mos == "") and (rtp_out_mos == nil or rtp_out_mos == "") then
	    quality_mos_hide = "style=\"display: none;\""
	 else
	    quality_mos_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"quality_mos_id_tr\" ".. quality_mos_hide .."><th style=\"text-align:right\">"..i18n("flow_details.pseudo_mos").."</th><td><span id=mos_in_signal></span><span id=mos_in>"
	 if((rtp_in_mos ~= nil) and (rtp_in_mos ~= "")) then
	    string_table = string_table .. MosPercentageBar(rtp_in_mos)
	 end
	 string_table = string_table .. "</span> <span id=mos_in_trend></span></td>"
	 
	 string_table = string_table .. "<td><span id=mos_out_signal></span><span id=mos_out>"
	 if((rtp_out_mos ~= nil) and (rtp_out_mos ~= "")) then
	    string_table = string_table .. MosPercentageBar(rtp_out_mos)
	 end
	 string_table = string_table .. "</span> <span id=mos_out_trend></span></td></tr>"
      end
      
      -- R_FACTOR
      if(info["RTP_IN_R_FACTOR"] ~= nil) then
	 rtp_in_r_factor = getFlowValue(info, "RTP_IN_R_FACTOR")/100
	 rtp_out_r_factor = getFlowValue(info, "RTP_OUT_R_FACTOR")/100
	 
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
  local pool_id, quota_protocol, quota_is_category

  if as_client then
    pool_id = info["cli.pool_id"]
    quota_protocol = info["cli.quota_applied_proto"]
    quota_is_category = info["cli.quota_is_category"]
  else
    pool_id = info["srv.pool_id"]
    quota_protocol = info["srv.quota_applied_proto"]
    quota_is_category = info["srv.quota_is_category"]
  end

  local master_proto, app_proto = splitProtocol(info["proto.ndpi"])
  app_proto = app_proto or master_proto

  local pools_stats = interface.getHostPoolsStats()
  local pool_stats = pools_stats and pools_stats[tonumber(pool_id)]

  if pool_stats ~= nil then
    local application = ternary(quota_protocol == "master", master_proto, app_proto)
    local key, category_stats, proto_stats

    if quota_is_category then
      -- the quota is being applied on the protocol category
      key = interface.getnDPIProtoCategory(interface.getnDPIProtoId(application)).name
      proto_stats = nil
      category_stats = pool_stats.ndpi_categories
    else
      -- the quota is being applied on the protocol itself
      key = application
      proto_stats = pool_stats.ndpi
      category_stats = nil
    end

    local quota_and_protos = shaper_utils.getPoolProtoShapers(ifid, pool_id)
    local proto_info = quota_and_protos[key]

    if proto_info ~= nil then
      return proto_info, proto_stats, category_stats
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
