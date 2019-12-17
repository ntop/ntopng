--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')
local debug = false
-- setTraceLevel(TRACE_DEBUG) -- Debug mode

-- Output parameters
mode = _GET["procstats_mode"]

-- Table parameters
currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]
host        = _GET["host"]
port        = _GET["port"]
application = _GET["application"]

-- System host parameters
hosts = _GET["hosts"]
user = _GET["username"]
pid = tonumber(_GET["pid"])
name = _GET["pid_name"]
process_sourceId = 0

if (name ~= nil) then
  info = split(name,"@")
  if (info[1] ~= nil) then name = info[1]           end
  if (info[2] ~= nil) then process_sourceId = tonumber(info[2])end
end

if(mode == nil) then
   mode = "table"
end
if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Mode: "..mode.."\n") end
if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
end

if(port ~= nil) then port = tonumber(port) end

if(sortOrder == nil) then
   sortOrder = "asc"
end

interface.select(ifname)
local flows_stats = interface.getFlowsInfo()
local total = flows_stats["numFlows"]
flows_stats = flows_stats["flows"]

if (mode == "table") then
  print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
  to_skip = (currentPage-1) * perPage
end


processes = {}
vals = {}
num = 0

for _key, value in ipairs(flows_stats) do
  p = flows_stats[_key]
  process = 1 
  client_process = 1
  server_process = 1

  if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"===============================\n")end
  ---------------- PID ----------------
   if(pid ~= nil) then
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"Pid:"..pid.."\n")end
    if (p["client_process"] ~= nil) then 
      if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"Client pid:"..p["client_process"]["pid"].."\n") end
      if ((p["client_process"]["pid"] ~= pid)) then 
        process = 0
      end
      if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"ClientProcess -\t"..process.."\n")end
    end
    if (p["server_process"] ~= nil) then 
      if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"Server pid:"..p["server_process"]["pid"].."\n") end
      if ((p["server_process"]["pid"] ~= pid)) then 
        process = 0
      end
      if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"ServerProcess -\t"..process.."\n")end
    end
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"Pid -\t"..process.."\n")end
   end
   
  ---------------- NAME ----------------
   if(name ~= nil) then
    
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"url:"..process_sourceId.."vlan:"..p["vlan"].."\n") end
    if (process_sourceId == p["vlan"]) then

      if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"Name:"..name.."\n")end
      if (p["client_process"] ~= nil) then 
        if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"Client name:"..p["client_process"]["name"].."\n") end

        if ((p["client_process"]["name"] ~= name)) then 
          client_process = 0
        end
        if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"ClientProcess -\t"..client_process.."\n")end
    
      end
      if (p["server_process"] ~= nil) then 
        if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"Server name:"..p["server_process"]["name"].."\n") end

        if ((p["server_process"]["name"] ~= name)) then 
          server_process = 0
        end
        if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"ServerProcess -\t"..server_process.."\n")end
    
      end
      if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"name -\t"..process.."\n")end
    else
      client_process = 0 
      server_process = 0
    end
   end
   

  ---------------- HOST ----------------
  if((host ~= nil) and (p["cli.ip"] ~= host) and (p["srv.ip"] ~= host)) then
    process = 0
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"host -\t"..process.."\n")end
  end


  if (process == 1) then

    if((p["client_process"] ~= nil) and (client_process == 1) )then 
      k = p["client_process"]
      key = k["name"] -- .."@"..p["vlan"]

      if(processes[key] == nil) then
    processes[key] = { }
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"INIT: Client process: "..key.." initialize with value: "..(p["cli2srv.bytes"] + p["srv2cli.bytes"]).." \n")end
    -- Flow information
    processes[key]["bytes_sent"] = p["cli2srv.bytes"]
    processes[key]["bytes_rcvd"] = p["srv2cli.bytes"]
    processes[key]["duration"] = p["duration"]
    processes[key]["count"] = 1
    -- Process information
    processes[key]["name"] = k["name"]
    processes[key]["actual_memory"] = p["client_process"]["actual_memory"]
    processes[key]["average_cpu_load"] = p["client_process"]["average_cpu_load"]
    processes[key]["vlan"] = p["vlan"]
      else
    -- Flow information
    processes[key]["duration"] = math.max(processes[key]["duration"], p["duration"])
    processes[key]["bytes_sent"] = processes[key]["bytes_sent"] + p["cli2srv.bytes"]
    processes[key]["bytes_rcvd"] = processes[key]["bytes_rcvd"] + p["srv2cli.bytes"]
    processes[key]["count"] = processes[key]["count"] + 1
    -- Process information
    processes[key]["actual_memory"] = processes[key]["actual_memory"] + p["client_process"]["actual_memory"]
    processes[key]["average_cpu_load"] = processes[key]["average_cpu_load"] + p["client_process"]["average_cpu_load"]
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"UPDATE: Client process: "..key.." update value to: "..(processes[key]["bytes_sent"] + processes[key]["bytes_rcvd"]).." \n")end
      end
    end

    if((p["server_process"] ~= nil) and (server_process == 1) )then 
      k = p["server_process"]
      key = k["name"] -- .."@"..p["vlan"]

      if(processes[key] == nil) then
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"INIT: Server process: "..key.." initialize with value: "..(p["cli2srv.bytes"] + p["srv2cli.bytes"]).." \n")end
    processes[key] = { }
    -- Flow information
    processes[key]["bytes_sent"] = p["srv2cli.bytes"]
    processes[key]["bytes_rcvd"]  = p["cli2srv.bytes"]
    processes[key]["duration"] = p["duration"]
    processes[key]["count"] = 1
    -- Process information
    processes[key]["name"] = k["name"]
    processes[key]["actual_memory"] = p["server_process"]["actual_memory"]
    processes[key]["average_cpu_load"] = p["server_process"]["average_cpu_load"]
    processes[key]["vlan"] = p["vlan"]
      else
    -- Flow information
    processes[key]["duration"] = math.max(processes[key]["duration"], p["duration"])
    processes[key]["bytes_sent"] = processes[key]["bytes_sent"] + p["srv2cli.bytes"]
    processes[key]["bytes_rcvd"] = processes[key]["bytes_rcvd"] + p["cli2srv.bytes"]
    processes[key]["count"] = processes[key]["count"] + 1
    -- Process information
    processes[key]["actual_memory"] = processes[key]["actual_memory"] + p["server_process"]["actual_memory"]
    processes[key]["average_cpu_load"] = processes[key]["average_cpu_load"] + p["server_process"]["average_cpu_load"]
    if (debug) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"UPDATE: Server process: "..key.." update value to: "..(processes[key]["bytes_sent"] + processes[key]["bytes_rcvd"]).." \n")end
      end
    end
  end
