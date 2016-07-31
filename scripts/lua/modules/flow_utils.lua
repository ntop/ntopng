--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"

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

function handleCustomFlowField(key, value)
   if((key == 'TCP_FLAGS') or (key == '6')) then
      return(formatTcpFlags(value))
   elseif((key == 'INPUT_SNMP') or (key == '10')
	     or (key == 'OUTPUT_SNMP') or (key == '14')) then
      return(formatInterfaceId(value))
   elseif((key == 'EXPORTER_IPV4_ADDRESS') or (key == '130')) then
      local b1, b2, b3, b4 = value:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
      b1 = tonumber(b1)
      b2 = tonumber(b2)
      b3 = tonumber(b3)
      b4 = tonumber(b4)
      local ipaddr = string.format('%d.%d.%d.%d', b4, b3, b2, b1)
      local res = ntop.getResolvedAddress(ipaddr)

      local ret = "<A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?host="..ipaddr..">"

      if((res == "") or (res == nil)) then
	 ret = ret .. ipaddr
      else
	 ret = ret .. res
      end

      return(ret .. "</A>")
   elseif((key == 'FLOW_USER_NAME') or (key == '57593')) then
      elems = string.split(value, ';')

      if((elems ~= nil) and (table.getn(elems) == 6)) then
          r = '<table class="table table-bordered table-striped">'
	  imsi = elems[1]
	  mcc = string.sub(imsi, 1, 3)

	  if(mobile_country_code[mcc] ~= nil) then
    	    mcc_name = " ["..mobile_country_code[mcc].."]"
	  else
   	    mcc_name = ""
	  end

          r = r .. "<th>IMSI (International mobile Subscriber Identity)</th><td>"..elems[1]..mcc_name
	  r = r .. " <A HREF=http://www.numberingplans.com/?page=analysis&sub=imsinr><i class='fa fa-info'></i></A></td></tr>"
	  r = r .. "<th>NSAPI</th><td>".. elems[2].."</td></tr>"
	  r = r .. "<th>GSM Cell LAC (Location Area Code)</th><td>".. elems[3].."</td></tr>"
	  r = r .. "<th>GSM Cell Identifier</th><td>".. elems[4].."</td></tr>"
	  r = r .. "<th>SAC (Service Area Code)</th><td>".. elems[5].."</td></tr>"
	  r = r .. "<th>IP Address</th><td>".. ntop.inet_ntoa(elems[6]).."</td></tr>"
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

   rsp = "<A HREF=http://en.wikipedia.org/wiki/Transmission_Control_Protocol>"
   if(bit.band(flags, 1) == 2)  then rsp = rsp .. " SYN "  end
   if(bit.band(flags, 16) == 16) then rsp = rsp .. " ACK "  end
   if(bit.band(flags, 1) == 1)  then rsp = rsp .. " FIN "  end
   if(bit.band(flags, 4) == 4)  then rsp = rsp .. " RST "  end
   if(bit.band(flags, 8) == 8 )  then rsp = rsp .. " PUSH " end

   return(rsp .. "</A>")
end

-- #######################

function formatInterfaceId(id)
   if(id == 65535) then
      return("Unknown")
   else
      return(id)
   end
end

-- #######################

-- IMPORTANT: keep it in sync with ParserInterface::ParserInterface()

