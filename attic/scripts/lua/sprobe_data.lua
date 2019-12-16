--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

interface.select(ifname)
flows_stats = interface.getFlowsInfo()
flows_stats = flows_stats["flows"]

procs = {}
hosts = {}
names = {}

for key, value in pairs(flows_stats) do
   flow = flows_stats[key]

   c = flow["cli.ip"]
   s = flow["srv.ip"]
   if(flow["cli.host"] ~= nil) then 
      c_sym = flow["cli.host"] 
   else
      c_sym = getResolvedAddress(hostkey2hostinfo(flow["cli.ip"]))

      if(c_sym ~= flow["cli.ip"]) then
	 c_sym = c_sym .." (".. flow["cli.ip"] ..")"
      end
   end


   if(flow["srv.host"] ~= nil) then 
      s_sym = flow["srv.host"] 
   else
      s_sym = getResolvedAddress(hostkey2hostinfo(flow["srv.ip"]))
      
      if(s_sym ~= flow["srv.ip"]) then
	 s_sym = s_sym .." (".. flow["srv.ip"] .. ")" 
      end
   end

   names[c] = c_sym
   names[s] = s_sym

   if(flow["client_process"] ~= nil) then
      if(hosts[c] == nil) then hosts[c] = { } end
      name = flow["client_process"]["name"]
      if(hosts[c][name] == nil) then hosts[c][name] = { flow["client_process"], { }, { } } end
      hosts[c][name][2][s] = 1

      for f_key, f_value in pairs(flows_stats) do
	 s_flow = flows_stats[f_key]

	 if(s_flow["cli.host"] == s_flow["srv.host"]) then
	    if(s_flow["client_process"] == flow["client_process"]) then
	       if(s_flow["server_process"] ~= nil) then
		  hosts[c][name][3][s_flow["server_process"]["pid"]] = s_flow["server_process"]
	       end
	       elseif(s_flow["server_process"] == flow["client_process"]) then
	       if(s_flow["client_process"] ~= nil) then
		  hosts[c][name][3][s_flow["client_process"]["pid"]] = s_flow["client_process"]
	       end
	    end
	 end
      end
   end

   if(flow["server_process"] ~= nil) then
      if(hosts[s] == nil) then hosts[s] = { } end
      name = flow["server_process"]["name"]
      if(hosts[s][name] == nil) then hosts[s][name] = { flow["server_process"], { }, { } } end
      hosts[s][name][2][c] = 1

      for f_key, f_value in pairs(flows_stats) do
	 s_flow = flows_stats[f_key]

	 if(s_flow["cli.host"] == s_flow["srv.host"]) then
	    if(s_flow["client_process"] == flow["server_process"]) then
	       if(s_flow["server_process"] ~= nil) then
		  hosts[s][name][3][s_flow["server_process"]["pid"]] = s_flow["server_process"]
	       end
	       elseif(s_flow["server_process"] == flow["server_process"]) then
	       if(s_flow["client_process"] ~= nil) then
		  hosts[s][name][3][s_flow["client_process"]["pid"]] = s_flow["client_process"]
	       end
	    end
	 end
      end

   end
end

n = 0

print [[
{
 "name": "",
 "children": [ ]]

for key, value in pairs(hosts) do
   if(n > 0) then print(",") end

    print('\n\t{ "name": "'..names[key]..'", "type": "host", "link": "'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='..key ..'&page=flows", "children": [')

    m = 0
    for k, _v in pairs(value) do
       if(m > 0) then print(",") end
       m = m + 1
       v = _v[1]
       -- Process
       link = ntop.getHttpPrefix().."/lua/get_process_info.lua?pid="..v["pid"].."&pid_name="..k.."&host=".. key .."&page=Flows"
       print('\n\t\t{ "name": "'..k..' (pid '.. v["pid"]..')", "link": "'.. link ..'", "type": "proc", "children": [ ')
       o = 0
       for peer,_ in pairs(_v[2]) do
	  if(peer ~= key) then
	     if(o > 0) then print(",") end
	     o = o + 1
	     link = ntop.getHttpPrefix().."/lua/host_details.lua?host="..peer .."&page=flows"
	     print('\n\t\t\t{ "name": "'..names[peer]..'", "link": "'.. link ..'", "type": "host", "children": [ ] } ')
	  end
       end

       for pid,p_val in pairs(_v[3]) do
	  if(pid ~= key) then
	     if(o > 0) then print(",") end
	     o = o + 1
	     link = ntop.getHttpPrefix().."/lua/host_details.lua?host="..pid .."&page=flows"
	     link = ntop.getHttpPrefix().."/lua/get_process_info.lua?pid="..pid.."&pid_name="..k.."&host=".. key .."&page=Flows"
	     print('\n\t\t\t{ "name": "'..p_val["name"]..' (pid '.. pid..')", "link": "'.. link ..'", "type": "proc", "children": [ ] } ')
	  end
       end

       print('\n\t\t] }')
    end

    print('\n\t] }')
   n = n + 1
end



print("\n]\n}\n")


