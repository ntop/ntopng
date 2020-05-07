--
-- (C) 2018 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
ignore_post_payload_parse = 1
require "lua_utils"

local google = require "google_assistant_utils"
local net_state = require "network_state"

local response, request

--[[
see "ndpi_get_proto_breed_name( ... )" in ndpi_main.c for more info

NDPI_PROTOCOL_SAFE:                   "Safe"           /* Surely doesn't provide risks for the network. (e.g., a news site) */
NDPI_PROTOCOL_ACCEPTABLE:             "Acceptable"     /* Probably doesn't provide risks, but could be malicious (e.g., Dropbox) */
NDPI_PROTOCOL_FUN:                    "Fun"            /* Pure fun protocol, which may be prohibited by the user policy (e.g., Netflix) */
NDPI_PROTOCOL_UNSAFE:                 "Unsafe"         /* Probably provides risks, but could be a normal traffic. Unencrypted protocols with clear pass should be here (e.g., telnet) */
NDPI_PROTOCOL_POTENTIALLY_DANGEROUS:  "Dangerous"      /* Surely is dangerous (ex. Tor). Be prepared to troubles */
NDPI_PROTOCOL_UNRATED:                "Unrated"        /* No idea, not implemented or impossible to classify */
]]--
---------------------------------LOCAL FUNCTIONS------------------------------------------

local function translate_ndpi_breeds(table)
  local t = {}

  for i,v in pairs(table) do
    if        i == "Safe"         then t["Sicuro"] = v
    elseif    i == "Unsafe"       then t["Potenzialmente Pericoloso"] = v
    elseif    i == "Dangerous"    then t["Pericoloso"] = v
    elseif    i == "Fun"          then t["Divertimento"] = v
    elseif    i == "Acceptable"   then t["Accettabile"] = v
    else      t["Altro"] = v
    end
  end
  
  return t
end

local function are_app_and_hosts_good()
  local ndpi_breeds, blacklisted_host_num, danger  = net_state.check_bad_hosts_and_app()
  local prc_safe = ndpi_breeds["Safe"] or 0 
  local safe_text, score, text = "", 0, ""

  if ndpi_breeds == nil then
    google.send("Non sono riuscito ad eseguire la richiesta")
  end

  if ndpi_breeds["Safe"] then
    score = score + ( ndpi_breeds["Safe"]["perc"] or 0 )
  end

  if ndpi_breeds["Fun"] then
    score = score + ( (ndpi_breeds["Fun"]["perc"] or 0) * 0.85 )
  end
  if ndpi_breeds["Acceptable"] then
    score = score + ( (ndpi_breeds["Acceptable"]["perc"] or 0) * 0.8 )
  end

  --score = ( ndpi_breeds["Safe"]["perc"] or 0 )  +  ( (ndpi_breeds["Fun"]["perc"] or 0) * 0.85 )  +  ( (ndpi_breeds["Acceptable"]["perc"] or 0) * 0.8 )
  if score >= 99 then 
    safe_text = ", in generale, sono sicure"
  elseif score >= 90 then
    safe_text = "sono per la maggior parte sicure"
  elseif score >= 75 then
    safe_text = "sono per lo più sicure"
  elseif score >= 50 then
    safe_text = "sono parzialmente sicure"
  elseif score >= 25 then
    safe_text = "sono poco sicure"
  else 
    safe_text = "sono potenzialmente pericolose"
  end

  local bl_num_txt = ""
  if blacklisted_host_num == 0 then
    bl_num_txt = "Nessun host indesiderato.\n"
  elseif blacklisted_host_num == 1 then
    bl_num_txt = "Un host indesiderato.\n"
  else 
    bl_num_txt = blacklisted_host_num .. " host indesiderati.\n"
  end

  text = bl_num_txt .. "Le comunicazioni "..safe_text

  if danger then text = text .. ". \nMa attenzione! È stato rilevato traffico pericoloso! " end

  return text
end


local function send_text_telegram(text) 
  local chat_id, bot_token = ntop.getCache("ntopng.prefs.telegram_chat_id"), ntop.getCache("ntopng.prefs.telegram_bot_token")

  io.write(chat_id.." "..bot_token )

    if( string.len(text) >= 4096 ) then 
      text = string.sub( text, 1, 4096 )
    end

    if (bot_token and chat_id) and (bot_token ~= "") and (chat_id ~= "") then 
      os.execute("curl -X POST  https://api.telegram.org/bot"..bot_token.."/sendMessage -d chat_id="..chat_id.." -d text=\" " ..text.." \" ")
      return 0

    else
      return 1
    end