local flow_fields_description = {
    ["IN_BYTES"] = "Incoming flow bytes (src->dst)",
    ["IN_PKTS"] = "Incoming flow packets (src->dst)",
    ["FLOWS"] = "Number of flows",
    ["PROTOCOL"] = "IP protocol byte",
    ["PROTOCOL_MAP"] = "IP protocol name",
    ["SRC_TOS"] = "Type of service (TOS)",
    ["TCP_FLAGS"] = "Cumulative of all flow TCP flags",
    ["L4_SRC_PORT"] = "IPv4 source port",
    ["L4_SRC_PORT_MAP"] = "Layer 4 source port symbolic name",
    ["IPV4_SRC_ADDR"] = "IPv4 source address",
    ["IPV4_SRC_MASK"] = "IPv4 source subnet mask (/<bits>)",
    ["INPUT_SNMP"] = "Input interface SNMP idx",
    ["L4_DST_PORT"] = "IPv4 destination port",
    ["L4_DST_PORT_MAP"] = "Layer 4 destination port symbolic name",
    ["L4_SRV_PORT"] = "Layer 4 server port",
    ["L4_SRV_PORT_MAP"] = "Layer 4 server port symbolic name",
    ["IPV4_DST_ADDR"] = "IPv4 destination address",
    ["IPV4_DST_MASK"] = "IPv4 dest subnet mask (/<bits>)",
    ["OUTPUT_SNMP"] = "Output interface SNMP idx",
    ["IPV4_NEXT_HOP"] = "IPv4 Next Hop",
    ["SRC_AS"] = "Source BGP AS",
    ["DST_AS"] = "Destination BGP AS",
    ["LAST_SWITCHED"] = "SysUptime (msec) of the last flow pkt",
    ["FIRST_SWITCHED"] = "SysUptime (msec) of the first flow pkt",
    ["OUT_BYTES"] = "Outgoing flow bytes (dst->src)",
    ["OUT_PKTS"] = "Outgoing flow packets (dst->src)",
    ["IPV6_SRC_ADDR"] = "IPv6 source address",
    ["IPV6_DST_ADDR"] = "IPv6 destination address",
    ["IPV6_SRC_MASK"] = "IPv6 source mask",
    ["IPV6_DST_MASK"] = "IPv6 destination mask",
    ["ICMP_TYPE"] = "ICMP Type * 256 + ICMP code",
    ["SAMPLING_INTERVAL"] = "Sampling rate",
    ["SAMPLING_ALGORITHM"] = "Sampling type (deterministic/random)",
    ["FLOW_ACTIVE_TIMEOUT"] = "Activity timeout of flow cache entries",
    ["FLOW_INACTIVE_TIMEOUT"] = "Inactivity timeout of flow cache entries",
    ["ENGINE_TYPE"] = "Flow switching engine",
    ["ENGINE_ID"] = "Id of the flow switching engine",
    ["TOTAL_BYTES_EXP"] = "Total bytes exported",
    ["TOTAL_PKTS_EXP"] = "Total flow packets exported",
    ["TOTAL_FLOWS_EXP"] = "Total number of exported flows",
    ["MIN_TTL"] = "Min flow TTL",
    ["MAX_TTL"] = "Max flow TTL",
    ["DST_TOS"] = "TOS/DSCP (dst->src)",
    ["IN_SRC_MAC"] = "Source MAC Address",
    ["SRC_VLAN"] = "Source VLAN",
    ["DST_VLAN"] = "Destination VLAN",
    ["DOT1Q_SRC_VLAN"] = "Source VLAN (outer VLAN in QinQ)",
    ["DOT1Q_DST_VLAN"] = "Destination VLAN (outer VLAN in QinQ)",
    ["IP_PROTOCOL_VERSION"] = "4=IPv4]6=IPv6]",
    ["DIRECTION"] = "It indicates where a sample has been taken (always 0)",
    ["IPV6_NEXT_HOP"] = "IPv6 next hop address",
    ["MPLS_LABEL_1"] = "MPLS label at position 1",
    ["MPLS_LABEL_2"] = "MPLS label at position 2",
    ["MPLS_LABEL_3"] = "MPLS label at position 3",
    ["MPLS_LABEL_4"] = "MPLS label at position 4",
    ["MPLS_LABEL_5"] = "MPLS label at position 5",
    ["MPLS_LABEL_6"] = "MPLS label at position 6",
    ["MPLS_LABEL_7"] = "MPLS label at position 7",
    ["MPLS_LABEL_8"] = "MPLS label at position 8",
    ["MPLS_LABEL_9"] = "MPLS label at position 9",
    ["MPLS_LABEL_10"] = "MPLS label at position 10",
    ["OUT_DST_MAC"] = "Destination MAC Address",
    ["APPLICATION_ID"] = "Cisco NBAR Application Id",
    ["PACKET_SECTION_OFFSET"] = "Packet section offset",
    ["SAMPLED_PACKET_SIZE"] = "Sampled packet size",
    ["SAMPLED_PACKET_ID"] = "Sampled packet id",
    ["EXPORTER_IPV4_ADDRESS"] = "Exporter IPv4 Address",
    ["EXPORTER_IPV6_ADDRESS"] = "Exporter IPv6 Address",
    ["FLOW_ID"] = "Serial Flow Identifier",
    ["FLOW_START_SEC"] = "Seconds (epoch) of the first flow packet",
    ["FLOW_END_SEC"] = "Seconds (epoch) of the last flow packet",
    ["FLOW_START_MILLISECONDS"] = "Msec (epoch) of the first flow packet",
    ["FLOW_END_MILLISECONDS"] = "Msec (epoch) of the last flow packet",
    ["BIFLOW_DIRECTION"] = "1=initiator,  2=reverseInitiator",
    ["OBSERVATION_POINT_TYPE"] = "Observation point type",
    ["OBSERVATION_POINT_ID"] = "Observation point id",
    ["SELECTOR_ID"] = "Selector id",
    ["IPFIX_SAMPLING_ALGORITHM"] = "Sampling algorithm",
    ["SAMPLING_SIZE"] = "Number of packets to sample",
    ["SAMPLING_POPULATION"] = "Sampling population",
    ["FRAME_LENGTH"] = "Original L2 frame length",
    ["PACKETS_OBSERVED"] = "Tot number of packets seen",
    ["PACKETS_SELECTED"] = "Number of pkts selected for sampling",
    ["SELECTOR_NAME"] = "Sampler name",
    ["APPLICATION_NAME"] = "Palo Alto App-Id",
    ["USER_NAME"] = "Palo Alto User-Id",
    ["FRAGMENTS"] = "Number of fragmented flow packets",
    ["CLIENT_NW_DELAY_SEC"] = "Network latency client <-> nprobe (sec)",
    ["CLIENT_NW_DELAY_USEC"] = "Network latency client <-> nprobe (residual usec)",
    ["CLIENT_NW_DELAY_MS"] = "Network latency client <-> nprobe (msec)",
    ["SERVER_NW_DELAY_SEC"] = "Network latency nprobe <-> server (sec)",
    ["SERVER_NW_DELAY_USEC"] = "Network latency nprobe <-> server (residual usec)",
    ["SERVER_NW_DELAY_MS"] = "Network latency nprobe <-> server (residual msec)",
    ["APPL_LATENCY_SEC"] = "Application latency (sec)",
    ["APPL_LATENCY_USEC"] = "Application latency (residual usec)",
    ["APPL_LATENCY_MS"] = "Application latency (msec)",
    ["NUM_PKTS_UP_TO_128_BYTES"] = "# packets whose size <= 128",
    ["NUM_PKTS_128_TO_256_BYTES"] = "# packets whose size > 128 and <= 256",
    ["NUM_PKTS_256_TO_512_BYTES"] = "# packets whose size > 256 and < 512",
    ["NUM_PKTS_512_TO_1024_BYTES"] = "# packets whose size > 512 and < 1024",
    ["NUM_PKTS_1024_TO_1514_BYTES"] = "# packets whose size > 1024 and <= 1514",
    ["NUM_PKTS_OVER_1514_BYTES"] = "# packets whose size > 1514",
    ["CUMULATIVE_ICMP_TYPE"] = "Cumulative OR of ICMP type packets",
    ["SRC_IP_COUNTRY"] = "Country where the src IP is located",
    ["SRC_IP_CITY"] = "City where the src IP is located",
    ["DST_IP_COUNTRY"] = "Country where the dst IP is located",
    ["DST_IP_CITY"] = "City where the dst IP is located",
    ["FLOW_PROTO_PORT"] = "L7 port that identifies the flow protocol or 0 if unknown",
    ["UPSTREAM_TUNNEL_ID"] = "Upstream tunnel identifier (e.g. GTP TEID) or 0 if unknown",
    ["LONGEST_FLOW_PKT"] = "Longest packet (bytes) of the flow",
    ["SHORTEST_FLOW_PKT"] = "Shortest packet (bytes) of the flow",
    ["RETRANSMITTED_IN_PKTS"] = "Number of retransmitted TCP flow packets (src->dst)",
    ["RETRANSMITTED_IN_BYTES"] = "Number of retransmitted TCP flow bytes (src->dst)",
    ["RETRANSMITTED_OUT_PKTS"] = "Number of retransmitted TCP flow packets (dst->src)",
    ["RETRANSMITTED_OUT_BYTES"] = "Number of retransmitted TCP flow bytes (dst->src)",
    ["OOORDER_IN_PKTS"] = "Number of out of order TCP flow packets (dst->src)",
    ["OOORDER_OUT_PKTS"] = "Number of out of order TCP flow packets (dst->src)",
    ["UNTUNNELED_PROTOCOL"] = "Untunneled IP protocol byte",
    ["UNTUNNELED_IPV4_SRC_ADDR"] = "Untunneled IPv4 source address",
    ["UNTUNNELED_L4_SRC_PORT"] = "Untunneled IPv4 source port",
    ["UNTUNNELED_IPV4_DST_ADDR"] = "Untunneled IPv4 destination address",
    ["UNTUNNELED_L4_DST_PORT"] = "Untunneled IPv4 destination port",
    ["L7_PROTO"] = "Layer 7 protocol (numeric)",
    ["L7_PROTO_NAME"] = "Layer 7 protocol name",
    ["DOWNSTREAM_TUNNEL_ID"] = "Downstream tunnel identifier (e.g. GTP TEID) or 0 if unknown",
    ["FLOW_USER_NAME"] = "Flow Username",
    ["FLOW_SERVER_NAME"] = "Flow server name",
    ["PLUGIN_NAME"] = "Plugin name used by this flow (if any)",
    ["UNTUNNELED_IPV6_SRC_ADDR"] = "Untunneled IPv6 source address",
    ["UNTUNNELED_IPV6_DST_ADDR"] = "Untunneled IPv6 destination address",
    ["SRC_IP_LONG"] = "Longitude where the src IP is located",
    ["SRC_IP_LAT"] = "Latitude where the src IP is located",
    ["DST_IP_LONG"] = "Longitude where the dst IP is located",
    ["DST_IP_LAT"] = "Latitude where the dst IP is located",
    ["NUM_PKTS_TTL_EQ_1"] = "# packets with TTL = 1",
    ["NUM_PKTS_TTL_2_5"] = "# packets with TTL > 1 and TTL <= 5",
    ["NUM_PKTS_TTL_5_32"] = "# packets with TTL > 5 and TTL <= 32",
    ["NUM_PKTS_TTL_32_64"] = "# packets with TTL > 32 and <= 64 ",
    ["NUM_PKTS_TTL_64_96"] = "# packets with TTL > 64 and <= 96",
    ["NUM_PKTS_TTL_96_128"] = "# packets with TTL > 96 and <= 128",
    ["NUM_PKTS_TTL_128_160"] = "# packets with TTL > 128 and <= 160",
    ["NUM_PKTS_TTL_160_192"] = "# packets with TTL > 160 and <= 192",
    ["NUM_PKTS_TTL_192_224"] = "# packets with TTL > 192 and <= 224",
    ["NUM_PKTS_TTL_224_255"] = "# packets with TTL > 224 and <= 255",
    ["IN_SRC_OSI_SAP"] = "OSI Source SAP (OSI Traffic Only)",
    ["OUT_DST_OSI_SAP"] = "OSI Destination SAP (OSI Traffic Only)",
    ["DURATION_IN"] = "Client to Server stream duration (msec)",
    ["DURATION_OUT"] = "Client to Server stream duration (msec)",
    ["TCP_WIN_MIN_IN"] = "Min TCP Window (src->dst)",
    ["TCP_WIN_MAX_IN"] = "Max TCP Window (src->dst)",
    ["TCP_WIN_MSS_IN"] = "TCP Max Segment Size (src->dst)",
    ["TCP_WIN_SCALE_IN"] = "TCP Window Scale (src->dst)",
    ["TCP_WIN_MIN_OUT"] = "Min TCP Window (dst->src)",
    ["TCP_WIN_MAX_OUT"] = "Max TCP Window (dst->src)",
    ["TCP_WIN_MSS_OUT"] = "TCP Max Segment Size (dst->src)",
    ["TCP_WIN_SCALE_OUT"] = "TCP Window Scale (dst->src)",

    -- MYSQL
    ["MYSQL_SERVER_VERSION"] = "MySQL server version",
    ["MYSQL_USERNAME"] = "MySQL username",
    ["MYSQL_DB"] = "MySQL database in use",
    ["MYSQL_QUERY"] = "MySQL Query",
    ["MYSQL_RESPONSE"] = "MySQL server response",
    ["MYSQL_APPL_LATENCY_USEC"] = "MySQL request->response latecy (usec)",

    ["SRC_AS_PATH_1"] = "Src AS path position 1",
    ["SRC_AS_PATH_2"] = "Src AS path position 2",
    ["SRC_AS_PATH_3"] = "Src AS path position 3",
    ["SRC_AS_PATH_4"] = "Src AS path position 4",
    ["SRC_AS_PATH_5"] = "Src AS path position 5",
    ["SRC_AS_PATH_6"] = "Src AS path position 6",
    ["SRC_AS_PATH_7"] = "Src AS path position 7",
    ["SRC_AS_PATH_8"] = "Src AS path position 8",
    ["SRC_AS_PATH_9"] = "Src AS path position 9",
    ["SRC_AS_PATH_10"] = "Src AS path position 10",
    ["DST_AS_PATH_1"] = "Dest AS path position 1",
    ["DST_AS_PATH_2"] = "Dest AS path position 2",
    ["DST_AS_PATH_3"] = "Dest AS path position 3",
    ["DST_AS_PATH_4"] = "Dest AS path position 4",
    ["DST_AS_PATH_5"] = "Dest AS path position 5",
    ["DST_AS_PATH_6"] = "Dest AS path position 6",
    ["DST_AS_PATH_7"] = "Dest AS path position 7",
    ["DST_AS_PATH_8"] = "Dest AS path position 8",
    ["DST_AS_PATH_9"] = "Dest AS path position 9",
    ["DST_AS_PATH_10"] = "Dest AS path position 10",

    -- DHCP
    ["DHCP_CLIENT_MAC"] = "MAC of the DHCP client",
    ["DHCP_CLIENT_IP"] = "DHCP assigned client IPv4 address",
    ["DHCP_CLIENT_NAME"] = "DHCP client name",
    ["DHCP_REMOTE_ID"] = "DHCP agent remote Id",
    ["DHCP_SUBSCRIBER_ID"] = "DHCP subscribed Id",
    ["DHCP_MESSAGE_TYPE"] = "DHCP message type",

    -- DIAMETER
    ["DIAMETER_REQ_MSG_TYPE"] = "DIAMETER Request Msg Type",
    ["DIAMETER_RSP_MSG_TYPE"] = "DIAMETER Response Msg Type",
    ["DIAMETER_REQ_ORIGIN_HOST"] = "DIAMETER Origin Host Request",
    ["DIAMETER_RSP_ORIGIN_HOST"] = "DIAMETER Origin Host Response",
    ["DIAMETER_REQ_USER_NAME"] = "DIAMETER Request User Name",
    ["DIAMETER_RSP_RESULT_CODE"] = "DIAMETER Response Result Code",
    ["DIAMETER_EXP_RES_VENDOR_ID"] = "DIAMETER Response Experimental Result Vendor Id",
    ["DIAMETER_EXP_RES_RESULT_CODE"] = "DIAMETER Response Experimental Result Code",

    -- DNS
    ["DNS_QUERY"] = "DNS query",
    ["DNS_QUERY_ID"] = "DNS query transaction Id",
    ["DNS_QUERY_TYPE"] = "DNS query type (e.g. 1=A, 2=NS..)",
    ["DNS_RET_CODE"] = "DNS return code (e.g. 0=no error)",
    ["DNS_NUM_ANSWERS"] = "DNS # of returned answers",
    ["DNS_TTL_ANSWER"] = "TTL of the first A record (if any)",
    ["DNS_RESPONSE"] = "DNS response(s)",

    -- FTP
    ["FTP_LOGIN"] = "FTP client login",
    ["FTP_PASSWORD"] = "FTP client password",
    ["FTP_COMMAND"] = "FTP client command",
    ["FTP_COMMAND_RET_CODE"] = "FTP client command return code",

    -- GTP
    ["GTPV0_REQ_MSG_TYPE"] = "GTPv0 Request Msg Type",
    ["GTPV0_RSP_MSG_TYPE"] = "GTPv0 Response Msg Type",
    ["GTPV0_TID"] = "GTPv0 Tunnel Identifier",
    ["GTPV0_APN_NAME"] = "GTPv0 APN Name",
    ["GTPV0_END_USER_IP"] = "GTPv0 End User IP Address",
    ["GTPV0_END_USER_MSISDN"] = "GTPv0 End User MSISDN",
    ["GTPV0_RAI_MCC"] = "GTPv0 Mobile Country Code",
    ["GTPV0_RAI_MNC"] = "GTPv0 Mobile Network Code",
    ["GTPV0_RAI_CELL_LAC"] = "GTPv0 Cell Location Area Code",
    ["GTPV0_RAI_CELL_RAC"] = "GTPv0 Cell Routing Area Code",
    ["GTPV0_RESPONSE_CAUSE"] = "GTPv0 Cause of Operation",
    ["GTPV1_REQ_MSG_TYPE"] = "GTPv1 Request Msg Type",
    ["GTPV1_RSP_MSG_TYPE"] = "GTPv1 Response Msg Type",
    ["GTPV1_C2S_TEID_DATA"] = "GTPv1 Client->Server TunnelId Data",
    ["GTPV1_C2S_TEID_CTRL"] = "GTPv1 Client->Server TunnelId Control",
    ["GTPV1_S2C_TEID_DATA"] = "GTPv1 Server->Client TunnelId Data",
    ["GTPV1_S2C_TEID_CTRL"] = "GTPv1 Server->Client TunnelId Control",
    ["GTPV1_END_USER_IP"] = "GTPv1 End User IP Address",
    ["GTPV1_END_USER_IMSI"] = "GTPv1 End User IMSI",
    ["GTPV1_END_USER_MSISDN"] = "GTPv1 End User MSISDN",
    ["GTPV1_END_USER_IMEI"] = "GTPv1 End User IMEI",
    ["GTPV1_APN_NAME"] = "GTPv1 APN Name",
    ["GTPV1_RAI_MCC"] = "GTPv1 RAI Mobile Country Code",
    ["GTPV1_RAI_MNC"] = "GTPv1 RAI Mobile Network Code",
    ["GTPV1_RAI_LAC"] = "GTPv1 RAI Location Area Code",
    ["GTPV1_RAI_RAC"] = "GTPv1 RAI Routing Area Code",
    ["GTPV1_ULI_MCC"] = "GTPv1 ULI Mobile Country Code",
    ["GTPV1_ULI_MNC"] = "GTPv1 ULI Mobile Network Code",
    ["GTPV1_ULI_CELL_LAC"] = "GTPv1 ULI Cell Location Area Code",
    ["GTPV1_ULI_CELL_CI"] = "GTPv1 ULI Cell CI",
    ["GTPV1_ULI_SAC"] = "GTPv1 ULI SAC",
    ["GTPV1_RESPONSE_CAUSE"] = "GTPv1 Cause of Operation",
    ["GTPV2_REQ_MSG_TYPE"] = "GTPv2 Request Msg Type",
    ["GTPV2_RSP_MSG_TYPE"] = "GTPv2 Response Msg Type",
    ["GTPV2_C2S_S1U_GTPU_TEID"] = "GTPv2 Client->Svr S1U GTPU TEID",
    ["GTPV2_C2S_S1U_GTPU_IP"] = "GTPv2 Client->Svr S1U GTPU IP",
    ["GTPV2_S2C_S1U_GTPU_TEID"] = "GTPv2 Srv->Client S1U GTPU TEID",
    ["GTPV2_S2C_S1U_GTPU_IP"] = "GTPv2 Srv->Client S1U GTPU IP",
    ["GTPV2_END_USER_IMSI"] = "GTPv2 End User IMSI",
    ["GTPV2_END_USER_MSISDN"] = "GTPv2 End User MSISDN",
    ["GTPV2_APN_NAME"] = "GTPv2 APN Name",
    ["GTPV2_ULI_MCC"] = "GTPv2 Mobile Country Code",
    ["GTPV2_ULI_MNC"] = "GTPv2 Mobile Network Code",
    ["GTPV2_ULI_CELL_TAC"] = "GTPv2 Tracking Area Code",
    ["GTPV2_ULI_CELL_ID"] = "GTPv2 Cell Identifier",
    ["GTPV2_RESPONSE_CAUSE"] = "GTPv2 Cause of Operation",

    -- HTTP
    ["HTTP_URL"] = "HTTP URL",
    ["HTTP_METHOD"] = "HTTP METHOD",
    ["HTTP_RET_CODE"] = "HTTP return code (e.g. 200,  304...)",
    ["HTTP_REFERER"] = "HTTP Referer",
    ["HTTP_UA"] = "HTTP User Agent",
    ["HTTP_MIME"] = "HTTP Mime Type",
    ["HTTP_HOST"] = "HTTP Host Name",
    ["HTTP_FBOOK_CHAT"] = "HTTP Facebook Chat",
    ["HTTP_SITE"] = "HTTP server without host name",

    -- Oracle
    ["ORACLE_USERNAME"] = "Oracle Username",
    ["ORACLE_QUERY"] = "Oracle Query",
    ["ORACLE_RSP_CODE"] = "Oracle Response Code",
    ["ORACLE_RSP_STRING"] = "Oracle Response String",
    ["ORACLE_QUERY_DURATION"] = "Oracle Query Duration (msec)",

    -- Process
    ['SRC_PROC_PID'] = "Client Process PID",
    ['SRC_PROC_NAME'] = "Client Process Name",
    ['SRC_PROC_UID'] = "Client process UID",
    ['SRC_PROC_USER_NAME'] = "Client process User Name",
    ['SRC_FATHER_PROC_PID'] = "Client Father Process PID",
    ['SRC_FATHER_PROC_NAME'] = "Client Father Process Name",
    ['SRC_PROC_ACTUAL_MEMORY'] = "Client Process Used Memory (KB)",
    ['SRC_PROC_PEAK_MEMORY'] = "Client Process Peak Memory (KB)",
    ['SRC_PROC_AVERAGE_CPU_LOAD'] = "Client Process Average Process CPU Load (%)",
    ['SRC_PROC_NUM_PAGE_FAULTS'] = "Client Process Number of page faults",
    ['SRC_PROC_PCTG_IOWAIT'] = "Client process iowait time % (% * 100)",
    ['DST_PROC_PID'] = "Server Process PID",
    ['DST_PROC_UID'] = "Server process UID",
    ['DST_PROC_NAME'] = "Server Process Name",
    ['DST_PROC_USER_NAME'] = "Server process User Name",
    ['DST_FATHER_PROC_PID'] = "Server Father Process PID",
    ['DST_FATHER_PROC_NAME'] = "Server Father Process Name",
    ['DST_PROC_ACTUAL_MEMORY'] = "Server Process Used Memory (KB)",
    ['DST_PROC_PEAK_MEMORY'] = "Server Process Peak Memory (KB)",
    ['DST_PROC_AVERAGE_CPU_LOAD'] = "Server Process Average Process CPU Load (%)",
    ['DST_PROC_NUM_PAGE_FAULTS'] = "Server Process Number of page faults",
    ['DST_PROC_PCTG_IOWAIT'] = "Server process iowait time % (% * 100)",

    -- Radius
    ["RADIUS_REQ_MSG_TYPE"] = "RADIUS Request Msg Type",
    ["RADIUS_RSP_MSG_TYPE"] = "RADIUS Response Msg Type",
    ["RADIUS_USER_NAME"] = "RADIUS User Name (Access Only)",
    ["RADIUS_CALLING_STATION_ID"] = "RADIUS Calling Station Id",
    ["RADIUS_CALLED_STATION_ID"] = "RADIUS Called Station Id",
    ["RADIUS_NAS_IP_ADDR"] = "RADIUS NAS IP Address",
    ["RADIUS_NAS_IDENTIFIER"] = "RADIUS NAS Identifier",
    ["RADIUS_USER_IMSI"] = "RADIUS User IMSI (Extension)",
    ["RADIUS_USER_IMEI"] = "RADIUS User MSISDN (Extension)",
    ["RADIUS_FRAMED_IP_ADDR"] = "RADIUS Framed IP",
    ["RADIUS_ACCT_SESSION_ID"] = "RADIUS Accounting Session Name",
    ["RADIUS_ACCT_STATUS_TYPE"] = "RADIUS Accounting Status Type",
    ["RADIUS_ACCT_IN_OCTETS"] = "RADIUS Accounting Input Octets",
    ["RADIUS_ACCT_OUT_OCTETS"] = "RADIUS Accounting Output Octets",
    ["RADIUS_ACCT_IN_PKTS"] = "RADIUS Accounting Input Packets",
    ["RADIUS_ACCT_OUT_PKTS"] = "RADIUS Accounting Output Packets",

    -- VoIP
    ['RTP_SSRC'] =  "RTP Sync Source ID",
    ['RTP_MOS'] = "Rtp Voice Quality",
    ['RTP_R_FACTOR'] = "Rtp Voice Quality Metric (%)", --http://tools.ietf.org/html/rfc3611#section-4.7.5
    ['RTP_RTT'] =  "Rtp Round Trip Time",
    ['RTP_IN_TRANSIT'] = "RTP Transit (value * 100) (src->dst)",
    ['RTP_OUT_TRANSIT'] = "RTP Transit (value * 100) (dst->src)",
    ['RTP_FIRST_SEQ'] = "First flow RTP Seq Number",
    ['RTP_FIRST_TS'] = "First flow RTP timestamp",
    ['RTP_LAST_SEQ'] = "Last flow RTP Seq Number",
    ['RTP_LAST_TS'] = "Last flow RTP timestamp",
    ['RTP_IN_JITTER'] = "Rtp Incoming Packet Delay Variation",
    ['RTP_OUT_JITTER'] = "Rtp Out Coming Packet Delay Variation",
    ['RTP_IN_PKT_LOST'] = "Rtp Incoming Packets Lost",
    ['RTP_OUT_PKT_LOST'] = "Rtp Out Coming Packets Lost",
    ['RTP_OUT_PAYLOAD_TYPE'] = "Rtp Out Coming Payload Type",
    ['RTP_IN_MAX_DELTA'] = "Max delta (ms*100) between consecutive pkts (src->dst)",
    ['RTP_OUT_MAX_DELTA'] = "Max delta (ms*100) between consecutive pkts (dst->src)",
    ['RTP_IN_PAYLOAD_TYPE'] = "Rtp Incoming Payload Type",
    ['RTP_SIP_CALL_ID'] = "SIP call-id corresponding to this RTP stream",
    ['RTP_IN_PKT_DROP'] = "Packet discarded by Jitter Buffer (src->dst)",
    ['RTP_OUT_PKT_DROP'] = "Packet discarded by Jitter Buffer (dst->src)",
    ['RTP_IN_MOS'] = "RTP pseudo-MOS (value * 100) (src->dst)",
    ['RTP_OUT_MOS'] = "RTP pseudo-MOS (value * 100) (dst->src)",
    ['RTP_IN_R_FACTOR'] = "RTP pseudo-R_FACTOR (value * 100) (src->dst)",
    ['RTP_OUT_R_FACTOR'] = "RTP pseudo-R_FACTOR (value * 100) (dst->src)",
    ['RTP_DTMF_TONES'] = "DTMF tones sent (if any) during the call",
    ['SIP_CALL_ID'] = "SIP call-id",
    ['SIP_CALLING_PARTY'] = "SIP Call initiator",
    ['SIP_CALLED_PARTY'] = "SIP Called party",
    ['SIP_RTP_CODECS'] = "SIP RTP codecs",
    ['SIP_INVITE_TIME'] = "SIP time (epoch) of INVITE",
    ['SIP_TRYING_TIME'] = "SIP time (epoch) of Trying",
    ['SIP_RINGING_TIME'] = "SIP time (epoch) of RINGING",
    ['SIP_INVITE_OK_TIME'] = "SIP time (epoch) of INVITE OK",
    ['SIP_INVITE_FAILURE_TIME'] = "SIP time (epoch) of INVITE FAILURE",
    ['SIP_BYE_TIME'] = "SIP time (epoch) of BYE",
    ['SIP_BYE_OK_TIME'] = "SIP time (epoch) of BYE OK",
    ['SIP_CANCEL_TIME'] = "SIP time (epoch) of CANCEL",
    ['SIP_CANCEL_OK_TIME'] = "SIP time (epoch) of CANCEL OK",
    ['SIP_RTP_IPV4_SRC_ADDR'] = "SIP RTP stream source IP",
    ['SIP_RTP_L4_SRC_PORT'] = "SIP RTP stream source port",
    ['SIP_RTP_IPV4_DST_ADDR'] = "SIP RTP stream dest IP",
    ['SIP_RTP_L4_DST_PORT'] = "SIP RTP stream dest port",
    ['SIP_RESPONSE_CODE'] = "SIP failure response code",
    ['SIP_REASON_CAUSE'] = "SIP Cancel/Bye/Failure reason cause",
    ['SIP_C_IP'] = "SIP C IP adresses",
    ['SIP_CALL_STATE'] = "Sip Call State",

    -- S1AP
    ["S1AP_ENB_UE_S1AP_ID"] = "S1AP ENB Identifier",
    ["S1AP_MME_UE_S1AP_ID"] = "S1AP MME Identifier",
    ["S1AP_MSG_EMM_TYPE_MME_TO_ENB"] = "S1AP EMM Message Type from MME to ENB",
    ["S1AP_MSG_ESM_TYPE_MME_TO_ENB"] = "S1AP ESM Message Type from MME to ENB",
    ["S1AP_MSG_EMM_TYPE_ENB_TO_MME"] = "S1AP EMM Message Type from ENB to MME",
    ["S1AP_MSG_ESM_TYPE_ENB_TO_MME"] = "S1AP ESM Message Type from ENB to MME",
    ["S1AP_CAUSE_ENB_TO_MME"] = "S1AP Cause from ENB to MME",
    ["S1AP_DETAILED_CAUSE_ENB_TO_MME"] = "S1AP Detailed Cause from ENB to MME",

    -- Mail
    ["SMTP_MAIL_FROM"] = "Mail sender",
    ["SMTP_RCPT_TO"] = "Mail recipient",
    ["POP_USER"] = "POP3 user login",
    ["IMAP_LOGIN"] = "Mail sender",

    -- WHOIS
    ["WHOIS_DAS_DOMAIN"] = "Whois/DAS Domain name",
 }

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

