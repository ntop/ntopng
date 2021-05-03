--
-- (C) 2018 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
ignore_post_payload_parse = 1
require "lua_utils"
local alert_consts = require "alert_consts"

local network_state = {}
local if_stats = interface.getStats()

--------------------------------------------------------------------------------------------------------------

function network_state.getUpTime()
  return secondsToTime( ntop.getUpTime() )
end  

--return ndpi categoty table [ "category_name" = "bytes" ]
function network_state.check_ndpi_categories()
  local t = {} 
  
  for i,v in pairs(if_stats.ndpi_categories) do
     t[tostring(i)] = if_stats.ndpi_categories[i].bytes 
  end
  
  return t
end

--makes the sum of "i1" and "i2" for each ndpi proto
--return ndpi proto table [ "proto_name" = "i1 + i2" ]
function network_state.check_ndpi_table(i1, i2)
  local t, ndpi_stats = {}, interface.getActiveFlowsStats() 
  local j = 1
  for i,v in pairs( ndpi_stats.ndpi ) do

     t[j] = { tostring(i),  v[i1] }
     if (i2 ~= nil) then t[j][2] = t[j][2] +  v[i2] end
     j = j + 1
  end
  
  return t
end


function network_state.check_traffic_categories()
  local traffic = network_state.check_ndpi_categories()
  local tot = 1
  local res = {}

  for i,v in pairs(traffic) do
      tot = tot + v
  end

  for i,v in pairs(traffic) do
      table.insert( res, {name = i, perc = math.floor(( v / tot ) * 1000) / 10 } )
  end

  function compare(a, b) return a.perc > b.perc end

  table.sort( res, compare )

  return res
end

--return the name and percentage of the ndpi proto that has generated more traffic
function network_state.check_top_traffic_application_protocol_categories()
  local traffic = network_state.check_ndpi_categories()
  local name, max, perc, tot = "non specificato", 0, 0, 1

  for i,v in pairs(traffic) do
    tot = tot + v
    if max < v then 
       name, max = i, v
    end    
  end
  perc = math.floor(( max / tot ) * 100) 
  return name, perc
end


--return an array-table of all ndpi_proto_name and traffic percentage
function network_state.check_top_application_protocol()
  local t, tot = {}, 1
  local proto_app = network_state.check_ndpi_table("bytes.sent", "bytes.rcvd" )
  for i,v in pairs(proto_app) do tot = tot + v[2] end

  
  function compare(a,b) return a[2]>b[2] end
  table.sort(proto_app, compare)


  local c, res = 0, {}
  
  for i,v in pairs(proto_app) do

      local prc = math.floor( (v[2] / tot) * 100 )
      c = c + 1
      res[c] = { v[1] , prc }

  end
  return res
end

--return table with some interface stats
function network_state.check_ifstats_table()
  local t = {
    device_num = if_stats.stats.devices,
    flow_num = if_stats.stats.flows,
    host_num = if_stats.stats.hosts,
    total_bytes = if_stats.stats.bytes,
    local_host_num = if_stats.stats.local_hosts,
    device_num = if_stats.stats.devices
  }
  return t
end

function network_state.check_devices_type() 
  local discover = require "discover_utils" 
  local res= {}

  for i,v in pairs(interface.getMacDeviceTypes() ) do
    res[discover.devtype2string(i)] = v
  end 


  return res, if_stats.stats.devices
end