end

local function danger_app()
  local danger_apps = net_state.check_dangerous_traffic()
  local text = "Ho rilevato queste applicazioni pericolose:\n"
  local unit = "bytes"

  local display_text = "Applicazioni pericolose:\n"
  local display_unit = unit

  if danger_apps == nil then 
    text = "Non rilevo nessuna comunicazione pericolosa"
    display_text = "Non rilevo nessuna comunicazione pericolosa"
    return text, display_text, false

  else
    for i,v in pairs(danger_apps) do
      tb = v.total_bytes 

      if tb > 512 then 
        tb = math.floor( (tb / 1024) * 100 )/100
        unit = "KiloBytes"
        display_unit = "KB"
      end
      if tb > 512 then
        tb = math.floor( (tb / 1024) * 100 )/100
        unit = "MegaBytes"
        display_unit = "MB"
      end

      text = text.. v.name .. " che ha generato un volume di traffico pari a " ..tb .. " "..unit.."\n"
      display_text = display_text .."-" ..v.name .. ". volume traffico: "..tb.." ".. display_unit .."\n" 
    end
  end

  return text, display_text, true
end

-------------------------------------INTENTS HANDLER FUNCTIONS-------------------------------------------


function handler_upTime()
  local uptime, time = ntop.getUptime()
  if uptime > 3600 then
    time = secondsToTime( uptime ) 
  else
    time = math.floor(uptime / 60).." minuti e ".. math.fmod(uptime, 60).. " secondi"
  end

  google.send( "Sono in esecuzione da ".. time  ) 
end


function handler_Network_State()
  local stats = net_state.check_ifstats_table()
  local alert_num, severity = net_state.check_num_alerts_and_severity()
  local alert_text = ""

  if alert_num > 0 then
    alert_text = alert_num .. " allarmi scattati, di cui "

    for i,v in pairs(severity) do
      if v > 0 then  alert_text = alert_text .. v .. " " .. i .. ", " end
    end

    alert_text = string.sub(alert_text,1,-2)
    alert_text = string.sub(alert_text,1,-2)
    alert_text = alert_text..".\n"

  else
    alert_text = "0 allarmi scattati\n"
  end

  local app_host_good_text, b, danger = are_app_and_hosts_good()

  local text = "Rilevo:\n"..stats.device_num.." dispositivi collegati, "..stats.local_host_num..
  " host locali, "  ..stats.flow_num.." flussi attivi.\n".. alert_text.. app_host_good_text

  local sugg = {}
  if danger and alert_num > 0 then 
    sugg = {"traffico pericoloso", "allarmi attivi"}
  elseif danger and alert_num == 0  then
    sugg = {"traffico pericoloso"}
  elseif not danger and alert_num > 0   then
    sugg = {"allarmi attivi"}
  else --not danger and alert_num == 0
    sugg = {}
  end

  google.send(text, nil, nil, sugg)
end


function handler_network_state_communication()
  local stats, text = net_state.check_net_communication(),""
  local ctg, prc = net_state.check_top_traffic_application_protocol_categories()

  if stats.prc_remote2local_traffic + stats.prc_local2remote_traffic < 50 then
    text = text .. "Il traffico è prevalentemente interno alla rete "
  elseif stats.prc_remote2local_traffic > stats.prc_local2remote_traffic then 
    text = text .. "La maggior parte del traffico dati proviene dall'esterno della rete, "
  else 
    text = text .. "Il traffico è per lo più inviato verso l'esterno della rete, "
  end

  text = text .. " di cui il "..prc.." percento è di tipo "..ctg..

  ". L'efficienza di trasmissione dati è "..net_state.check_TCP_flow_goodput() ..". Dimmi pure se vuoi approfondire qualcosa"

  google.send( text, nil, nil, {"categorie traffico","efficienza trasmissioni","traffico locale/remoto"} )
end