function getFlowKey(name)
   v = rtemplate[tonumber(name)]
   if(v == nil) then return(name) end

   s = flow_fields_description[v]

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
   if(field == nil or protocol == nil) then
     return 0
   end
   v = rtemplate[tonumber(field)]
   if(v == nil) then return 0 end
   return string.starts(v, protocol.."_")
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
   local return_value = ""
   local value_original = "0"
   for key,value in pairs(info) do
     if(rtemplate[tonumber(key)] == field)then
       return_value = handleCustomFlowField(key, value)
       value_original = value
     end
   end
   return_value = string.gsub(return_value, "<", "&lt;")
   return_value = string.gsub(return_value, ">", "&gt;")
   return_value = string.gsub(return_value, "\"", "\\\"")

   return return_value , value_original
end

-- #######################

function isThereProtocol(protocol, info)
  found = 0
  for key,value in pairs(info) do
    if(isFieldProtocol(protocol, key)) then
      found = 1
    end
  end
  return found
end

-- #######################

function isThereSIPCall(info)
  local retVal = 0
  local call_state = getFlowValue(info, "SIP_CALL_STATE")
  if((call_state ~= nil) and
     ( (call_state == "CALL_STARTED")
       or (call_state == "CALL_IN_PROGRESS")
       or (call_state == "CALL_COMPLETED")
       or (call_state == "CALL_ERROR")
       or (call_state == "CALL_CANCELED") ) ) then
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
        returnString =  calling_party .. " <-> " .. called_party
      end
    end
  end
  return returnString
