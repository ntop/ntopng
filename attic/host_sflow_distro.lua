--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local json = require ("dkjson")

sendHTTPContentTypeHeader('text/html')


local debug = false

-----------------------------------

function setAggregatedFlow(p_id,p_ip_address,p_value,p_what)
  if (what_array[p_id] == nil) then 
    what_array[p_id]  = {}
    what_array[p_id]["value"]  = 0
    what_array[p_id]["url"]  = url..p_what.."&host="..p_ip_address
  end

  if ((how_is_process == 1) or (how_is_latency == 1))then
    if ( what_array[p_id]["value"]  == 0) then
      what_array[p_id]["value"] = p_value
    end
  else
    what_array[p_id]["value"] = what_array[p_id]["value"] + p_value
  end
end

-----------------------------------

function getAggregationValue(flow,flow_key,type)
  l_how = 0;
  process_key = "client_process"
  bytes_key = "cli2srv.bytes"
  
  if (type == "server") then
    process_key = "server_process"
     bytes_key = "srv2cli.bytes"
  end
  
  if (how_is_process == 1) then
  
    l_how = flow[process_key][how]
  
  elseif (how_is_latency == 1) then
  
    flow_more_info = interface.findFlowByKey(flow_key)
    local info, pos, err = json.decode(flow_more_info["moreinfo.json"], 1, nil)
    for k,v in pairs(info) do
      if("Application latency (residual usec)" == getFlowKey(k)) then
        l_how = tonumber(handleCustomFlowField(k, v))
      end
    end
  
  else
  
    l_how = flow[bytes_key]
  
  end
  return l_how;
end

-----------------------------------

function setType(p_type)
  if((p_type == nil) or (p_type == "memory")) then
    how = "actual_memory"
    how_is_process = 1
  elseif (p_type == "bytes") then
    how = "bytes"
  elseif (p_type == "latency") then
    how_is_latency = 1
    how = "Application latency (residual usec)"
  end
  
  if (debug) then io.write("How:"..how.."\n"); end
end

-----------------------------------

function setMode(p_mode)
  if((p_mode == nil) or (p_mode == "user")) then
    what = "user_name"
    url = ntop.getHttpPrefix().."/lua/get_user_info.lua?username="
  elseif (p_mode == "process") then
    what = "name"
    url = ntop.getHttpPrefix().."/lua/get_process_info.lua?pid_name="
  end
  if (debug) then io.write("what:"..what..",url:"..url.."\n"); end
end

-----------------------------------

function setFilter(p_filter)
  if((p_filter == nil) or (p_filter == "All")) then
    filter_client = 1
    filter_server = 1
  elseif (p_filter == "Client") then
    filter_client = 1
  elseif (p_filter == "Server") then
    filter_server = 1
  end
  if (debug) then io.write("Client:"..filter_client..", Server:"..filter_server.."\n"); end
end


-----------------------------------

mode = _GET["sflowdistro_mode"] -- memory(actual-memory),bytes,latency
type = _GET["distr"] -- user,process(proc_name)
host = _GET["host"]
filter = _GET["sflow_filter"] -- all,client,server

interface.select(ifname)

if(host == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> This flow cannot be found (expired ?)</div>")
else
  flows_stats = interface.getFlowsInfo()
  flows_stats = flows_stats["flows"] 
  
  -- Default values
  filter_client = 0
  filter_server = 0
  how_is_process = 0
  how_is_latency = 0
  url = ""
  what = ""
  how = ""

  -- Process parameter
  setType(type)
  setMode(mode)
  setFilter(filter)
  
  -- scan flows
  tot = 0
  what_array = {}
  num = 0
  
  for key, value in pairs(flows_stats) do
    client_process = 0
    server_process = 0
    flow = flows_stats[key]
    if (debug) then io.write("Client:"..flow["cli.ip"]..",Server:"..flow["srv.ip"].."\n"); end
    
    if((filter_client == 1) and (flow["cli.ip"] == host) and (flow.client_process ~= nil))then
      client_process = 1
    end

    if((filter_server == 1) and (flow["srv.ip"] == host) and (flow.server_process ~= nil))then
      server_process = 1
    end

    
    if ((client_process == 1))then
      current_what = flow["client_process"][what].." (client)"
      
      value = getAggregationValue(flow,key,"client")
      setAggregatedFlow(current_what,flow["cli.ip"],value,flow["client_process"][what])
      
      if (debug) then io.write("Find client_process:"..current_what..", Value:"..value..", Process:"..flow["client_process"]["name"]..",Pid:"..flow["client_process"]["pid"]..",Url:"..what_array[current_what]["url"].."\n"); end
    end
    
    if(server_process == 1) then
      current_what = flow["server_process"][what].." (server)"
      
      value = getAggregationValue(flow,key,"server")
      setAggregatedFlow(current_what,flow["srv.ip"],value,flow["server_process"][what])
      
      if (debug) then io.write("Find server_process:"..current_what..", Value:"..value..", Process:"..flow["server_process"]["name"]..",Pid:"..flow["server_process"]["pid"]..",Url:"..what_array[current_what]["url"].."\n"); end

    end
  end
  
  -- Print json
  print "[\n"
  num = 0
  s = 0

  tot = 0
  for key, value in pairs(what_array) do
     value = what_array[key]["value"]
     tot = tot + value
  end

  other = 0;
  thr = (tot * 5) / 100
  
  for key, value in pairs(what_array) do
     value = what_array[key]["value"]
     -- io.write("Val: "..value.."\n")
     if(value >= thr) then
	if(num > 0) then
	   print ",\n"
	end
	label = key
	url = what_array[key]["url"]
	print("\t { \"label\": \"" .. label .."\", \"value\": ".. value ..", \"url\": \"" .. url.."\" }") 
	num = num + 1
	s = s + value
     end
  end

  if(tot > s) then
    print(",\t { \"label\": \"Other\", \"value\": ".. (tot-s) .." }") 
  end

  print "\n]"

end