function handler_traffic_app_info()
  local stats = net_state.check_top_application_protocol()
  local text, top_num, j = "", 0, 1
  
  if      stats[3] then top_num = 3
  elseif  stats[2] then top_num = 2
  elseif  stats[1] then top_num = 1
  end

  if top_num == 1 then 
    text = "L'unico protocollo applicativo rilevato è "..stats[1][1].." con il "..stats[1][2] .." percento del traffico."
  end

  local text_name, text_perc
  if top_num > 1 then 
    text_name = "I ".. top_num .." principali protocolli applicativi sono: "..(stats[1][1] or "")..", "..(stats[2][1] or "")..", e "..(stats[3][1] or "")
    text_perc = "; Con un traffico, rispettivamente, del "..(stats[1][2] or "")..", "..(stats[2][2] or "")..", "..(stats[3][2] or "").. " percento"
    text = text_name..text_perc
  else 
    text = "Non ho ancora rilevato nessun protocollo applicativo" 
    google.send(text)
  end


  local display_text = ""
  for i=1,3 do
    if stats[i] then 
      display_text = display_text .. stats[i][1]..": ".. stats[i][2].."%;\n"
    end
  end


  if #stats > 5 then
    text = text .. ". Vuoi che ti scriva l'elenco delle ".. #stats-top_num.." app rimanenti?"
    display_text = display_text .. "Vuoi che ti scriva l'elenco delle ".. #stats-top_num.." app rimanenti?"
  end

  google.send(text, display_text, nil, {"Sì","No"})
end

function handler_traffic_app_info_more_info()
  local stats, text = net_state.check_top_application_protocol(), ""
  local if_0 = "< 1%; "

  for i,v in pairs(stats) do
    if i > 3 then
      if v[2] == 0 then 
        text = text ..  v[1]..": "..if_0
      else
        text = text ..  v[1]..": "..v[2].." %; "
      end
      text = text .. "\n"
    end
  end

  google.send("Ecco a te l'elenco",text)
end


function handler_device_info()
  local info, devices_num = net_state.check_devices_type()
  local text2 = ""
  
  text = "Rilevo "..  devices_num.. " dispositivi collegati. "

  for i,v in pairs(info) do
    if i ~= "Unknown" then text2 = text2 .. v.. " ".. i.. ", " end
  end

  if text2 ~= "" then 
    text =  text .. "Tra cui ".. text2
  end

  text = text .. ". Vuoi informazioni più dettagliate?"

  google.send(text, text, true, {"Sì","No"})
end


function handler_send_devices_info()
  local limit, text = request["parameters"]["number"], ""
  local discover = require "discover_utils"
  local callback = require "callback_utils"
  local devices_stats = callback.getDevicesIterator()
  local manufacturer = ""

  local cont = 0
  for i, v in devices_stats do

    if v.source_mac and (cont < limit) then 
      cont = cont + 1
      text = text .. cont .." Nome: ".. mac2label(v.mac) .. "\n"
      if v.manufacturer then manufacturer = v.manufacturer else manufacturer = "Sconosciuto" end
      text = text .. "Costruttore: " .. manufacturer .. "\n"
      text = text .. "Mac: " .. v.mac .. "\n"
      text = text .. "Tipo: " .. discover.devtype2string(v.devtype) .. "\n"
      text = text .. "Byte inviati " .. v["bytes.sent"] .. "\n"
      text = text .. "Byte ricevuti " .. v["bytes.rcvd"] .. "\n"
      text = text .. "\n"
    end
    
  end

  if limit >4 then 
    if (send_text_telegram(text) == 0) then
      google.send("Info inviate su Telegram")
    else
      google.send("Ops, invio su Telegram fallito. Sicuro di aver impostato token e chat id?")
    end
  else
    google.send("Ecco a te", text)
  end

end