end

-- #######################

function getSIPTableRows(info)
   local string_table = ""
   local call_id = ""
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
     string_table = string_table.."<tr><th colspan=3 class=\"info\" >SIP Protocol Information</th></tr>\n"
     call_id = getFlowValue(info, "SIP_CALL_ID")
     if((call_id == nil) or (call_id == "")) then
       string_table = string_table.."<tr id=\"call_id_tr\" style=\"display: none;\"><th width=30%> Call-ID </th><td colspan=2><div id=call_id></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"call_id_tr\" style=\"display: table-row;\"><th width=30%> Call-ID </th><td colspan=2><div id=call_id>" .. call_id .. "</div></td></tr>\n"
     end

     called_party = getFlowValue(info, "SIP_CALLED_PARTY")
     calling_party = getFlowValue(info, "SIP_CALLING_PARTY")
     called_party = string.gsub(called_party, "\\\"","\"")
     calling_party = string.gsub(calling_party, "\\\"","\"")
     called_party = extractSIPCaller(called_party)
     calling_party = extractSIPCaller(calling_party)
     if(((called_party == nil) or (called_party == "")) and ((calling_party == nil) or (calling_party == ""))) then
       string_table = string_table.."<tr id=\"called_calling_tr\" style=\"display: none;\"><th>Call Initiator <i class=\"fa fa-exchange fa-lg\"></i> Called Party</th><td colspan=2><div id=calling_called_party></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"called_calling_tr\" style=\"display: table-row;\"><th>Call Initiator <i class=\"fa fa-exchange fa-lg\"></i> Called Party</th><td colspan=2><div id=calling_called_party>" .. calling_party .. " <i class=\"fa fa-exchange fa-lg\"></i> " .. called_party .. "</div></td></tr>\n"
     end

     rtp_codecs = getFlowValue(info, "SIP_RTP_CODECS")
     if((rtp_codecs == nil) or (rtp_codecs == "")) then
       string_table = string_table.."<tr id=\"rtp_codecs_tr\" style=\"display: none;\"><th width=30%>RTP Codecs</th><td colspan=2> <div id=rtp_codecs></></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"rtp_codecs_tr\" style=\"display: table-row;\"><th width=30%>RTP Codecs</th><td colspan=2> <div id=rtp_codecs>" .. rtp_codecs .. "</></td></tr>\n"
     end


     time_invite, time_epoch_invite = getFlowValue(info, "SIP_INVITE_TIME")
     time_trying, time_epoch_trying = getFlowValue(info, "SIP_TRYING_TIME")
     time_ringing, time_epoch_ringing = getFlowValue(info, "SIP_RINGING_TIME")
     time_invite_ok, time_epoch_invite_ok = getFlowValue(info, "SIP_INVITE_OK_TIME")
     time_invite_failure, time_epoch_invite_failure = getFlowValue(info, "SIP_INVITE_FAILURE_TIME")
     time_bye, time_epoch_bye = getFlowValue(info, "SIP_BYE_TIME")
     time_bye_ok, time_epoch_bye_ok = getFlowValue(info, "SIP_BYE_OK_TIME")
     time_cancel, time_epoch_cancel = getFlowValue(info, "SIP_CANCEL_TIME")
     time_cancel_ok, time_epoch_cancel_ok = getFlowValue(info, "SIP_CANCEL_OK_TIME")

     -- get delta invite
     local delta_invite = ""
     if(time_epoch_invite ~= "0") then
       if(time_epoch_trying ~= "0") then
         if((tonumber(time_epoch_trying) - tonumber(time_epoch_invite)) >= 0 ) then
           delta_invite = tonumber(time_epoch_trying) - tonumber(time_epoch_invite)
           if (delta_invite == 0) then
             delta_invite = "< 1"
           end
           print_second = 1
         end
       else
         delta_invite = secondsToTime(os.time()-tonumber(time_epoch_invite))
         print_second = 0
       end
     end

     if((time_epoch_invite ~= "0") and (delta_invite ~= "")) then
       string_table = string_table.."<tr id=\"invite_time_tr\" style=\"display: table-row;\"><th width=30%>Time of Invite</th><td colspan=2> <div id=time_invite>" .. delta_invite
       if (print_second == 1) then string_table = string_table.." sec" end
       string_table = string_table.."</div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"invite_time_tr\" style=\"display: none;\"><th width=30%>Time of Invite</th><td colspan=2></td><div id=time_invite></div></tr>\n"
     end

     local delta_trying = ""
     print_second = 0
     if(time_epoch_trying ~= "0") then
       if(time_epoch_ringing ~= "0") then
         if((tonumber(time_epoch_ringing) - tonumber(time_epoch_trying)) >= 0 ) then
           delta_trying = tonumber(time_epoch_ringing) - tonumber(time_epoch_trying)
           if (delta_trying == 0) then
             delta_trying = "< 1"
           end
           print_second = 1
         end
       else
         delta_trying = secondsToTime(os.time()-tonumber(time_epoch_trying))
         print_second = 0
       end
     end

     if((time_epoch_trying ~= "0") and (delta_trying ~= "")) then
       string_table = string_table.."<tr id=\"trying_time_tr\" style=\"display: table-row;\"><th width=30%>Time of Trying</th><td colspan=2><div id=time_trying>" .. delta_trying
       if (print_second == 1) then string_table = string_table.." sec" end
       string_table = string_table.."</div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"trying_time_tr\" style=\"display: none;\"><th width=30%>Time of Trying</th><td colspan=2><div id=time_trying></div></td></tr>\n"
     end

     local delta_ringing = ""
     print_second = 0
     if(time_epoch_ringing ~= "0") then
       if(time_epoch_invite_ok ~= "0") then
         if((tonumber(time_epoch_invite_ok) - tonumber(time_epoch_ringing)) >= 0 ) then
           delta_ringing = tonumber(time_epoch_invite_ok) - tonumber(time_epoch_ringing)
           if (delta_ringing == 0) then
             delta_ringing = "< 1"
           end
           print_second = 1
         end
       else
         if(time_epoch_invite_failure ~= "0") then
           if((tonumber(time_epoch_invite_failure) - tonumber(time_epoch_ringing)) >= 0 ) then
             delta_ringing = tonumber(time_epoch_invite_failure) - tonumber(time_epoch_ringing)
             if (delta_ringing == 0) then
               delta_ringing = "< 1"
             end
             print_second = 1
           end
         else
           if(time_epoch_cancel_ok ~= "0") then
             if((tonumber(time_epoch_cancel_ok) - tonumber(time_epoch_ringing)) >= 0 ) then
               delta_ringing = tonumber(time_epoch_cancel_ok) - tonumber(time_epoch_ringing)
               if (delta_ringing == 0) then
                 delta_ringing = "< 1"
               end
               print_second = 1
             end
           else
             delta_ringing = secondsToTime(os.time()-tonumber(time_epoch_ringing))
             print_second = 0
           end
         end
       end
     end

     if((time_epoch_ringing ~= "0") and (delta_ringing ~= "")) then
       string_table = string_table.."<tr id=\"ringing_time_tr\" style=\"display: table-row;\"><th width=30%>Time of Ringing</th><td colspan=2><div id=time_ringing>" .. delta_ringing
       if (print_second == 1) then string_table = string_table.." sec" end
       string_table = string_table.."</div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"ringing_time_tr\" style=\"display: none;\"><th width=30%>Time of Ringing</th><td colspan=2><div id=time_ringing></div></td></tr>\n"
     end

     local delta_invite_ok = ""
     print_second = 0
     if(time_epoch_invite_ok ~= "0") then
       if(time_epoch_bye ~= "0") then
         if((tonumber(time_epoch_bye) - tonumber(time_epoch_invite_ok)) >= 0 ) then
           delta_invite_ok = tonumber(time_epoch_bye) - tonumber(time_epoch_invite_ok)
           if (delta_invite_ok == 0) then
             delta_invite_ok = "< 1"
           end
           print_second = 1
         end
       else
         delta_invite_ok = secondsToTime(os.time()-tonumber(time_epoch_invite_ok))
         print_second = 0
       end
     end

     local delta_invite_failure = ""
     print_second_2 = 0
     if(time_epoch_invite_failure ~= "0") then
       if(time_epoch_bye ~= "0") then
         if((tonumber(time_epoch_bye) - tonumber(time_epoch_invite_failure)) >= 0 ) then
           delta_invite_failure = tonumber(time_epoch_bye) - tonumber(time_epoch_invite_failure)
           if (delta_invite_failure == 0) then
             delta_invite_failure = "< 1"
           end
           print_second_2 = 1
         end
       else
         delta_invite_ok = secondsToTime(os.time()-tonumber(time_epoch_invite_failure))
         print_second_2 = 0
       end
     end

     if(((time_epoch_invite_ok ~= "0") or (time_epoch_invite_failure ~= "0")) and ((delta_invite_ok ~= "") or (delta_invite_failure ~= ""))) then
       string_table = string_table .. "<tr id=\"invite_ok_tr\" style=\"display: table-row;\"><th width=30%>Time of Invite Ok / Invite Failure</th><td><div id=time_invite_ok>"
     else
       string_table = string_table .. "<tr id=\"invite_ok_tr\" style=\"display: none;\"><th width=30%>Time of Invite Ok / Invite Failure</th><td><div id=time_invite_ok>"
     end
     if((time_epoch_invite_ok ~= "0") and (delta_invite_ok ~= "")) then
        string_table = string_table .. delta_invite_ok
        if (print_second == 1) then string_table = string_table.." sec" end
     end
     string_table = string_table .. "</div></td><td><div id=time_invite_failure>\n"
     if((time_epoch_invite_failure ~= "0") and (delta_invite_failure ~= "")) then
        string_table = string_table ..  delta_invite_failure
        if (print_second_2 == 1) then string_table = string_table.." sec" end
     end
     string_table = string_table .. "</div></td></tr>\n"

     local delta_bye = ""
     print_second = 0
     if(time_epoch_bye ~= "0") then
       if(time_epoch_bye_ok ~= "0") then
         if((tonumber(time_epoch_bye_ok) - tonumber(time_epoch_bye)) >= 0 ) then
           delta_bye = tonumber(time_epoch_bye_ok) - tonumber(time_epoch_bye)
           if (delta_bye == 0) then
             delta_bye = "< 1"
           end
           print_second = 1
         end
       else
         delta_bye = secondsToTime(os.time()-tonumber(time_epoch_bye_ok))
         print_second = 0
       end
     end

     local delta_bye_ok = ""
     if(time_epoch_bye_ok ~= "0") then
         delta_bye_ok = secondsToTime(os.time()-tonumber(time_epoch_bye_ok))
     end

     if((time_epoch_bye ~= "0") or (time_epoch_bye_ok ~= "0")) then
       string_table = string_table .. "<tr id=\"time_bye_tr\" style=\"display: table-row;\"><th width=30%>Time of Bye / Bye Ok</th><td><div id=time_bye>"
     else
       string_table = string_table .. "<tr id=\"time_bye_tr\" style=\"display: none;\"><th width=30%>Time of Bye / Bye Ok</th><td><div id=time_bye>"
     end

     if(time_epoch_bye ~= "0") then
        string_table = string_table .. delta_bye
        if (print_second == 1) then string_table = string_table.." sec" end
     end
     string_table = string_table .. "</div></td><td><div id=time_bye_ok>\n"
     if(time_epoch_bye_ok ~= "0") then
        string_table = string_table .. delta_bye_ok
     end
     string_table = string_table .. "</div></td></tr>\n"

     local delta_cancel = ""
     print_second = 0
     if(time_epoch_cancel ~= "0") then
       if(time_epoch_cancel_ok ~= "0") then
         if((tonumber(time_epoch_cancel_ok) - tonumber(time_epoch_cancel)) >= 0 ) then
           delta_cancel = tonumber(time_epoch_cancel_ok) - tonumber(time_epoch_cancel)
           if (delta_cancel == 0) then
             delta_cancel = "< 1"
           end
           print_second = 1
         end
       else
         delta_cancel = secondsToTime(os.time()-tonumber(time_epoch_cancel_ok))
         print_second = 0
       end
     end

     local delta_cancel_ok = ""
     if(time_epoch_cancel_ok ~= "0") then
         delta_cancel_ok = secondsToTime(os.time()-tonumber(time_epoch_cancel_ok))
     end

     if((time_epoch_cancel ~= "0") or (time_epoch_cancel_ok ~= "0")) then
       string_table = string_table .. "<tr id=\"time_failure_tr\" style=\"display: table-row;\"><th width=30%>Time of Cancel / Cancel Ok</th><td><div id=time_cancel>"
     else
       string_table = string_table .. "<tr id=\"time_failure_tr\" style=\"display: none;\"><th width=30%>Time of Cancel / Cancel Ok</th><td><div id=time_cancel>"
     end

     if(time_epoch_cancel ~= "0") then
        string_table = string_table .. delta_cancel
        if (print_second == 1) then string_table = string_table.." sec" end
     end
     string_table = string_table .. "</div></td><td><div id=time_cancel_ok>\n"
     if(time_epoch_cancel_ok ~= "0") then
        string_table = string_table ..  delta_cancel_ok
     end
     string_table = string_table .. "</div></td></tr>\n"

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
         local address_ip = string_table_1
         interface.select(ifname)
         rtp_host = interface.getHostInfo(string_table_1)
         if(rtp_host ~= nil) then
           string_table_1 = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..string_table_1.. "\">"
           string_table_1 = string_table_1..address_ip
           string_table_1 = string_table_1.."</A>"
         end
       end
       show_rtp_stream = 1
     end
     if((getFlowValue(info, "SIP_RTP_L4_SRC_PORT")~=nil) and (getFlowValue(info, "SIP_RTP_L4_SRC_PORT")~="") and (sip_rtp_src_addr == 1)) then
       --string_table = string_table ..":"..getFlowValue(info, "SIP_RTP_L4_SRC_PORT")
       string_table_2 = ":"..getFlowValue(info, "SIP_RTP_L4_SRC_PORT")
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
         local address_ip = string_table_4
         interface.select(ifname)
         rtp_host = interface.getHostInfo(string_table_4)
         if(rtp_host ~= nil) then
           string_table_4 = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..string_table_4.. "\">"
           string_table_4 = string_table_4..address_ip
           string_table_4 = string_table_4.."</A>"
         end
       end
       show_rtp_stream = 1
     end
     if((getFlowValue(info, "SIP_RTP_L4_DST_PORT")~=nil) and (getFlowValue(info, "SIP_RTP_L4_DST_PORT")~="") and (sip_rtp_dst_addr == 1)) then
       --string_table = string_table ..":"..getFlowValue(info, "SIP_RTP_L4_DST_PORT")
       string_table_5 = ":"..getFlowValue(info, "SIP_RTP_L4_DST_PORT")
       show_rtp_stream = 1
     end

     if (show_rtp_stream == 1) then
       string_table = string_table.."<tr id=\"rtp_stream_tr\" style=\"display: table-row;\"><th width=30%>RTP Stream Pears (src <i class=\"fa fa-exchange fa-lg\"></i> dst)</th><td colspan=2><div id=rtp_stream>"
     else
       string_table = string_table.."<tr id=\"rtp_stream_tr\" style=\"display: none;\"><th width=30%>RTP Stream Pears (src <i class=\"fa fa-exchange fa-lg\"></i> dst)</th><td colspan=2><div id=rtp_stream>"
     end
     string_table = string_table..string_table_1..string_table_2..string_table_3..string_table_4..string_table_5
     string_table = string_table.."</div></td></tr>\n"

     fail_resp_code_string = getFlowValue(info, "SIP_RESPONSE_CODE")
     fail_resp_code_string = map_failure_resp_code(fail_resp_code_string)
     if((fail_resp_code_string == nil) or (fail_resp_code_string == "")) then
       string_table = string_table.."<tr id=\"failure_resp_code_tr\" style=\"display: none;\"><th width=30%> Failure Response Code </th><td colspan=2><div id=response_code></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"failure_resp_code_tr\" style=\"display: table-row;\"><th width=30%> Failure Response Code </th><td colspan=2><div id=response_code>" .. fail_resp_code_string .. "</div></td></tr>\n"
     end

     val, val_original = getFlowValue(info, "SIP_REASON_CAUSE")
     if(val_original ~= "0") then
        string_table = string_table.."<tr id=\"cbf_reason_cause_tr\" style=\"display: table-row;\"><th width=30%> Cancel/Bye/Failure Reason Cause </th><td colspan=2><div id=reason_cause>"
        string_table = string_table..val
     else
        string_table = string_table.."<tr id=\"cbf_reason_cause_tr\" style=\"display: none;\"><th width=30%> Cancel/Bye/Failure Reason Cause </th><td colspan=2><div id=reason_cause>"
     end
     string_table = string_table.."</div></td></tr>\n"
     if((getFlowValue(info, "SIP_C_IP") == nil) or (getFlowValue(info, "SIP_C_IP") == "")) then
       string_table = string_table.."<tr id=\"sip_c_ip_tr\" style=\"display: none;\"><th width=30%> C IP Addresses </th><td colspan=2><div id=c_ip></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"sip_c_ip_tr\" style=\"display: table-row;\"><th width=30%> C IP Addresses </th><td colspan=2><div id=c_ip>" .. getFlowValue(info, "SIP_C_IP") .. "</div></td></tr>\n"
     end

     if((getFlowValue(info, "SIP_CALL_STATE") == nil) or (getFlowValue(info, "SIP_CALL_STATE") == "")) then
       string_table = string_table.."<tr id=\"sip_call_state_tr\" style=\"display: none;\"><th width=30%> Call State </th><td colspan=2><div id=call_state></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"sip_call_state_tr\" style=\"display: table-row;\"><th width=30%> Call State </th><td colspan=2><div id=call_state>" .. getFlowValue(info, "SIP_CALL_STATE") .. "</div></td></tr>\n"
     end
   end
   return string_table