--return respectively: state of goodput, number of total flow, total number of bad goodput flow
function network_state.check_TCP_flow_goodput()
  local bad_gp_client, bad_gp_server, flow_tot, prbl = 0,0,0,0
  local seen, deadline = 0, os.time() + 3000
  local group_of = 5

  repeat
    hoinfo = interface.getHostsInfo(true, "column_", group_of)
    tot = hoinfo.numHosts


    for i,v in pairs( hoinfo["hosts"] ) do
      local afas, afac = hoinfo["hosts"][i]["active_flows.as_server"], hoinfo["hosts"][i]["active_flows.as_client"]
      local bgc, bgs = hoinfo["hosts"][i]["low_goodput_flows.as_client"], hoinfo["hosts"][i]["low_goodput_flows.as_server"]
  
      flow_tot = flow_tot + afac + afas
      bad_gp_client = bad_gp_client + bgc
      bad_gp_server = bad_gp_server + bgs
  
    end 
    

    seen = seen + group_of
  until (seen < tot) or (os.time() > deadline)

  local perc, state = 100 - math.floor( (bad_gp_client + bad_gp_server) / flow_tot) * 100 
  if perc > 90 then 
    state = "complessivamente ottima" 
  elseif perc > 80 then 
    state = "complessivamente buona"
  elseif perc > 70 then
    state = "complessivamente mediocre"
  else 
    state = "complessivamente bassa" 
  end

  return state, flow_tot, (bad_gp_client + bad_gp_server)
end

--return a table with tot traffic, remote/local percentage and pkt drop
function network_state.check_net_communication()

  local tot = if_stats.localstats.bytes.local2remote + if_stats.localstats.bytes.remote2local + 
            if_stats.localstats.bytes.remote2remote + if_stats.localstats.bytes.local2local
  local t = {
    total_traffic = tot,
    prc_remote2local_traffic = math.floor((if_stats.localstats.bytes.remote2local / tot) * 100),
    prc_local2remote_traffic = math.floor((if_stats.localstats.bytes.local2remote / tot) * 100),
    prc_pkt_drop = math.floor( (if_stats.tcpPacketStats.lost / if_stats.stats.packets) * 100000 ) / 1000, --TODO: assicurarsi che "if_stats.stats.packets" si riferisca ai pacchetti tcp
    num_pkt_drop = if_stats.tcpPacketStats.lost,
    num_tot_pkt = if_stats.stats.packets
  }
  return t
  
end

--return a table ["breed_name" = "perentage of that breed"], number of blacklisted active host and a flag to report Dangerous traffic
function network_state.check_bad_hosts_and_app()
  local blacklisted, danger_flag = 0, false
  local callback = require "callback_utils"

  local function mycallback( hostname, hoststats )
      if  hoststats.is_blacklisted then blacklisted = blacklisted + 1  end
  end
  callback.foreachHost(ifname, mycallback)

  local j, breeds, tot, bytes = 1, {}, 0, 0
  for i,v in pairs(if_stats["ndpi"]) do
    bytes = if_stats["ndpi"][i]["bytes.sent"] + if_stats["ndpi"][i]["bytes.rcvd"]
    breeds[j] ={ ["name"] = if_stats["ndpi"][i]["breed"], ["bytes"] = bytes  }
    tot = tot + bytes
    j = j + 1
  end

  local res = {}
  for i,v in ipairs(breeds) do 
    if res[ breeds[i]["name"] ] ~= nil then 
      res[breeds[i]["name"] ] = res[breeds[i]["name"] ] + breeds[i]["bytes"]
    else
      res[breeds[i]["name"] ] = breeds[i]["bytes"]
    end
  end

  for i,v in pairs(res) do 

    if i == "Dangerous" then danger_flag = true end

    res[i] = { perc = math.floor( (res[i] / tot) * 1000 ) / 10, bytes = v }
    
  end

  return res, blacklisted, danger_flag
end



function network_state.check_dangerous_traffic()
  local res= {}
  local tot_bytes = 0

  for i,v in pairs(if_stats["ndpi"]) do
    if v.breed == "Dangerous" then 

      tot_bytes = v["bytes.rcvd"] + v["bytes.sent"]
      v["total_bytes"] = tot_bytes 
      v["name"] = i
      table.insert( res, v )
    end
  end

  if #res > 0 then
    return res
  else 
    return nil 
  end
end


------------------------ALERTS----------------------------

local alert_utils = require "alert_utils"

function network_state.check_alerts()
  local engaged_alerts = alert_utils.getAlerts("engaged", alert_utils.getTabParameters(_GET, "engaged"))
  local past_alerts    = alert_utils.getAlerts("historical", alert_utils.getTabParameters(_GET, "historical"))
  local flow_alerts    = alert_utils.getAlerts("historical-flows", alert_utils.getTabParameters(_GET, "historical-flows"))

  return engaged_alerts, past_alerts, flow_alerts