function handler_suspicious_activity_more_info()
  local ndpi_breeds, blacklisted_host_num, danger  = net_state.check_bad_hosts_and_app()
  local res = {}
  local text = ""
  local d_text = ""
  local alert_text = ""

  d_text = "Traffico dati:\n"
  text = d_text

  if  ndpi_breeds["Safe"] then
    table.insert( res, {nome = "è sicuro", perc = ndpi_breeds["Safe"]["perc"], bytes = ndpi_breeds["Safe"]["bytes"]  } )
  end

  if  ndpi_breeds["Acceptable"] and ndpi_breeds["Fun"]  then
    table.insert( res, {nome = "è accettabile", perc = ndpi_breeds["Acceptable"]["perc"]  + ndpi_breeds["Fun"]["perc"], bytes = ndpi_breeds["Acceptable"]["bytes"] + ndpi_breeds["Fun"]["bytes"] } )
    
  elseif  ndpi_breeds["Acceptable"]   then
    table.insert( res, {nome = "è accettabile", perc = ndpi_breeds["Acceptable"]["perc"], bytes = ndpi_breeds["Acceptable"]["bytes"] } )
  end
  
  if  ndpi_breeds["Unrated"] then
    table.insert( res, {nome = "non è valutabile", perc = ndpi_breeds["Unrated"]["perc"], bytes = ndpi_breeds["Unrated"]["bytes"] } )
  end

  if  ndpi_breeds["Other"] then
    table.insert( res, {nome = "è di altro tipo", perc = ndpi_breeds["Other"]["perc"], bytes = ndpi_breeds["Other"]["bytes"] } )
  end

  if  ndpi_breeds["Dangerous"] then
    table.insert( res, {nome = "è pericoloso", perc = ndpi_breeds["Dangerous"]["perc"], bytes = ndpi_breeds["Dangerous"]["bytes"] } )
  end

  local function compare(a, b) return a["perc"] > b["perc"] end
  table.sort(res, compare)

  local if_0 = "< 1%"

  for i,v in pairs(res) do 
    if v and v.perc == 0 and  v.bytes > 0 then 
      text = text .. "meno dell' 1 percento del traffico "..v.nome..","
    elseif v and v.bytes and v.bytes > 0 then
      text = text.." il "..v.perc.." percento del traffico "..v.nome..","
    end
  end

  
  for i,v in pairs(res) do 
    if v.perc == 0 and v.bytes and v.bytes > 0 then 
      d_text = d_text .. if_0 .. " ".. v.nome..";\n"
    elseif v and v.bytes and v.bytes > 0 then
      d_text = d_text.. v.perc .. "% "..v.nome..";\n"
    end
  end

  danger_text, danger_display_text, danger_flag = danger_app()
  if danger_flag then

    text = text .."\n\n"..danger_text
    d_text = d_text .."\n\n" .. danger_display_text

  end

  google.send(text, d_text)
end


function handler_suspicious_activity()

  google.send( are_app_and_hosts_good() ..  ". Vuoi saperne di più sulla sicurezza del traffico?", nil, nil, {"Sì", "No"} )
end


function local_remote_traffic()
  local stats, text = net_state.check_net_communication(),""

  text = "il "..stats.prc_remote2local_traffic.."% del traffico è in entrata, il "..
  stats.prc_local2remote_traffic.." è in uscita e il "..100 -(stats.prc_remote2local_traffic +stats.prc_local2remote_traffic)  .."% è interno alla rete. "

  return text
end

function flow_efficency()
  local global_state, flow_tot, bad_gp = net_state.check_TCP_flow_goodput()
  local stats= net_state.check_net_communication()

  local text = "l'efficienza delle comunicazioni è " .. global_state .. ". Su ".. flow_tot .. " flussi attivi "..bad_gp.. " hanno rallentamenti. "

  if stats.prc_pkt_drop < 1 then text = text .. "La perdita di pacchetti è trascurabile"
  else text =  text .. "Sono andati persi il".. stats.prc_pkt_drop .. "% pacchetti."
  end

  local display_text = "l'efficienza delle comunicazioni è " .. global_state .. ". Su ".. flow_tot .. " flussi (TCP) attivi "..bad_gp.. " hanno rallentamenti. "

  local pkt_drop_txt= ""
  if stats.prc_pkt_drop == 0.000 then pkt_drop_txt = "< 0.01%"
  else pkt_drop_txt = pkt_drop_txt .. stats.prc_pkt_drop .. "%"
  end

  if stats.prc_pkt_drop < 0.09 then display_text = display_text .. "La perdita di pacchetti è trascurabile: "..pkt_drop_txt.."\n"
  else 
    display_text =  display_text .. "Persi il ".. stats.prc_pkt_drop .. "% pacchetti.\n"
  end
  display_text = display_text.. "[ " .. stats.num_pkt_drop.. " su " .. stats.num_tot_pkt.."]"

  return text, display_text
end


