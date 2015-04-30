--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

flow_key = _GET["flow_key"]
if(flow_key == nil) then
 flow = nil
else
 interface.select(ifname)
 flow = interface.findFlowByKey(tonumber(flow_key))
end

throughput_type = getThroughputType()

sendHTTPHeader('text/html; charset=iso-8859-1')
--sendHTTPHeader('application/json')

if(flow == nil) then
 print('{}')
else

 diff0 = os.time()-flow["seen.first"]
 diff = os.time()-flow["seen.last"]
   -- Default values
   thpt = 0
   thpt_display = bitsToSize(0)
   if (throughput_type == "bps") then
    thpt = 8*flow["throughput_bps"]
    thpt_display = bitsToSize(thpt)
    top_thpt_display = bitsToSize(8*flow["top_throughput_bps"])
    
    elseif (throughput_type == "pps") then
      thpt = flow["throughput_pps"]
      thpt_display = pktsToSize(thpt)
      top_thpt_display = pktsToSize(flow["top_throughput_pps"])
    end
    print('{ ' .. '"seen.last": "'.. formatEpoch(flow["seen.last"]) .. ' ['.. secondsToTime(diff) .. ' ago]", ' 
    .. '"seen.first": "'.. formatEpoch(flow["seen.first"]) .. ' ['.. secondsToTime(diff0) .. ' ago]"' 
    .. ', "bytes": ' .. flow["bytes"] .. ', "cli2srv.packets": ' .. flow["cli2srv.packets"] .. ', "srv2cli.packets": ' .. flow["srv2cli.packets"] .. ', "cli2srv.bytes": ' .. flow["cli2srv.bytes"] .. ', "srv2cli.bytes": ' .. flow["srv2cli.bytes"].. ', "throughput": "' .. thpt_display..'", "top_throughput_display": "'.. top_thpt_display ..'", "throughput_raw": ' .. thpt)

    if(flow["proto.l4"] == "TCP") then
       print(', "c2sOOO":'.. flow["cli2srv.out_of_order"] )
       print(', "c2slost":'..flow["cli2srv.lost"] )
       print(', "c2sretr":'..flow["cli2srv.retransmissions"] )
       print(', "s2cOOO":'.. flow["srv2cli.out_of_order"] )
       print(', "s2clost":'..flow["srv2cli.lost"] )
       print(', "s2cretr":'..flow["srv2cli.retransmissions"] )
    end

    -- Processes information
    show_processes = false
    if ((flow.client_process ~= nil) or (flow.server_process ~= nil) )then show_processes= true end
    
    if (show_processes)then print (', "processes": {') end

    if(flow.client_process ~= nil) then

      proc = flow.client_process
      print ('"'..proc.pid..'": {')
     
      if(proc.actual_memory > 0) then
        -- average_cpu_load
        print('"average_cpu_load": "')
	load = round(proc.average_cpu_load, 2)
        if(proc.average_cpu_load < 33) then
          if(proc.average_cpu_load == 0) then proc.average_cpu_load = "< 1" end
          print("<font color=green>"..load.." %</font>")
        elseif(proc.average_cpu_load < 66) then
          print("<font color=orange><b>"..load.." %</b></font>")
        else
          print("<font color=red><b>"..load.." %</b></font>")
        end
        print('"')
        -- memory
        print(', "memory": "'.. bytesToSize(proc.actual_memory) .. " / ".. bytesToSize(proc.peak_memory) .. " [" .. round((proc.actual_memory*100)/proc.peak_memory, 1) ..'%]"')
        -- page faults
        print(', "page_faults": ')
        if(proc.num_vm_page_faults > 0) then
          print('"<font color=red><b>'..proc.num_vm_page_faults..'</b></font>"')
        else
          print('"<font color=green><b>'..proc.num_vm_page_faults..'</b></font>"')
        end
      end

      print ('}')
    end

    if(flow.server_process ~= nil) then
      if (flow.client_process ~= nil) then print (',') end

      proc = flow.server_process
      print ('"'..proc.pid..'": {')

      if(proc.actual_memory > 0) then
        -- average_cpu_load
        load = round(proc.average_cpu_load, 2)
        print('"average_cpu_load": "')
        if(proc.average_cpu_load < 33) then
          if(proc.average_cpu_load == 0) then proc.average_cpu_load = "< 1" end
          print("<font color=green>"..load.." %</font>")
        elseif(proc.average_cpu_load < 66) then
          print("<font color=orange><b>"..load.." %</b></font>")
        else
          print("<font color=red><b>"..load.." %</b></font>")
        end
        print('"')

        print(', "memory": "'.. bytesToSize(proc.actual_memory) .. " / ".. bytesToSize(proc.peak_memory) .. " [" .. round((proc.actual_memory*100)/proc.peak_memory, 1) ..'%]"')
        
        print(', "page_faults": ')
        if(proc.num_vm_page_faults > 0) then
          print('"<font color=red><b>'..proc.num_vm_page_faults..'</b></font>"')
        else
          print('"<font color=green><b>'..proc.num_vm_page_faults..'</b></font>"')
        end
      end

      print ('}')
    end

    if (show_processes)then print ('}') end


  print (' }\n')
end