end


function network_state.check_num_alerts_and_severity()
  local num_engaged_alerts  = alert_utils.getNumAlerts("engaged", alert_utils.getTabParameters(_GET, "engaged"))
  local num_past_alerts     = alert_utils.getNumAlerts("historical", alert_utils.getTabParameters(_GET, "historical"))
  local num_flow_alerts     = alert_utils.getNumAlerts("historical-flows", alert_utils.getTabParameters(_GET,"historical-flows"))
  local engaged_alerts      = alert_utils.getAlerts("engaged", alert_utils.getTabParameters(_GET, "engaged"))
  local past_alerts         = alert_utils.getAlerts("historical", alert_utils.getTabParameters(_GET, "historical"))
  local flow_alerts         = alert_utils.getAlerts("historical-flows", alert_utils.getTabParameters(_GET, "historical-flows"))

  local severity = {} --severity: (none,) info, warning, error
  local alert_num = num_engaged_alerts + num_past_alerts + num_flow_alerts

  local function severity_cont(alerts, severity_table )
    local severity_text = ""

    for i,v in pairs(alerts) do
      if v.alert_severity then 
        severity_text = alert_consts.alertSeverityLabel(v.alert_severity, true)
        severity_table[severity_text] = (severity_table[severity_text] or 0) + 1 
      end
    end
  end

  if alert_num > 0 then
    severity_cont(engaged_alerts, severity)
    severity_cont(   flow_alerts, severity)
    severity_cont(   past_alerts, severity)
  end

  return alert_num, severity
end

function network_state.alerts_details()
  local engaged_alerts, past_alerts, flow_alerts = network_state.check_alerts() 
  local tmp_alerts, alerts = {}, {}
  local limit= 3 --temporary limit, add effective selection criterion

  j = 0
  for i,v in pairs(engaged_alerts)  do
    if j < limit then 
       table.insert( tmp_alerts, v )
       j = j+1
    else break end
  end

  j = 0
  for i,v in pairs(flow_alerts)  do
    if j < limit then 
       table.insert( tmp_alerts, v )
       j = j+1
    else break end
  end

  j = 0
  for i,v in pairs(past_alerts)  do
    if j < limit then 
       table.insert( tmp_alerts, v )
       j = j+1
    else break end
  end

  local alert_type, rowid, t_stamp, srv_addr, srv_port, cli_addr, cli_port, severity, alert_json  

  for i,v in pairs(tmp_alerts) do 

    if v.alert_type       then alert_type = alert_consts.alertTypeLabel( v.alert_type, true )      else  alert_type      = "Sconosciuto" end
    if v.rowid            then rowid  =  v.rowid                                      else  rowid           = "Sconosciuto" end
    if v.alert_tstamp     then t_stamp =  os.date( "%c", tonumber(v.alert_tstamp))    else  t_stamp         = "Sconosciuto" end
    if v.srv_addr         then srv_addr = v.srv_addr                                  else  srv_addr        = "Sconosciuto" end
    if v.srv_port         then srv_port = v.srv_port                                  else  srv_port        = "Sconosciuto" end
    if v.cli_addr         then cli_addr = v.cli_addr                                  else  cli_addr        = "Sconosciuto" end
    if v.cli_port         then cli_port = v.cli_port                                  else  cli_port        = "Sconosciuto" end
    if v.alert_severity   then severity = alert_consts.alertSeverityLabel(v.alert_severity, true)  else  severity        = "Sconosciuto" end
    if v.alert_json       then alert_json = v.alert_json                              else  alert_json      = "Sconosciuto" end 
    
    local e = {
      ID            = rowid,
      Tipo          = alert_type,
      Scattato      = t_stamp,
      Pericolosita  = severity,
      IP_Server     = srv_addr,
      Porta_Server  = srv_port,
      IP_Client     = cli_addr,
      Porta_Client  = cli_port,
      JSON_info     = alert_json
    }

    table.insert( alerts, e )
  end

  if #alerts > 0 then 
    return alerts
  else
    return nil
  end

end
  
------------------------------------------------------


return network_state