function handler_traffic_category()
  local categories = net_state.check_traffic_categories()
  local text, d_text = "", ""

  local cont = 0
  
  for i,v in pairs(categories) do
    if v.perc > 10 then cont = cont + 1 end
  end

  if cont == 0 then 
    text = "non riesco a rilevare le categorie del traffico"
    return google.send(text)

  elseif cont == 1 then 
    text = "L'unica categoria rilevante è ".. categories[1].name.. " con il "..categories[1].perc.."% del traffico"

  else
    text = "Le "..cont.."categorie più rilevanti sono: "
    for i,v in pairs(categories) do
      if v.perc > 10 then 
        text = text .. categories[i].name .. " con il ".. categories[i].perc.."%;\n"
      end
    end
  end

  for i,v in pairs(categories) do
    d_text = d_text .. categories[i].name .. " - ".. categories[i].perc.."%;\n"
  end

  return text, d_text
end


function handler_network_state_communication_more_info()
  local param, text, display_text = request["parameters"]["Communication"], "Ops, ho un problema, prova a chiedermi altro", "Ops, ho un problema, prova a chiedermi altro"
  local v = param[1]

  if     v == "categorie traffico"      then 
    text, display_text =  handler_traffic_category()

  elseif v == "traffico locale/remoto"  then 
    text = local_remote_traffic()
    display_text = text
  elseif v == "efficienza trasmissioni" then 
    text, display_text =  flow_efficency()

    for ii,vv in pairs(param) do
      if v == vv then table.remove( param, ii ) end 
    end

  end

  google.send(text, display_text, nil, {"categorie traffico","traffico locale/remoto","efficienza trasmissioni"})
end


function handler_dangerous_communications_detected()

  local text, display_text = danger_app()
  google.send(text, display_text)
end


function handler_ntopng()
  local display_text = "Sono l'assistente vocale di ntopng"
  local speech_text = "Sono l'assistente vocale di n top n g, scopri di più visitando il sito!"
  local card_title = "ntopng: High-Speed Web-based Traffic Analysis and Flow Collection"
  local card_url_image = "https://www.ntop.org/wp-content/uploads/2011/08/ntopng-icon-150x150.png"
  local accessibility_text = "ntopng_logo"
  local button_title = "Vai al sito"
  local button_open_url_action = "https://www.ntop.org/products/traffic-analysis/ntop/"
  local card = google.create_card(card_title, card_url_image, accessibility_text,button_title, button_open_url_action)

  google.send(speech_text, display_text, nil, nil, card)
end


function handler_what_can_you_do()
  local text = "Posso tenerti aggiornato sullo stato della tua rete, descriverti come vanno le comunicazioni, dirti chi è connesso in questo momento, informarti se ci sono attività sospette in corso, avviare una cattura di pacchetti e molto altro!"
  sugg = {
    "Come sta la rete",
    "Stato delle comunicazioni",
    "Traffico Applicativo",
    "Attività sospette",
    "Dispositivi connessi",
    "Avvia cattura pacchetti",
    "Chi sei",
    "Tempo dall'avvio"
  }

  google.send(text, nil, nil, sugg)
end


function handler_alert_more_info()
  local text, display_text = "",""
  local alerts = net_state.alerts_details()

  if not alerts then 
    google.send("Non ci sono allarmi da segnalare")
    return
  end

  display_text = "Allarmi scattati:\n\n"

  for i,v in pairs(alerts) do

    for ii,vv in pairs(v) do
      display_text = display_text .. ii .. ": " .. vv .. "\n"
    end

    display_text = display_text .. "\n"
  end
  text = "Ecco a te l'elenco degli allarmi scattati:\n"

  if #alerts > 2 then 
    if (send_text_telegram(display_text) == 0) then
      google.send("Ti ho inviato le informazioni su Telegram")
    else
      google.send("Ops, invio su Telegram fallito. Sicuro di aver impostato token e chat id?")
    end

  else
    google.send(text, display_text)
  end
end

function handler_alert()
  local alert_num, severity = net_state.check_num_alerts_and_severity()
  local alert_text = ""

  if alert_num > 0 then
    alert_text = alert_num .. " allarmi scattati, di cui "

    for i,v in pairs(severity) do
      if v > 0 then  alert_text = alert_text .. v .. " " .. i .. ", " end
    end

    alert_text = string.sub(alert_text,1,-2)
    alert_text = string.sub(alert_text,1,-2)
    alert_text = alert_text..". Vuoi più dettagli riguardo gli allarmi?"

    google.send(alert_text, alert_text, nil, { "Sì", "No"})
  else
    alert_text = "0 allarmi scattati\n"
    google.setContext(request["context"], 0, nil)
    google.send(alert_text, alert_text)
  end
