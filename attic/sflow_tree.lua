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

function setAggregatedFlow(pid,father_pid,father_name,p_what,p_how,type)
 if (aggregated_flows[pid] == nil) then
    aggregated_flows[pid] = {};
    aggregated_flows[pid]["pid"] = pid
    aggregated_flows[pid]["father_pid"] = father_pid
    aggregated_flows[pid]["father_name"] = father_name
    aggregated_flows[pid]["type"] = type
    aggregated_flows[pid][what] = p_what
    aggregated_flows[pid][how] = p_how 
  else
    -- Aggregate values
    if ((how_is_process ~= 1) and (how_is_latency ~= 1))then
      aggregated_flows[pid][how] = aggregated_flows[pid][how] + p_how
    end 
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
  if((p_mode == nil) or (p_mode == "process")) then
    what = "name"
    url = ntop.getHttpPrefix().."/lua/get_process_info.lua?host="..host.."&pid="
  elseif (p_mode == "user") then -- TODO
    what = "user_name"
     url = ntop.getHttpPrefix().."/lua/get_user_info.lua?username="
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
  aggregated_flows = {}
  father_process = {}
  children_process = {}
  num = 0
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

  -- Scan flows
  for key, value in ipairs(flows_stats) do
    flow = flows_stats[key]
    process = 1

    if ((flow["cli.ip"] ~= host) and 
      (flow["srv.ip"] ~= host)) then 
      process = 0
    end

    if (process == 1) then

      if (filter_client == 1) and (flow["cli.ip"] == host) and (flow["client_process"] ~= nil) then 
        client_id = flow["client_process"]["pid"]

        client_how = getAggregationValue(flow,key,"client")
        setAggregatedFlow(client_id,flow["client_process"]["father_pid"],flow["client_process"]["father_name"],flow["client_process"][what],client_how,"client")
      end
        
      if (filter_server == 1) and (flow["srv.ip"] == host) and (flow["server_process"] ~= nil) then 
        server_id = flow["server_process"]["pid"]

        server_how = getAggregationValue(flow,key,"server")
        setAggregatedFlow(server_id,flow["server_process"]["father_pid"],flow["server_process"]["father_name"],flow["server_process"][what],server_how,"server")
      end

    end
  end 

  father_process = {}
  children_process = {}
  num = 0
  tot = 0
  for key, value in pairs(aggregated_flows) do
    flow = aggregated_flows[key]
    -- print("Pid:"..flow["pid"]..", Father Pid:"..flow["father_pid"]..", Father Name:"..flow["father_name"]..", Type:"..flow["type"]..", What:"..flow[what]..", How:"..flow[how].."\n")

    if(flow["pid"] == flow["father_pid"]) then
      if(father_process[flow["father_pid"]] == nil) then
        father_process[flow["father_pid"]] = {}
        father_process[flow["father_pid"]]["name"] = flow[what]
        father_process[flow["father_pid"]]["size"] = flow[how]
        father_process[flow["father_pid"]]["pid"] = flow["pid"]      
      else
        father_process[flow["father_pid"]]["size"] = father_process[flow["father_pid"]]["size"] + flow[how]
      end
      tot = tot + father_process[flow["father_pid"]]["size"]
    else
      if(father_process[flow["father_pid"]] == nil) then
        father_process[flow["father_pid"]] = {}
        father_process[flow["father_pid"]]["children"] = {}
        father_process[flow["father_pid"]]["children"][flow["pid"]] = {}
        father_process[flow["father_pid"]]["children"][flow["pid"]]["name"] = flow[what]
        father_process[flow["father_pid"]]["children"][flow["pid"]]["size"] = flow[how]
        father_process[flow["father_pid"]]["pid"] = flow["pid"]
        father_process[flow["father_pid"]]["size"] = flow[how]
        father_process[flow["father_pid"]]["name"] = flow["father_name"]
      else
        father_process[flow["father_pid"]]["children"][flow["pid"]] = {}
        father_process[flow["father_pid"]]["children"][flow["pid"]]["name"] = flow[what]
        father_process[flow["father_pid"]]["children"][flow["pid"]]["size"] = flow[how]
        father_process[flow["father_pid"]]["size"] = father_process[flow["father_pid"]]["size"] + flow[how]
    end
    tot = tot + father_process[flow["father_pid"]]["size"]

  end

  end

  if (debug) then 
    for key, size in pairs(father_process) do
      flow = father_process[key]
      io.write("Father => Name:"..flow["name"]..", size:"..flow["size"]..", pid:"..flow["pid"].."\n")
      if (flow["children"] ~= nil) then
        for key, size in pairs(flow["children"]) do
          children = flow["children"][key]
          io.write("Children => Name:"..children["name"]..", size:"..children["size"]..", pid:"..flow["pid"].."\n")
        end
      end
    end
  end


  print "{\n"
  num = 0
  s = 0
  print("\"name\": \"" .. what .."\", \"size\": ".. tot ..", \n\"children\": [\n") 

  for key, value in pairs(father_process) do
    flow = father_process[key]
    if(num > 0) then
     print ",\n"
    end
    if (flow["name"] == "") then
      if(debug) then io.write("Empty name\n") end
      flow["name"] = "Empty name"
    end
    print("\t { \"name\": \"" .. flow["name"] .."\", \"id\": " .. key ..", \"size\": ".. flow["size"]..",\"url\": \"" .. url..key.."\"") 
    
    children_num = 0
    if (flow["children"] ~= nil) then
      print( ", \n\t\"children\": \n\t\t[\n")
      for k,v in pairs(flow["children"]) do
        children = flow["children"][k]
        if(children_num > 0) then
          print ",\n"
        end
        if (children["name"] == "") then
          if(debug) then io.write("Empty name children\n") end
          children["name"] = "Empty name"
        end
        print("\t\t { \"name\": \"" .. children["name"] .."\", \"id\": ".. k ..", \"size\": ".. children["size"] ..",\"url\": \"" .. url..k.."\" }") 
      
        children_num = children_num + 1
      
      end
      print ("\n\t\t]\n")
    end

    print ("\t}")
    
   num = num + 1

  end


  print "]\n}"

end -- if host error