end

-- #######################

function getRTPTableRows(info)
   local string_table = ""
   -- check if there is a RTP field
   rtp_found = isThereProtocol("RTP", info)

   if(rtp_found == 1) then
     string_table = string_table.."<tr><th colspan=3 class=\"info\" >RTP Protocol Information</th></tr>\n"
     string_table = string_table.."<tr><th width=30%> Sync Source ID </th><td colspan=2><div id=sync_source_id>" .. getFlowValue(info, "RTP_SSRC") .. "</div></td></tr>\n"
     string_table = string_table .. "<tr><th width=30%>First / Last Flow Timestamp</th><td><div id=first_flow_timestamp>"
     rtp_first_ts = getFlowValue(info, "RTP_FIRST_TS")
     if((rtp_first_ts ~= nil) and (rtp_first_ts ~= "")) then
       string_table = string_table .. "<i class='fa fa-clock-o fa-lg'></i>  "..rtp_first_ts
     end
     string_table = string_table .. "</div></td><td><div id=last_flow_timestamp>"
     rtp_last_ts = getFlowValue(info, "RTP_LAST_TS")
     if((rtp_last_ts ~= nil) and (rtp_last_ts ~= "")) then
       string_table = string_table .. "<i class='fa fa-clock-o fa-lg'></i>  "..rtp_last_ts
     end
     string_table = string_table .. "</div></td></tr>\n"
     string_table = string_table .. "<tr><th width=30%>First / Last Flow Sequence</th><td><div id=first_flow_sequence>"..getFlowValue(info, "RTP_FIRST_SEQ").."</div></td><td><div id=last_flow_sequence>"..getFlowValue(info, "RTP_LAST_SEQ").."</div></td></tr>\n"
     string_table = string_table .. "<tr><th width=30%>Jitter IN / OUT</th><td><span id=jitter_in>"
     rtp_in_jitter = getFlowValue(info, "RTP_IN_JITTER")
     if((rtp_in_jitter ~= nil) and (rtp_in_jitter ~= "")) then
       string_table = string_table .. rtp_in_jitter.." ms "
     end
     string_table = string_table .. "</span> <span id=jitter_in_trend></span></td><td><span id=jitter_out>"
     rtp_out_jitter = getFlowValue(info, "RTP_OUT_JITTER")
     if((rtp_out_jitter ~= nil) and (rtp_out_jitter ~= "")) then
       string_table = string_table .. rtp_out_jitter.." ms "
     end
     string_table = string_table .. "</span> <span id=jitter_out_trend></span></td></tr>\n"

     string_table = string_table .. "<tr><th width=30%>Packet Lost in Stream IN / OUT</th><td><span id=packet_lost_in>"
     rtp_in_pkt_lost = getFlowValue(info, "RTP_IN_PKT_LOST")
     if((rtp_in_pkt_lost ~= nil) and (rtp_in_pkt_lost ~= "")) then
       string_table = string_table .. formatPackets(rtp_in_pkt_lost)
     end
     string_table = string_table .. "</span> <span id=packet_lost_in_trend></span></td><td><span id=packet_lost_out>"
     rtp_out_pkt_lost = getFlowValue(info, "RTP_OUT_PKT_LOST")
     if((rtp_out_pkt_lost ~= nil) and (rtp_out_pkt_lost ~= "")) then
       string_table = string_table .. formatPackets(rtp_out_pkt_lost)
     end
     string_table = string_table .. " </span> <span id=packet_lost_out_trend></span></td></tr>\n"

     string_table = string_table .. "<tr><th width=30%>Packet Discarded in Jitter Buffer IN / OUT</th><td><span id=packet_drop_in>"
     rtp_in_pkt_drop = getFlowValue(info, "RTP_IN_PKT_DROP")
     if((rtp_in_pkt_drop ~= nil) and (rtp_in_pkt_drop ~= "")) then
       string_table = string_table .. formatPackets(rtp_in_pkt_drop)
     end
     string_table = string_table .. "</span> <span id=packet_drop_in_trend></span></td><td><span id=packet_drop_out>"
     rtp_out_pkt_drop = getFlowValue(info, "RTP_OUT_PKT_DROP")
     if((rtp_out_pkt_drop ~= nil) and (rtp_out_pkt_drop ~= "")) then
       string_table = string_table .. formatPackets(rtp_out_pkt_drop)
     end
     string_table = string_table .. " </span> <span id=packet_drop_out_trend></span></td></tr>\n"

     string_table = string_table .. "<tr><th width=30%>Payload Type IN / OUT</th><td><div id=payload_type_in>"..getFlowValue(info, "RTP_IN_PAYLOAD_TYPE").."</div></td><td><div id=payload_type_out>"..getFlowValue(info, "RTP_OUT_PAYLOAD_TYPE").."</div></td></tr>\n"

     string_table = string_table .. "<tr><th width=30%>Max Delta Time between Packets IN / OUT</th><td><span id=max_delta_time_in>"
     rtp_in_max_delta = getFlowValue(info, "RTP_IN_MAX_DELTA")
     if((rtp_in_max_delta ~= nil) and (rtp_in_max_delta ~= "")) then
       string_table = string_table .. rtp_in_max_delta .. " ms "
     end
     string_table = string_table .. "</span> <span id=max_delta_time_in_trend></span></td><td><span id=max_delta_time_out>"
     rtp_out_max_delta = getFlowValue(info, "RTP_OUT_MAX_DELTA")
     if((rtp_out_max_delta ~= nil) and (rtp_out_max_delta ~= "")) then
       string_table = string_table .. rtp_out_max_delta .. " ms "
     end
     string_table = string_table .. "</span> <span id=max_delta_time_out_trend></span></td></tr>\n"
     string_table = string_table .. "<tr><th width=30%> SIP Call Id  </th><td colspan=2><div id=rtp_sip_call_id>" .. getFlowValue(info, "RTP_SIP_CALL_ID") .. "</div></td></tr>\n"

     string_table = string_table .. "<tr><th width=30%>Quality of VoIP Communication (Average MOS/R-Factor) </th><td colspan=2><span id=mos_average_signal>"
     rtp_mos = getFlowValue(info, "RTP_MOS")
     rtp_r_factor = getFlowValue(info, "RTP_R_FACTOR")
     if(((rtp_mos ~= nil) and (rtp_mos ~= "")) or ((rtp_r_factor ~= nil) and (rtp_r_factor ~= ""))) then
       string_table = string_table .. "<i class='fa fa-signal'></i> "
     end
     string_table = string_table .. "</span><span id=mos_average>"
     if((rtp_mos ~= nil) and (rtp_mos ~= "")) then
       string_table = string_table .. rtp_mos
     end
     string_table = string_table .. "</span> <span id=mos_average_trend></span>"
     string_table = string_table .. "<span id=mos_average_slash>"
     if((rtp_r_factor ~= nil) and (rtp_r_factor ~= "")) then
       string_table = string_table .. " / "
     end
     string_table = string_table .. "</span>"
     string_table = string_table .. "<span id=r_factor_average>"
     if((rtp_r_factor ~= nil) and (rtp_r_factor ~= "")) then
       string_table = string_table .. rtp_r_factor
     end
     string_table = string_table .. " </span> <span id=r_factor_average_trend></span></td></tr>\n"


     string_table = string_table .. "<tr><th width=30%>Quality of VoIP Communication (MOS/R-Factor) IN / OUT </th><td><span id=mos_in_signal>"
     rtp_in_mos = getFlowValue(info, "RTP_IN_MOS")
     rtp_in_r_factor = getFlowValue(info, "RTP_IN_R_FACTOR")
     if(((rtp_in_mos ~= nil) and (rtp_in_mos ~= "")) or ((rtp_in_r_factor ~= nil) and (rtp_in_r_factor ~= ""))) then
       string_table = string_table .. "<i class='fa fa-signal'></i> "
     end
     string_table = string_table .. "</span><span id=mos_in>"
     if((rtp_in_mos ~= nil) and (rtp_in_mos ~= "")) then
       string_table = string_table .. rtp_in_mos
     end
     string_table = string_table .. "</span> <span id=mos_in_trend></span>"
     string_table = string_table .. "<span id=mos_in_slash>"
     if((rtp_in_r_factor ~= nil) and (rtp_in_r_factor ~= "")) then
       string_table = string_table .. " / "
     end
     string_table = string_table .. "</span>"
     string_table = string_table .. "<span id=r_factor_in>"
     if((rtp_in_r_factor ~= nil) and (rtp_in_r_factor ~= "")) then
       string_table = string_table .. rtp_in_r_factor
     end
     string_table = string_table .. "</span> <span id=r_factor_in_trend></span></td><td><span id=mos_out_signal>"
     rtp_out_mos = getFlowValue(info, "RTP_OUT_MOS")
     rtp_out_r_factor = getFlowValue(info, "RTP_OUT_R_FACTOR")
     if(((rtp_out_mos ~= nil) and (rtp_out_mos ~= "")) or ((rtp_out_r_factor ~= nil) and (rtp_out_r_factor ~= ""))) then
       string_table = string_table .. "<i class='fa fa-signal'></i> "
     end
     string_table = string_table .. "</span><span id=mos_out>"
     if((rtp_out_mos ~= nil) and (rtp_out_mos ~= "")) then
       string_table = string_table .. rtp_out_mos
     end
     string_table = string_table .. "</span> <span id=mos_out_trend></span>"
     string_table = string_table .. "<span id=mos_out_slash>"
     if((rtp_out_r_factor ~= nil) and (rtp_out_r_factor ~= "")) then
       string_table = string_table .. " / "
     end
     string_table = string_table .. "</span>"
     string_table = string_table .. "<span id=r_factor_out>"
     if((rtp_out_r_factor ~= nil) and (rtp_out_r_factor ~= "")) then
       string_table = string_table .. rtp_out_r_factor
     end
     string_table = string_table .. " </span> <span id=r_factor_out_trend></span></td></tr>\n"

     string_table = string_table .. "<tr><th width=30%>RTP Transit IN / OUT</th><td><div id=rtp_transit_in>"..getFlowValue(info, "RTP_IN_TRANSIT").."</div></td><td><div id=rtp_transit_out>"..getFlowValue(info, "RTP_OUT_TRANSIT").."</div></td></tr>\n"

     string_table = string_table .. "<tr><th width=30%>Round Trip Time</th><td colspan=2><span id=rtp_rtt>"
     rtp_rtt = getFlowValue(info, "RTP_RTT")
     if((rtp_rtt ~= nil) and (rtp_rtt ~= "")) then
       string_table = string_table .. rtp_rtt .. " ms "
     end
     string_table = string_table .. "</span> <span id=rtp_rtt_trend></span></td></tr>\n"
     string_table = string_table .. "<tr><th width=30%>DTMF tones sent during the call</th><td colspan=2><span id=dtmf_tones>"..getFlowValue(info, "RTP_DTMF_TONES").."</span></td></tr>\n"
   end
   return string_table
end

-- #######################