end


function handler_tcp_dump()
  local duration_amount, duration_unit = request.parameters.duration.amount, request.parameters.duration.unit
  --possible values of "unit": s - min - h - day

  local seconds = 10
  local unit_text

  if      duration_unit == "s"    then 
    seconds = duration_amount 
    unit_text = "secondi"

  elseif  duration_unit == "min"  then 
    seconds = duration_amount * 60
    unit_text = "minuti"
    
  elseif  duration_unit == "h"    then 
    seconds = duration_amount * 60 * 60
    unit_text = "ore"

  elseif  duration_unit == "day"    then 
    seconds = duration_amount * 60 * 60 * 24
    unit_text = "giorni"
  end

  local text = "OK! Catturerò i pacchetti per ".. duration_amount.. " ".. unit_text
  local path = interface.captureToPcap(seconds )

  if path then
     io.write("\n"..os.date("%c")..": the pcap file is here: "..path.."\n") 
     ntop.setPref("ntopng.prefs.dump_file_path", path)

    if(interface.isCaptureRunning()) then
      ntop.msleep(1000)
    end
    
    interface.stopRunningCapture()
    --io.write("\n"..os.date("%c")..": pcap file: "..path.." capture finished".."\n") 
  
    text = text .. "\n\nQuando vorrai, per ricevere il file di cattura su Telegram ti basterà dire 'inviami il file su Telegram' "
    google.send(text)

  else 
    io.write("\nerror: pcap file not created\n")

    google.send("Mi dispiace, ma non riesco a lanciare la cattura!")
  end
end


function handler_send_dump()
  local chat_id, bot_token = ntop.getCache("ntopng.prefs.telegram_chat_id"), ntop.getCache("ntopng.prefs.telegram_bot_token")
  io.write("token & id:"..bot_token .." - " .. chat_id )

  local file_path = ntop.getPref("ntopng.prefs.dump_file_path")

  if file_path then 

    if interface.isCaptureRunning() then
       interface.stopRunningCapture() 
       io.write("\n"..os.date("%c")..": pcap file: "..path.." capture stopped".."\n") 
    end

    if (bot_token and chat_id) and (bot_token ~= "") and (chat_id ~= "") then 
      os.execute("curl -F chat_id="..chat_id.." -F document=@"..file_path.." https://api.telegram.org/bot"..bot_token.."/sendDocument ")
      google.send("File inviato!")
    else
      google.send("Ops, invio su Telegram fallito. Sicuro di aver impostato token e chat id?")
    end

  else
    google.send("Ops, non ho trovato il file. Sei sicuro di aver avviato la cattura prima?")
  end
end

---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------

request = google.receive()

if      request.intent_name == "Network_State" then response = handler_Network_State()

elseif  request.intent_name == "Communication_State" then response = handler_network_state_communication()
elseif  request.intent_name == "Communication_State - More_Info" then response = handler_network_state_communication_more_info()

elseif  request.intent_name == "Traffic_App_Info" then response = handler_traffic_app_info()
elseif  request.intent_name == "Traffic_App_Info-More_Info" then response = handler_traffic_app_info_more_info()

elseif  request.intent_name == "UpTime" then response = handler_upTime()

elseif  request.intent_name == "Devices_Info" then response = handler_device_info()
elseif  request.intent_name == "Devices_Info - yes" then response = handler_send_devices_info()--*

elseif  request.intent_name == "Suspicious_Activity" then response = handler_suspicious_activity()
elseif  request.intent_name == "Suspicious_Activity-More_Info" then response = handler_suspicious_activity_more_info()

elseif  request.intent_name == "Dangerous_communications_detected" then response = handler_dangerous_communications_detected()

elseif  request.intent_name == "ntopng" then response = handler_ntopng()

elseif  request.intent_name == "what_can_you_do" then response = handler_what_can_you_do()

elseif  request.intent_name == "dump" then response = handler_tcp_dump()
elseif  request.intent_name == "send_dump" then response = handler_send_dump()

elseif  request.intent_name == "alert" then response = handler_alert()
elseif  request.intent_name == "alert_more_info" then response = handler_alert_more_info()
elseif  request.intent_name == "alert_from_network_state" then response = handler_alert_more_info()


else response = google.send("Scusa, ma non ho capito bene, puoi ripetere?")
end
