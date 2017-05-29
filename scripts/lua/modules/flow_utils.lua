--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"
require "voip_utils"
require "graph_utils"

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")
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
      local res = getResolvedAddress(hostkey2hostinfo(ipaddr))

      local ret = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..ipaddr.."\">"

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
	  r = r .. " <A HREF='http://www.numberingplans.com/?page=analysis&sub=imsinr'><i class='fa fa-info'></i></A></td></tr>"
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

   rsp = "<A HREF=\"http://en.wikipedia.org/wiki/Transmission_Control_Protocol\">"
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
    ["IN_BYTES"] = i18n("nprobe_mapping.id_1"),
    ["IN_PKTS"] = i18n("nprobe_mapping.id_2"),
    ["PROTOCOL"] = i18n("nprobe_mapping.id_4"),
    ["PROTOCOL_MAP"] = i18n("nprobe_mapping.id_58500"),
    ["SRC_TOS"] = i18n("nprobe_mapping.id_5"),
    ["TCP_FLAGS"] = i18n("nprobe_mapping.id_6"),
    ["L4_SRC_PORT"] = i18n("nprobe_mapping.id_7"),
    ["L4_SRC_PORT_MAP"] = i18n("nprobe_mapping.id_58503"),
    ["IPV4_SRC_ADDR"] = i18n("nprobe_mapping.id_8"),
    ["IPV4_SRC_MASK"] = i18n("nprobe_mapping.id_9"),
    ["INPUT_SNMP"] = i18n("nprobe_mapping.id_10"),
    ["L4_DST_PORT"] = i18n("nprobe_mapping.id_11"),
    ["L4_DST_PORT_MAP"] = i18n("nprobe_mapping.id_58507"),
    ["L4_SRV_PORT"] = i18n("nprobe_mapping.id_58508"),
    ["L4_SRV_PORT_MAP"] = i18n("nprobe_mapping.id_58509"),
    ["IPV4_DST_ADDR"] = i18n("nprobe_mapping.id_12"),
    ["IPV4_DST_MASK"] = i18n("nprobe_mapping.id_13"),
    ["OUTPUT_SNMP"] = i18n("nprobe_mapping.id_14"),
    ["IPV4_NEXT_HOP"] = i18n("nprobe_mapping.id_15"),
    ["SRC_AS"] = i18n("nprobe_mapping.id_16"),
    ["DST_AS"] = i18n("nprobe_mapping.id_17"),
    ["LAST_SWITCHED"] = i18n("nprobe_mapping.id_21"),
    ["FIRST_SWITCHED"] = i18n("nprobe_mapping.id_22"),
    ["OUT_BYTES"] = i18n("nprobe_mapping.id_23"),
    ["OUT_PKTS"] = i18n("nprobe_mapping.id_24"),
    ["IPV6_SRC_ADDR"] = i18n("nprobe_mapping.id_27"),
    ["IPV6_DST_ADDR"] = i18n("nprobe_mapping.id_28"),
    ["IPV6_SRC_MASK"] = i18n("nprobe_mapping.id_29"),
    ["IPV6_DST_MASK"] = i18n("nprobe_mapping.id_30"),
    ["ICMP_TYPE"] = i18n("nprobe_mapping.id_32"),
    ["SAMPLING_INTERVAL"] = i18n("nprobe_mapping.id_34"),
    ["SAMPLING_ALGORITHM"] = i18n("nprobe_mapping.id_35"),
    ["FLOW_ACTIVE_TIMEOUT"] = i18n("nprobe_mapping.id_36"),
    ["FLOW_INACTIVE_TIMEOUT"] = i18n("nprobe_mapping.id_37"),
    ["ENGINE_TYPE"] = i18n("nprobe_mapping.id_38"),
    ["ENGINE_ID"] = i18n("nprobe_mapping.id_39"),
    ["TOTAL_BYTES_EXP"] = i18n("nprobe_mapping.id_40"),
    ["TOTAL_PKTS_EXP"] = i18n("nprobe_mapping.id_41"),
    ["TOTAL_FLOWS_EXP"] = i18n("nprobe_mapping.id_42"),
    ["MIN_TTL"] = i18n("nprobe_mapping.id_52"),
    ["MAX_TTL"] = i18n("nprobe_mapping.id_53"),
    ["DST_TOS"] = i18n("nprobe_mapping.id_55"),
    ["IN_SRC_MAC"] = i18n("nprobe_mapping.id_56"),
    ["SRC_VLAN"] = i18n("nprobe_mapping.id_58"),
    ["DST_VLAN"] = i18n("nprobe_mapping.id_59"),
    ["DOT1Q_SRC_VLAN"] = i18n("nprobe_mapping.id_243"),
    ["DOT1Q_DST_VLAN"] = i18n("nprobe_mapping.id_254"),
    ["IP_PROTOCOL_VERSION"] = i18n("nprobe_mapping.id_60"),
    ["DIRECTION"] = i18n("nprobe_mapping.id_61"),
    ["IPV6_NEXT_HOP"] = i18n("nprobe_mapping.id_62"),
    ["MPLS_LABEL_1"] = i18n("nprobe_mapping.id_70"),
    ["MPLS_LABEL_2"] = i18n("nprobe_mapping.id_71"),
    ["MPLS_LABEL_3"] = i18n("nprobe_mapping.id_72"),
    ["MPLS_LABEL_4"] = i18n("nprobe_mapping.id_73"),
    ["MPLS_LABEL_5"] = i18n("nprobe_mapping.id_74"),
    ["MPLS_LABEL_6"] = i18n("nprobe_mapping.id_75"),
    ["MPLS_LABEL_7"] = i18n("nprobe_mapping.id_76"),
    ["MPLS_LABEL_8"] = i18n("nprobe_mapping.id_77"),
    ["MPLS_LABEL_9"] = i18n("nprobe_mapping.id_78"),
    ["MPLS_LABEL_10"] = i18n("nprobe_mapping.id_79"),
    ["OUT_DST_MAC"] = i18n("nprobe_mapping.id_80"),
    ["APPLICATION_ID"] = i18n("nprobe_mapping.id_95"),
    ["PACKET_SECTION_OFFSET"] = i18n("nprobe_mapping.id_102"),
    ["SAMPLED_PACKET_SIZE"] = i18n("nprobe_mapping.id_103"),
    ["SAMPLED_PACKET_ID"] = i18n("nprobe_mapping.id_104"),
    ["EXPORTER_IPV4_ADDRESS"] = i18n("nprobe_mapping.id_130"),
    ["EXPORTER_IPV6_ADDRESS"] = i18n("nprobe_mapping.id_131"),
    ["FLOW_ID"] = i18n("nprobe_mapping.id_148"),
    ["FLOW_START_SEC"] = i18n("nprobe_mapping.id_150"),
    ["FLOW_END_SEC"] = i18n("nprobe_mapping.id_151"),
    ["FLOW_START_MILLISECONDS"] = i18n("nprobe_mapping.id_152"),
    ["FLOW_START_MICROSECONDS"] = i18n("nprobe_mapping.id_154"),
    ["FLOW_END_MILLISECONDS"] = i18n("nprobe_mapping.id_153"),
    ["FLOW_END_MICROSECONDS"] = i18n("nprobe_mapping.id_155"),
    ["BIFLOW_DIRECTION"] = i18n("nprobe_mapping.id_239"),
    ["INGRESS_VRFID"] = i18n("nprobe_mapping.id_234"),
    ["FLOW_DURATION_MILLISECONDS"] = i18n("nprobe_mapping.id_161"),
    ["FLOW_DURATION_MICROSECONDS"] = i18n("nprobe_mapping.id_162"),
    ["ICMP_IPV4_TYPE"] = i18n("nprobe_mapping.id_176"),
    ["ICMP_IPV4_CODE"] = i18n("nprobe_mapping.id_177"),
    ["OBSERVATION_POINT_TYPE"] = i18n("nprobe_mapping.id_277"),
    ["OBSERVATION_POINT_ID"] = i18n("nprobe_mapping.id_300"),
    ["SELECTOR_ID"] = i18n("nprobe_mapping.id_302"),
    ["IPFIX_SAMPLING_ALGORITHM"] = i18n("nprobe_mapping.id_304"),
    ["SAMPLING_SIZE"] = i18n("nprobe_mapping.id_309"),
    ["SAMPLING_POPULATION"] = i18n("nprobe_mapping.id_310"),
    ["FRAME_LENGTH"] = i18n("nprobe_mapping.id_312"),
    ["PACKETS_OBSERVED"] = i18n("nprobe_mapping.id_318"),
    ["PACKETS_SELECTED"] = i18n("nprobe_mapping.id_319"),
    ["SELECTOR_NAME"] = i18n("nprobe_mapping.id_335"),
    ["APPLICATION_NAME"] = i18n("nprobe_mapping.id_57899"),
    ["USER_NAME"] = i18n("nprobe_mapping.id_57900"),
    ["SRC_FRAGMENTS"] = i18n("nprobe_mapping.id_57552"),
    ["DST_FRAGMENTS"] = i18n("nprobe_mapping.id_57553"),
    ["CLIENT_NW_LATENCY_MS"] = i18n("nprobe_mapping.id_57595"),
    ["SERVER_NW_LATENCY_MS"] = i18n("nprobe_mapping.id_57596"),
    ["APPL_LATENCY_MS"] = i18n("nprobe_mapping.id_57597"),
    ["NPROBE_IPV4_ADDRESS"] = i18n("nprobe_mapping.id_57943"),
    ["SRC_TO_DST_MAX_THROUGHPUT"] = i18n("nprobe_mapping.id_57554"),
    ["SRC_TO_DST_MIN_THROUGHPUT"] = i18n("nprobe_mapping.id_57555"),
    ["SRC_TO_DST_AVG_THROUGHPUT"] = i18n("nprobe_mapping.id_57556"),
    ["DST_TO_SRC_MAX_THROUGHPUT"] = i18n("nprobe_mapping.id_57557"),
    ["DST_TO_SRC_MIN_THROUGHPUT"] = i18n("nprobe_mapping.id_57558"),
    ["DST_TO_SRC_AVG_THROUGHPUT"] = i18n("nprobe_mapping.id_57559"),
    ["NUM_PKTS_UP_TO_128_BYTES"] = i18n("nprobe_mapping.id_57560"),
    ["NUM_PKTS_128_TO_256_BYTES"] = i18n("nprobe_mapping.id_57561"),
    ["NUM_PKTS_256_TO_512_BYTES"] = i18n("nprobe_mapping.id_57562"),
    ["NUM_PKTS_512_TO_1024_BYTES"] = i18n("nprobe_mapping.id_57563"),
    ["NUM_PKTS_1024_TO_1514_BYTES"] = i18n("nprobe_mapping.id_57564"),
    ["NUM_PKTS_OVER_1514_BYTES"] = i18n("nprobe_mapping.id_57565"),
    ["CUMULATIVE_ICMP_TYPE"] = i18n("nprobe_mapping.id_57570"),
    ["SRC_IP_COUNTRY"] = i18n("nprobe_mapping.id_57573"),
    ["SRC_IP_CITY"] = i18n("nprobe_mapping.id_57574"),
    ["DST_IP_COUNTRY"] = i18n("nprobe_mapping.id_57575"),
    ["DST_IP_CITY"] = i18n("nprobe_mapping.id_57576"),
    ["SRC_IP_LONG"] = i18n("nprobe_mapping.id_57920"),
    ["SRC_IP_LAT"] = i18n("nprobe_mapping.id_57921"),
    ["DST_IP_LONG"] = i18n("nprobe_mapping.id_57922"),
    ["DST_IP_LAT"] = i18n("nprobe_mapping.id_57923"),
    ["FLOW_PROTO_PORT"] = i18n("nprobe_mapping.id_57577"),
    ["UPSTREAM_TUNNEL_ID"] = i18n("nprobe_mapping.id_57578"),
    ["UPSTREAM_SESSION_ID"] = i18n("nprobe_mapping.id_57918"),
    ["LONGEST_FLOW_PKT"] = i18n("nprobe_mapping.id_57579"),
    ["SHORTEST_FLOW_PKT"] = i18n("nprobe_mapping.id_57580"),
    ["RETRANSMITTED_IN_BYTES"] = i18n("nprobe_mapping.id_57599"),
    ["RETRANSMITTED_IN_PKTS"] = i18n("nprobe_mapping.id_57581"),
    ["RETRANSMITTED_OUT_BYTES"] = i18n("nprobe_mapping.id_57600"),
    ["RETRANSMITTED_OUT_PKTS"] = i18n("nprobe_mapping.id_57582"),
    ["OOORDER_IN_PKTS"] = i18n("nprobe_mapping.id_57583"),
    ["OOORDER_OUT_PKTS"] = i18n("nprobe_mapping.id_57584"),
    ["UNTUNNELED_PROTOCOL"] = i18n("nprobe_mapping.id_57585"),
    ["UNTUNNELED_IPV4_SRC_ADDR"] = i18n("nprobe_mapping.id_57586"),
    ["UNTUNNELED_L4_SRC_PORT"] = i18n("nprobe_mapping.id_57587"),
    ["UNTUNNELED_IPV4_DST_ADDR"] = i18n("nprobe_mapping.id_57588"),
    ["UNTUNNELED_L4_DST_PORT"] = i18n("nprobe_mapping.id_57589"),
    ["L7_PROTO"] = i18n("nprobe_mapping.id_57590"),
    ["L7_PROTO_NAME"] = i18n("nprobe_mapping.id_57591"),
    ["DOWNSTREAM_TUNNEL_ID"] = i18n("nprobe_mapping.id_57592"),
    ["DOWNSTREAM_SESSION_ID"] = i18n("nprobe_mapping.id_57919"),
    ["SSL_SERVER_NAME"] = i18n("nprobe_mapping.id_57660"),
    ["BITTORRENT_HASH"] = i18n("nprobe_mapping.id_57661"),
    ["FLOW_USER_NAME"] = i18n("nprobe_mapping.id_57593"),
    ["FLOW_SERVER_NAME"] = i18n("nprobe_mapping.id_57594"),
    ["PLUGIN_NAME"] = i18n("nprobe_mapping.id_57598"),
    ["UNTUNNELED_IPV6_SRC_ADDR"] = i18n("nprobe_mapping.id_57868"),
    ["UNTUNNELED_IPV6_DST_ADDR"] = i18n("nprobe_mapping.id_57869"),
    ["NUM_PKTS_TTL_EQ_1"] = i18n("nprobe_mapping.id_57819"),
    ["NUM_PKTS_TTL_2_5"] = i18n("nprobe_mapping.id_57818"),
    ["NUM_PKTS_TTL_5_32"] = i18n("nprobe_mapping.id_57806"),
    ["NUM_PKTS_TTL_32_64"] = i18n("nprobe_mapping.id_57807"),
    ["NUM_PKTS_TTL_64_96"] = i18n("nprobe_mapping.id_57808"),
    ["NUM_PKTS_TTL_96_128"] = i18n("nprobe_mapping.id_57809"),
    ["NUM_PKTS_TTL_128_160"] = i18n("nprobe_mapping.id_57810"),
    ["NUM_PKTS_TTL_160_192"] = i18n("nprobe_mapping.id_57811"),
    ["NUM_PKTS_TTL_192_224"] = i18n("nprobe_mapping.id_57812"),
    ["NUM_PKTS_TTL_224_255"] = i18n("nprobe_mapping.id_57813"),
    ["IN_SRC_OSI_SAP"] = i18n("nprobe_mapping.id_57821"),
    ["OUT_DST_OSI_SAP"] = i18n("nprobe_mapping.id_57822"),
    ["DURATION_IN"] = i18n("nprobe_mapping.id_57863"),
    ["DURATION_OUT"] = i18n("nprobe_mapping.id_57864"),
    ["TCP_WIN_MIN_IN"] = i18n("nprobe_mapping.id_57887"),
    ["TCP_WIN_MAX_IN"] = i18n("nprobe_mapping.id_57888"),
    ["TCP_WIN_MSS_IN"] = i18n("nprobe_mapping.id_57889"),
    ["TCP_WIN_SCALE_IN"] = i18n("nprobe_mapping.id_57890"),
    ["TCP_WIN_MIN_OUT"] = i18n("nprobe_mapping.id_57891"),
    ["TCP_WIN_MAX_OUT"] = i18n("nprobe_mapping.id_57892"),
    ["TCP_WIN_MSS_OUT"] = i18n("nprobe_mapping.id_57893"),
    ["TCP_WIN_SCALE_OUT"] = i18n("nprobe_mapping.id_57894"),
    ["PAYLOAD_HASH"] = i18n("nprobe_mapping.id_57910"),
    ["SRC_AS_MAP"] = i18n("nprobe_mapping.id_57915"),
    ["DST_AS_MAP"] = i18n("nprobe_mapping.id_57916"),

    -- BGP Update Listener
    ["SRC_AS_PATH_1"] = i18n("nprobe_mapping.id_57762"),
    ["SRC_AS_PATH_2"] = i18n("nprobe_mapping.id_57763"),
    ["SRC_AS_PATH_3"] = i18n("nprobe_mapping.id_57764"),
    ["SRC_AS_PATH_4"] = i18n("nprobe_mapping.id_57765"),
    ["SRC_AS_PATH_5"] = i18n("nprobe_mapping.id_57766"),
    ["SRC_AS_PATH_6"] = i18n("nprobe_mapping.id_57767"),
    ["SRC_AS_PATH_7"] = i18n("nprobe_mapping.id_57768"),
    ["SRC_AS_PATH_8"] = i18n("nprobe_mapping.id_57769"),
    ["SRC_AS_PATH_9"] = i18n("nprobe_mapping.id_57770"),
    ["SRC_AS_PATH_10"] = i18n("nprobe_mapping.id_57771"),
    ["DST_AS_PATH_1"] = i18n("nprobe_mapping.id_57772"),
    ["DST_AS_PATH_2"] = i18n("nprobe_mapping.id_57773"),
    ["DST_AS_PATH_3"] = i18n("nprobe_mapping.id_57774"),
    ["DST_AS_PATH_4"] = i18n("nprobe_mapping.id_57775"),
    ["DST_AS_PATH_5"] = i18n("nprobe_mapping.id_57776"),
    ["DST_AS_PATH_6"] = i18n("nprobe_mapping.id_57777"),
    ["DST_AS_PATH_7"] = i18n("nprobe_mapping.id_57778"),
    ["DST_AS_PATH_8"] = i18n("nprobe_mapping.id_57779"),
    ["DST_AS_PATH_9"] = i18n("nprobe_mapping.id_57780"),
    ["DST_AS_PATH_10"] = i18n("nprobe_mapping.id_57781"),

    -- DHCP Protocol
    ["DHCP_CLIENT_MAC"] = i18n("nprobe_mapping.id_57825"),
    ["DHCP_CLIENT_IP"] = i18n("nprobe_mapping.id_57826"),
    ["DHCP_CLIENT_NAME"] = i18n("nprobe_mapping.id_57827"),
    ["DHCP_REMOTE_ID"] = i18n("nprobe_mapping.id_57895"),
    ["DHCP_SUBSCRIBER_ID"] = i18n("nprobe_mapping.id_57896"),
    ["DHCP_MESSAGE_TYPE"] = i18n("nprobe_mapping.id_57901"),

    -- Diameter Protocol
    ["DIAMETER_REQ_MSG_TYPE"] = i18n("nprobe_mapping.id_57871"),
    ["DIAMETER_RSP_MSG_TYPE"] = i18n("nprobe_mapping.id_57872"),
    ["DIAMETER_REQ_ORIGIN_HOST"] = i18n("nprobe_mapping.id_57873"),
    ["DIAMETER_RSP_ORIGIN_HOST"] = i18n("nprobe_mapping.id_57874"),
    ["DIAMETER_REQ_USER_NAME"] = i18n("nprobe_mapping.id_57875"),
    ["DIAMETER_RSP_RESULT_CODE"] = i18n("nprobe_mapping.id_57876"),
    ["DIAMETER_EXP_RES_VENDOR_ID"] = i18n("nprobe_mapping.id_57877"),
    ["DIAMETER_EXP_RES_RESULT_CODE"] = i18n("nprobe_mapping.id_57878"),
    ["DIAMETER_HOP_BY_HOP_ID"] = i18n("nprobe_mapping.id_57917"),
    ["DIAMETER_CLR_CANCEL_TYPE"] = i18n("nprobe_mapping.id_57924"),
    ["DIAMETER_CLR_FLAGS"] = i18n("nprobe_mapping.id_57925"),

    -- DNS/LLMNR Protocol
    ["DNS_QUERY"] = i18n("nprobe_mapping.id_57677"),
    ["DNS_QUERY_ID"] = i18n("nprobe_mapping.id_57678"),
    ["DNS_QUERY_TYPE"] = i18n("nprobe_mapping.id_57679"),
    ["DNS_RET_CODE"] = i18n("nprobe_mapping.id_57680"),
    ["DNS_NUM_ANSWERS"] = i18n("nprobe_mapping.id_57681"),
    ["DNS_TTL_ANSWER"] = i18n("nprobe_mapping.id_57824"),
    ["DNS_RESPONSE"] = i18n("nprobe_mapping.id_57870"),

    -- FTP Protocol
    ["FTP_LOGIN"] = i18n("nprobe_mapping.id_57828"),
    ["FTP_PASSWORD"] = i18n("nprobe_mapping.id_57829"),
    ["FTP_COMMAND"] = i18n("nprobe_mapping.id_57830"),
    ["FTP_COMMAND_RET_CODE"] = i18n("nprobe_mapping.id_57831"),

    -- GTPv0 Signaling Protocol
    ["GTPV0_REQ_MSG_TYPE"] = i18n("nprobe_mapping.id_57793"),
    ["GTPV0_RSP_MSG_TYPE"] = i18n("nprobe_mapping.id_57794"),
    ["GTPV0_TID"] = i18n("nprobe_mapping.id_57795"),
    ["GTPV0_APN_NAME"] = i18n("nprobe_mapping.id_57798"),
    ["GTPV0_END_USER_IP"] = i18n("nprobe_mapping.id_57796"),
    ["GTPV0_END_USER_MSISDN"] = i18n("nprobe_mapping.id_57797"),
    ["GTPV0_RAI_MCC"] = i18n("nprobe_mapping.id_57799"),
    ["GTPV0_RAI_MNC"] = i18n("nprobe_mapping.id_57800"),
    ["GTPV0_RAI_CELL_LAC"] = i18n("nprobe_mapping.id_57801"),
    ["GTPV0_RAI_CELL_RAC"] = i18n("nprobe_mapping.id_57802"),
    ["GTPV0_RESPONSE_CAUSE"] = i18n("nprobe_mapping.id_57803"),

    -- GTPv1 Signaling Protocol
    ["GTPV1_REQ_MSG_TYPE"] = i18n("nprobe_mapping.id_57692"),
    ["GTPV1_RSP_MSG_TYPE"] = i18n("nprobe_mapping.id_57693"),
    ["GTPV1_C2S_TEID_DATA"] = i18n("nprobe_mapping.id_57694"),
    ["GTPV1_C2S_TEID_CTRL"] = i18n("nprobe_mapping.id_57695"),
    ["GTPV1_S2C_TEID_DATA"] = i18n("nprobe_mapping.id_57696"),
    ["GTPV1_S2C_TEID_CTRL"] = i18n("nprobe_mapping.id_57697"),
    ["GTPV1_END_USER_IP"] = i18n("nprobe_mapping.id_57698"),
    ["GTPV1_END_USER_IMSI"] = i18n("nprobe_mapping.id_57699"),
    ["GTPV1_END_USER_MSISDN"] = i18n("nprobe_mapping.id_57700"),
    ["GTPV1_END_USER_IMEI"] = i18n("nprobe_mapping.id_57701"),
    ["GTPV1_APN_NAME"] = i18n("nprobe_mapping.id_57702"),
    ["GTPV1_RAT_TYPE"] = i18n("nprobe_mapping.id_57708"),
    ["GTPV1_RAI_MCC"] = i18n("nprobe_mapping.id_57703"),
    ["GTPV1_RAI_MNC"] = i18n("nprobe_mapping.id_57704"),
    ["GTPV1_RAI_LAC"] = i18n("nprobe_mapping.id_57814"),
    ["GTPV1_RAI_RAC"] = i18n("nprobe_mapping.id_57815"),
    ["GTPV1_ULI_MCC"] = i18n("nprobe_mapping.id_57816"),
    ["GTPV1_ULI_MNC"] = i18n("nprobe_mapping.id_57817"),
    ["GTPV1_ULI_CELL_LAC"] = i18n("nprobe_mapping.id_57705"),
    ["GTPV1_ULI_CELL_CI"] = i18n("nprobe_mapping.id_57706"),
    ["GTPV1_ULI_SAC"] = i18n("nprobe_mapping.id_57707"),
    ["GTPV1_RESPONSE_CAUSE"] = i18n("nprobe_mapping.id_57804"),

    -- GTPv2 Signaling Protocol
    ["GTPV2_REQ_MSG_TYPE"] = i18n("nprobe_mapping.id_57742"),
    ["GTPV2_RSP_MSG_TYPE"] = i18n("nprobe_mapping.id_57743"),
    ["GTPV2_C2S_S1U_GTPU_TEID"] = i18n("nprobe_mapping.id_57744"),
    ["GTPV2_C2S_S1U_GTPU_IP"] = i18n("nprobe_mapping.id_57745"),
    ["GTPV2_S2C_S1U_GTPU_TEID"] = i18n("nprobe_mapping.id_57746"),
    ["GTPV2_S5_S8_GTPC_TEID"] = i18n("nprobe_mapping.id_57907"),
    ["GTPV2_S2C_S1U_GTPU_IP"] = i18n("nprobe_mapping.id_57747"),
    ["GTPV2_C2S_S5_S8_GTPU_TEID"] = i18n("nprobe_mapping.id_57911"),
    ["GTPV2_S2C_S5_S8_GTPU_TEID"] = i18n("nprobe_mapping.id_57912"),
    ["GTPV2_C2S_S5_S8_GTPU_IP"] = i18n("nprobe_mapping.id_57913"),
    ["GTPV2_S2C_S5_S8_GTPU_IP"] = i18n("nprobe_mapping.id_57914"),
    ["GTPV2_END_USER_IMSI"] = i18n("nprobe_mapping.id_57748"),
    ["GTPV2_END_USER_MSISDN"] = i18n("nprobe_mapping.id_57749"),
    ["GTPV2_APN_NAME"] = i18n("nprobe_mapping.id_57750"),
    ["GTPV2_ULI_MCC"] = i18n("nprobe_mapping.id_57751"),
    ["GTPV2_ULI_MNC"] = i18n("nprobe_mapping.id_57752"),
    ["GTPV2_ULI_CELL_TAC"] = i18n("nprobe_mapping.id_57753"),
    ["GTPV2_ULI_CELL_ID"] = i18n("nprobe_mapping.id_57754"),
    ["GTPV2_RESPONSE_CAUSE"] = i18n("nprobe_mapping.id_57805"),
    ["GTPV2_RAT_TYPE"] = i18n("nprobe_mapping.id_57755"),
    ["GTPV2_PDN_IP"] = i18n("nprobe_mapping.id_57756"),
    ["GTPV2_END_USER_IMEI"] = i18n("nprobe_mapping.id_57757"),
    ["GTPV2_C2S_S5_S8_GTPC_IP"] = i18n("nprobe_mapping.id_57926"),
    ["GTPV2_S2C_S5_S8_GTPC_IP"] = i18n("nprobe_mapping.id_57927"),
    ["GTPV2_C2S_S5_S8_SGW_GTPU_TEID"] = i18n("nprobe_mapping.id_57928"),
    ["GTPV2_S2C_S5_S8_SGW_GTPU_TEID"] = i18n("nprobe_mapping.id_57929"),
    ["GTPV2_C2S_S5_S8_SGW_GTPU_IP"] = i18n("nprobe_mapping.id_57930"),
    ["GTPV2_S2C_S5_S8_SGW_GTPU_IP"] = i18n("nprobe_mapping.id_57931"),

    -- HTTP Protocol
    ["HTTP_URL"] = i18n("nprobe_mapping.id_57652"),
    ["HTTP_METHOD"] = i18n("nprobe_mapping.id_57832"),
    ["HTTP_RET_CODE"] = i18n("nprobe_mapping.id_57653"),
    ["HTTP_REFERER"] = i18n("nprobe_mapping.id_57654"),
    ["HTTP_UA"] = i18n("nprobe_mapping.id_57655"),
    ["HTTP_MIME"] = i18n("nprobe_mapping.id_57656"),
    ["HTTP_HOST"] = i18n("nprobe_mapping.id_57659"),
    ["HTTP_SITE"] = i18n("nprobe_mapping.id_57833"),
    ["HTTP_X_FORWARDED_FOR"] = i18n("nprobe_mapping.id_57932"),
    ["HTTP_VIA"] = i18n("nprobe_mapping.id_57933"),

    -- IMAP Protocol
    ["IMAP_LOGIN"] = i18n("nprobe_mapping.id_57732"),

    -- MySQL Plugin
    ["MYSQL_SERVER_VERSION"] = i18n("nprobe_mapping.id_57667"),
    ["MYSQL_USERNAME"] = i18n("nprobe_mapping.id_57668"),
    ["MYSQL_DB"] = i18n("nprobe_mapping.id_57669"),
    ["MYSQL_QUERY"] = i18n("nprobe_mapping.id_57670"),
    ["MYSQL_RESPONSE"] = i18n("nprobe_mapping.id_57671"),
    ["MYSQL_APPL_LATENCY_USEC"] = i18n("nprobe_mapping.id_57792"),

    -- NETBIOS Protocol
    ["NETBIOS_QUERY_NAME"] = i18n("nprobe_mapping.id_57936"),
    ["NETBIOS_QUERY_TYPE"] = i18n("nprobe_mapping.id_57937"),
    ["NETBIOS_RESPONSE"] = i18n("nprobe_mapping.id_57938"),
    ["NETBIOS_QUERY_OS"] = i18n("nprobe_mapping.id_57939"),

    -- Oracle Protocol
    ["ORACLE_USERNAME"] = i18n("nprobe_mapping.id_57672"),
    ["ORACLE_QUERY"] = i18n("nprobe_mapping.id_57673"),
    ["ORACLE_RSP_CODE"] = i18n("nprobe_mapping.id_57674"),
    ["ORACLE_RSP_STRING"] = i18n("nprobe_mapping.id_57675"),
    ["ORACLE_QUERY_DURATION"] = i18n("nprobe_mapping.id_57676"),

    -- OP3 Protocol
    ["POP_USER"] = i18n("nprobe_mapping.id_57682"),

    -- System process information
    ["SRC_PROC_PID"] = i18n("nprobe_mapping.id_57640"),
    ["SRC_PROC_NAME"] = i18n("nprobe_mapping.id_57641"),
    ["SRC_PROC_UID"] = i18n("nprobe_mapping.id_57897"),
    ["SRC_PROC_USER_NAME"] = i18n("nprobe_mapping.id_57844"),
    ["SRC_FATHER_PROC_PID"] = i18n("nprobe_mapping.id_57845"),
    ["SRC_FATHER_PROC_NAME"] = i18n("nprobe_mapping.id_57846"),
    ["SRC_PROC_ACTUAL_MEMORY"] = i18n("nprobe_mapping.id_57855"),
    ["SRC_PROC_PEAK_MEMORY"] = i18n("nprobe_mapping.id_57856"),
    ["SRC_PROC_AVERAGE_CPU_LOAD"] = i18n("nprobe_mapping.id_57857"),
    ["SRC_PROC_NUM_PAGE_FAULTS"] = i18n("nprobe_mapping.id_57858"),
    ["SRC_PROC_PCTG_IOWAIT"] = i18n("nprobe_mapping.id_57865"),
    ["DST_PROC_PID"] = i18n("nprobe_mapping.id_57847"),
    ["DST_PROC_NAME"] = i18n("nprobe_mapping.id_57848"),
    ["DST_PROC_UID"] = i18n("nprobe_mapping.id_57898"),
    ["DST_PROC_USER_NAME"] = i18n("nprobe_mapping.id_57849"),
    ["DST_FATHER_PROC_PID"] = i18n("nprobe_mapping.id_57850"),
    ["DST_FATHER_PROC_NAME"] = i18n("nprobe_mapping.id_57851"),
    ["DST_PROC_ACTUAL_MEMORY"] = i18n("nprobe_mapping.id_57859"),
    ["DST_PROC_PEAK_MEMORY"] = i18n("nprobe_mapping.id_57860"),
    ["DST_PROC_AVERAGE_CPU_LOAD"] = i18n("nprobe_mapping.id_57861"),
    ["DST_PROC_NUM_PAGE_FAULTS"] = i18n("nprobe_mapping.id_57862"),
    ["DST_PROC_PCTG_IOWAIT"] = i18n("nprobe_mapping.id_57866"),

    -- Radius Protocol
    ["RADIUS_REQ_MSG_TYPE"] = i18n("nprobe_mapping.id_57712"),
    ["RADIUS_RSP_MSG_TYPE"] = i18n("nprobe_mapping.id_57713"),
    ["RADIUS_USER_NAME"] = i18n("nprobe_mapping.id_57714"),
    ["RADIUS_CALLING_STATION_ID"] = i18n("nprobe_mapping.id_57715"),
    ["RADIUS_CALLED_STATION_ID"] = i18n("nprobe_mapping.id_57716"),
    ["RADIUS_NAS_IP_ADDR"] = i18n("nprobe_mapping.id_57717"),
    ["RADIUS_NAS_IDENTIFIER"] = i18n("nprobe_mapping.id_57718"),
    ["RADIUS_USER_IMSI"] = i18n("nprobe_mapping.id_57719"),
    ["RADIUS_USER_IMEI"] = i18n("nprobe_mapping.id_57720"),
    ["RADIUS_FRAMED_IP_ADDR"] = i18n("nprobe_mapping.id_57721"),
    ["RADIUS_ACCT_SESSION_ID"] = i18n("nprobe_mapping.id_57722"),
    ["RADIUS_ACCT_STATUS_TYPE"] = i18n("nprobe_mapping.id_57723"),
    ["RADIUS_ACCT_IN_OCTETS"] = i18n("nprobe_mapping.id_57724"),
    ["RADIUS_ACCT_OUT_OCTETS"] = i18n("nprobe_mapping.id_57725"),
    ["RADIUS_ACCT_IN_PKTS"] = i18n("nprobe_mapping.id_57726"),
    ["RADIUS_ACCT_OUT_PKTS"] = i18n("nprobe_mapping.id_57727"),

    -- RTP Plugin
    ["RTP_SSRC"] = i18n("nprobe_mapping.id_57909"),
    ["RTP_FIRST_SEQ"] = i18n("nprobe_mapping.id_57622"),
    ["RTP_FIRST_TS"] = i18n("nprobe_mapping.id_57623"),
    ["RTP_LAST_SEQ"] = i18n("nprobe_mapping.id_57624"),
    ["RTP_LAST_TS"] = i18n("nprobe_mapping.id_57625"),
    ["RTP_IN_JITTER"] = i18n("nprobe_mapping.id_57626"),
    ["RTP_OUT_JITTER"] = i18n("nprobe_mapping.id_57627"),
    ["RTP_IN_PKT_LOST"] = i18n("nprobe_mapping.id_57628"),
    ["RTP_OUT_PKT_LOST"] = i18n("nprobe_mapping.id_57629"),
    ["RTP_IN_PKT_DROP"] = i18n("nprobe_mapping.id_57902"),
    ["RTP_OUT_PKT_DROP"] = i18n("nprobe_mapping.id_57903"),
    ["RTP_IN_PAYLOAD_TYPE"] = i18n("nprobe_mapping.id_57633"),
    ["RTP_OUT_PAYLOAD_TYPE"] = i18n("nprobe_mapping.id_57630"),
    ["RTP_IN_MAX_DELTA"] = i18n("nprobe_mapping.id_57631"),
    ["RTP_OUT_MAX_DELTA"] = i18n("nprobe_mapping.id_57632"),
    ["RTP_SIP_CALL_ID"] = i18n("nprobe_mapping.id_57820"),
    ["RTP_MOS"] = i18n("nprobe_mapping.id_57906"),
    ["RTP_IN_MOS"] = i18n("nprobe_mapping.id_57842"),
    ["RTP_OUT_MOS"] = i18n("nprobe_mapping.id_57904"),
    ["RTP_R_FACTOR"] = i18n("nprobe_mapping.id_57908"),
    ["RTP_IN_R_FACTOR"] = i18n("nprobe_mapping.id_57843"),
    ["RTP_OUT_R_FACTOR"] = i18n("nprobe_mapping.id_57905"),
    ["RTP_IN_TRANSIT"] = i18n("nprobe_mapping.id_57853"),
    ["RTP_OUT_TRANSIT"] = i18n("nprobe_mapping.id_57854"),
    ["RTP_RTT"] = i18n("nprobe_mapping.id_57852"),
    ["RTP_DTMF_TONES"] = i18n("nprobe_mapping.id_57867"),

    -- S1AP Protocol
    ["S1AP_ENB_UE_S1AP_ID"] = i18n("nprobe_mapping.id_57879"),
    ["S1AP_MME_UE_S1AP_ID"] = i18n("nprobe_mapping.id_57880"),
    ["S1AP_MSG_EMM_TYPE_MME_TO_ENB"] = i18n("nprobe_mapping.id_57881"),
    ["S1AP_MSG_ESM_TYPE_MME_TO_ENB"] = i18n("nprobe_mapping.id_57882"),
    ["S1AP_MSG_EMM_TYPE_ENB_TO_MME"] = i18n("nprobe_mapping.id_57883"),
    ["S1AP_MSG_ESM_TYPE_ENB_TO_MME"] = i18n("nprobe_mapping.id_57884"),
    ["S1AP_CAUSE_ENB_TO_MME"] = i18n("nprobe_mapping.id_57885"),
    ["S1AP_DETAILED_CAUSE_ENB_TO_MME"] = i18n("nprobe_mapping.id_57886"),

    -- SIP Plugin
    ["SIP_CALL_ID"] = i18n("nprobe_mapping.id_57602"),
    ["SIP_CALLING_PARTY"] = i18n("nprobe_mapping.id_57603"),
    ["SIP_CALLED_PARTY"] = i18n("nprobe_mapping.id_57604"),
    ["SIP_RTP_CODECS"] = i18n("nprobe_mapping.id_57605"),
    ["SIP_INVITE_TIME"] = i18n("nprobe_mapping.id_57606"),
    ["SIP_TRYING_TIME"] = i18n("nprobe_mapping.id_57607"),
    ["SIP_RINGING_TIME"] = i18n("nprobe_mapping.id_57608"),
    ["SIP_INVITE_OK_TIME"] = i18n("nprobe_mapping.id_57609"),
    ["SIP_INVITE_FAILURE_TIME"] = i18n("nprobe_mapping.id_57610"),
    ["SIP_BYE_TIME"] = i18n("nprobe_mapping.id_57611"),
    ["SIP_BYE_OK_TIME"] = i18n("nprobe_mapping.id_57612"),
    ["SIP_CANCEL_TIME"] = i18n("nprobe_mapping.id_57613"),
    ["SIP_CANCEL_OK_TIME"] = i18n("nprobe_mapping.id_57614"),
    ["SIP_RTP_IPV4_SRC_ADDR"] = i18n("nprobe_mapping.id_57615"),
    ["SIP_RTP_L4_SRC_PORT"] = i18n("nprobe_mapping.id_57616"),
    ["SIP_RTP_IPV4_DST_ADDR"] = i18n("nprobe_mapping.id_57617"),
    ["SIP_RTP_L4_DST_PORT"] = i18n("nprobe_mapping.id_57618"),
    ["SIP_RESPONSE_CODE"] = i18n("nprobe_mapping.id_57619"),
    ["SIP_REASON_CAUSE"] = i18n("nprobe_mapping.id_57620"),
    ["SIP_C_IP"] = i18n("nprobe_mapping.id_57834"),
    ["SIP_CALL_STATE"] = i18n("nprobe_mapping.id_57835"),

    -- SMTP Protocol
    ["SMTP_MAIL_FROM"] = i18n("nprobe_mapping.id_57657"),
    ["SMTP_RCPT_TO"] = i18n("nprobe_mapping.id_57658"),

    -- SSDP Protocol
    ["SSDP_HOST"] = i18n("nprobe_mapping.id_57934"),
    ["SSDP_USN"] = i18n("nprobe_mapping.id_57935"),
    ["SSDP_SERVER"] = i18n("nprobe_mapping.id_57940"),
    ["SSDP_TYPE"] = i18n("nprobe_mapping.id_57941"),
    ["SSDP_METHOD"] = i18n("nprobe_mapping.id_57942"),
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
  if(call_state == "CALL_STARTED") then return("Call Started")
  elseif(call_state == "CALL_IN_PROGRESS") then return("Ongoing Call")
  elseif(call_state == "CALL_COMPLETED") then return("<font color=green>Call Completed</font>")
  elseif(call_state == "CALL_ERROR") then return("<font color=red>Call Error</span>")
  elseif(call_state == "CALL_CANCELED") then return("<font color=orange>Call Canceled</span>")
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
        returnString =  calling_party .. " <-> " .. called_party
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
     string_table = string_table.."<tr><th colspan=3 class=\"info\" >SIP Protocol Information</th></tr>\n"
     call_id = getFlowValue(info, "SIP_CALL_ID")
     if((call_id == nil) or (call_id == "")) then
       string_table = string_table.."<tr id=\"call_id_tr\" style=\"display: none;\"><th width=33%> Call-ID "..call_id_ico.."</th><td colspan=2><div id=call_id></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"call_id_tr\" style=\"display: table-row;\"><th width=33%> Call-ID "..call_id_ico.."</th><td colspan=2><div id=call_id>" .. call_id .. "</div></td></tr>\n"
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
       string_table = string_table.."<tr id=\"rtp_codecs_tr\" style=\"display: none;\"><th width=33%>RTP Codecs</th><td colspan=2> <div id=rtp_codecs></></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"rtp_codecs_tr\" style=\"display: table-row;\"><th width=33%>RTP Codecs</th><td colspan=2> <div id=rtp_codecs>" .. rtp_codecs .. "</></td></tr>\n"
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
       string_table = string_table.."<tr id=\"rtp_stream_tr\" style=\"display: table-row;\"><th width=33%>RTP Stream Peers (src <i class=\"fa fa-exchange fa-lg\"></i> dst)</th><td colspan=2><div id=rtp_stream>"
     else
       string_table = string_table.."<tr id=\"rtp_stream_tr\" style=\"display: none;\"><th width=33%>RTP Stream Peers (src <i class=\"fa fa-exchange fa-lg\"></i> dst)</th><td colspan=2><div id=rtp_stream>"
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
	string_table = string_table..'<span class="label label-info">RTP Flow</span></a>'
     end
     string_table = string_table.."</div></td></tr>\n"

     val, val_original = getFlowValue(info, "SIP_REASON_CAUSE")
     if(val_original ~= "0") then
        string_table = string_table.."<tr id=\"cbf_reason_cause_tr\" style=\"display: table-row;\"><th width=33%> Cancel/Bye/Failure Reason Cause </th><td colspan=2><div id=reason_cause>"
        string_table = string_table..val
     else
        string_table = string_table.."<tr id=\"cbf_reason_cause_tr\" style=\"display: none;\"><th width=33%> Cancel/Bye/Failure Reason Cause </th><td colspan=2><div id=reason_cause>"
     end
     string_table = string_table.."</div></td></tr>\n"
     if(info["SIP_C_IP"]  ~= nil) then
       string_table = string_table.."<tr id=\"sip_c_ip_tr\" style=\"display: table-row;\"><th width=33%> C IP Addresses </th><td colspan=2><div id=c_ip>" .. getFlowValue(info, "SIP_C_IP") .. "</div></td></tr>\n"
     end

     if((getFlowValue(info, "SIP_CALL_STATE") == nil) or (getFlowValue(info, "SIP_CALL_STATE") == "")) then
       string_table = string_table.."<tr id=\"sip_call_state_tr\" style=\"display: none;\"><th width=33%> Call State </th><td colspan=2><div id=call_state></div></td></tr>\n"
     else
       string_table = string_table.."<tr id=\"sip_call_state_tr\" style=\"display: table-row;\"><th width=33%> Call State </th><td colspan=2><div id=call_state>" .. mapCallState(getFlowValue(info, "SIP_CALL_STATE")) .. "</div></td></tr>\n"
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
      string_table = string_table.."<tr><th colspan=3 class=\"info\" >RTP Protocol Information</th></tr>\n"
      if(info["RTP_SSRC"] ~= nil) then
	 sync_source_var = getFlowValue(info, "RTP_SSRC")
	 if((sync_source_var == nil) or (sync_source_var == "")) then
	    sync_source_hide = "style=\"display: none;\""
	 else
	    sync_source_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table.."<tr id=\"sync_source_id_tr\" "..sync_source_hide.." ><th> Sync Source ID </th><td colspan=2><div id=sync_source_id>" .. sync_source_var .. "</td></tr>\n"
      end
      
      -- ROUND-TRIP-TIME
      if(info["RTP_RTT"] ~= nil) then	 
	 rtp_rtt_var = getFlowValue(info, "RTP_RTT")
	 if((rtp_rtt_var == nil) or (rtp_rtt_var == "")) then
	    rtp_rtt_hide = "style=\"display: none;\""
	 else
	    rtp_rtt_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"rtt_id_tr\" "..rtp_rtt_hide.."><th>Round Trip Time</th><td colspan=2><span id=rtp_rtt>"
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
	 
	 string_table = string_table .. "<tr id=\"rtp_transit_id_tr\" "..rtp_transit_hide.."><th>RTP Transit IN / OUT</th><td><div id=rtp_transit_in>"..getFlowValue(info, "RTP_IN_TRANSIT").."</div></td><td><div id=rtp_transit_out>"..getFlowValue(info, "RTP_OUT_TRANSIT").."</div></td></tr>\n"
      end
      
      -- TONES
      if(info["RTP_DTMF_TONES"] ~= nil) then	 
	 rtp_dtmf_var = getFlowValue(info, "RTP_DTMF_TONES")
	 if((rtp_dtmf_var == nil) or (rtp_dtmf_var == "")) then
	    rtp_dtmf_hide = "style=\"display: none;\""
	 else
	    rtp_dtmf_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"dtmf_id_tr\" ".. rtp_dtmf_hide .."><th>DTMF tones sent during the call</th><td colspan=2><span id=dtmf_tones>"..rtp_dtmf_var.."</span></td></tr>\n"
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
	 string_table = string_table .. "<tr id=\"first_last_flow_sequence_id_tr\" "..first_last_flow_sequence_hide.."><th>First / Last Flow Sequence</th><td><div id=first_flow_sequence>"..first_flow_sequence_var.."</div></td><td><div id=last_flow_sequence>"..last_flow_sequence_var.."</div></td></tr>\n"
      end
      
      -- CALL-ID
      if(info["RTP_SIP_CALL_ID"] ~= nil) then	 
	 sip_call_id_var = getFlowValue(info, "RTP_SIP_CALL_ID")
	 if((sip_call_id_var == nil) or (sip_call_id_var == "")) then
	    sip_call_id_hide = "style=\"display: none;\""
      else
	 sip_call_id_hide = "style=\"display: table-row;\""
	 end
	 string_table = string_table .. "<tr id=\"sip_call_id_tr\" "..sip_call_id_hide.."><th> SIP Call-ID <i class='fa fa-phone fa-sm' aria-hidden='true' title='SIP Call-ID'></i>&nbsp;</th><td colspan=2><div id=rtp_sip_call_id>" .. sip_call_id_var .. "</div></td></tr>\n"
      end
      
      -- TWO-WAY CALL-QUALITY INDICATORS
      string_table = string_table.."<tr><th>Call Quality Indicators</th><th>Forward</th><th>Reverse</th></tr>"
      -- JITTER
      if(info["RTP_IN_JITTER"] ~= nil) then	 
	 rtp_in_jitter = getFlowValue(info, "RTP_IN_JITTER")/100
	 rtp_out_jitter = getFlowValue(info, "RTP_OUT_JITTER")/100
	 if(((rtp_in_jitter == nil) or (rtp_in_jitter == "")) and ((rtp_out_jitter == nil) or (rtp_out_jitter == ""))) then
	    rtp_out_jitter_hide = "style=\"display: none;\""
	 else
	    rtp_out_jitter_hide = "style=\"display: table-row;\""
	 end	 
	 string_table = string_table .. "<tr id=\"jitter_id_tr\" "..rtp_out_jitter_hide.."><th style=\"text-align:right\">Jitter</th><td><span id=jitter_in>"
	 
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
	 string_table = string_table .. "<tr id=\"rtp_packet_loss_id_tr\" "..rtp_packet_loss_hide.."><th style=\"text-align:right\">Lost Packets</th><td><span id=packet_lost_in>"
	 
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
	 string_table = string_table .. "<tr id=\"packet_drop_id_tr\" "..rtp_pkt_drop_hide.."><th style=\"text-align:right\">Dropped Packets</th><td><span id=packet_drop_in>"
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
	 string_table = string_table .. "<tr id=\"delta_time_id_tr\" "..rtp_max_delta_hide.."><th style=\"text-align:right\">Max Packet Interarrival Time</th><td><span id=max_delta_time_in>"
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
	 string_table = string_table .. "<tr id=\"payload_id_tr\" "..rtp_payload_hide.."><th style=\"text-align:right\">Payload Type</th><td><div id=payload_type_in>"..rtp_payload_in_var.."</div></td><td><div id=payload_type_out>"..rtp_payload_out_var.."</div></td></tr>\n"
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
	 string_table = string_table .. "<tr id=\"quality_mos_id_tr\" ".. quality_mos_hide .."><th style=\"text-align:right\">(Pseudo) MOS</th><td><span id=mos_in_signal></span><span id=mos_in>"
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
	 string_table = string_table .. "<tr id=\"quality_r_factor_id_tr\" ".. quality_r_factor_hide .."><th style=\"text-align:right\">R-Factor</th><td><span id=r_factor_in_signal></span><span id=r_factor_in>"
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