end


-- Aggregated value

for key, value in pairs(processes) do
  -- Process information
  processes[key]["actual_memory"] = (processes[key]["actual_memory"] / processes[key]["count"])
  processes[key]["average_cpu_load"] = (processes[key]["average_cpu_load"] / processes[key]["count"])

end

-- Sorting table

for key, value in pairs(processes) do
      -- postfix is used to create a unique key otherwise entries with the same key will disappear
      num = num + 1
      postfix = string.format("0.%04u", num)
      if(sortColumn == "column_name") then
   vkey = key
   elseif(sortColumn == "column_vlan") then
   vkey = processes[key]["vlan"]+postfix
   elseif(sortColumn == "column_bytes_rcvd") then
   vkey = processes[key]["bytes_rcvd"]+postfix
   elseif(sortColumn == "column_bytes_sent") then
   vkey = processes[key]["bytes_sent"]+postfix
   elseif(sortColumn == "column_duration") then
   vkey = processes[key]["duration"]+postfix    
   elseif(sortColumn == "column_count") then
   vkey = processes[key]["count"]+postfix   
      else
   vkey = key
      end
      
      vals[vkey] = key
end

num = 0
table.sort(vals)

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end


-- Json output

if (mode == "table") then
  for _key, _value in pairsByKeys(vals, funct) do
     key = vals[_key]   
     value = processes[key]

     if(to_skip > 0) then
        to_skip = to_skip-1
     else
        if(num < perPage) then
     if(num > 0) then
        print ",\n"
     end
     srv_tooltip = ""
     cli_tooltip = ""

     print ("{ \"key\" : \"" .. key..'\"')
     print (", \"column_name\" : \"".."<A HREF='"..ntop.getHttpPrefix().."/lua/get_process_info.lua?pid_name=" .. key .. "'>".. value["name"] .. "</A>")

     print ("\", \"column_duration\" : \"" .. secondsToTime(value["duration"]))
     print ("\", \"column_count\" : \"" .. value["count"])
     print ("\", \"column_bytes_sent\" : \"" .. bytesToSize(value["bytes_sent"]) .. "")
     print ("\", \"column_bytes_rcvd\" : \"" .. bytesToSize(value["bytes_rcvd"]) .. "")
     print ("\", \"column_vlan\" : \"" .. value["vlan"] .. "")
     print ("\", \"bytes_sent\" : \"" .. value["bytes_sent"] .. "")
     print ("\", \"bytes_rcvd\" : \"" .. value["bytes_rcvd"] .. "")
     print ("\" }\n")
     num = num + 1
        end
     end

  end -- for


  print ("\n], \"perPage\" : " .. perPage .. ",\n")

  if(sortColumn == nil) then
     sortColumn = ""
  end

  if(sortOrder == nil) then
     sortOrder = ""
  end

  print ("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
  print ("\"totalRows\" : " .. total .. " \n}")

elseif (mode == "timeline") then

  print ("[\n")
  for _key, _value in pairsByKeys(vals, funct) do
     key = vals[_key]   
     value = processes[key]

     if (num > 0) then print(',\n') end

    print('{'..
      '\"name\":\"'           .. key                                                .. '\",' ..
      '\"label\":\"'          .. key                                                .. '\",' ..
      '\"value\":'            .. (value["bytes_sent"] + value["bytes_rcvd"])        .. ',' ..
      '\"actual_memory\":'    .. value["actual_memory"]                             .. ',' ..
	     '\"average_cpu_load\":' .. round(value["average_cpu_load"],2)                          ..
    '}')
    num = num + 1

  end
  print ("\n]")

end
