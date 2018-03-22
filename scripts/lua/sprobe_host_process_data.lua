--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

host_ip = _GET["host"]

interface.select(ifname)
flows_stats = interface.getFlowsInfo(host_ip)
flows_stats = flows_stats["flows"]

print("[")
n = 0

for key, value in pairs(flows_stats) do
   flow = flows_stats[key]
   
   if((host_ip ~= nil)
   and (flow["cli.ip"] ~= host_ip)
and (flow["srv.ip"] ~= host_ip)) then
      -- wrong
      elseif((flow["client_process"] ~= nil) or (flow["server_process"] ~= nil)) then

      if((flow["client_process"] ~= nil)
      and (flow["server_process"] ~= nil)) then
	 if(n > 0) then print(",") end
	 print('\n\t{"source": "'..flow["client_process"]["name"]..'", "source_type": "proc", "source_pid": '.. 
	       flow["client_process"]["pid"] ..', "source_name": "'.. flow["client_process"]["name"] ..'", "target": "'
	       ..flow["server_process"]["name"]..'", "target_type": "proc", "target_pid": '.. 
	       flow["server_process"]["pid"] ..', "target_name": "'.. flow["server_process"]["name"] ..'", "type": "proc2proc"}')
	 n = n + 1
      else
	 if((flow["cli.ip"] == host_ip) and (flow["srv.ip"] == host_ip)) then 
	    -- Skip
	 else 
	    if(n > 0) then print(",") end
	    	 n = n + 1
	    if(flow["client_process"] ~= nil) then
	       if(flow["cli.ip"] == host_ip) then
		  print('\n\t{"source": "'..flow["client_process"]["pid"]..'", "source_type": "proc", "source_pid": '.. flow["client_process"]["pid"] ..', "source_name": "'.. 
			flow["client_process"]["name"]..'", "target": "'..flow["srv.ip"]..'", "target_type": "host", "target_pid": -1, "target_name": "'
			.. getResolvedAddress(hostkey2hostinfo(flow["srv.ip"])) ..'", "type": "proc2host"}')
	       else
		  print('\n\t{"target": "'..flow["client_process"]["pid"]..'", "target_type": "proc", "target_pid": '.. flow["client_process"]["pid"] ..
			', "target_name": "'.. flow["client_process"]["name"].."@".. flow["srv.ip"] ..'", "source": "'..flow["cli.ip"]..
			'", "source_type": "host", "source_pid": -1, "source_name": "'.. getResolvedAddress(hostkey2hostinfo(flow["cli.ip"])) ..'", "type": "host2proc"}')
	       end
	       elseif(flow["server_process"] ~= nil) then
	       if(flow["srv.ip"] == host_ip) then
		  print('\n\t{"target": "'..flow["server_process"]["pid"]..'", "target_type": "proc", "target_pid": '.. flow["server_process"]["pid"] 
			..', "target_name": "'.. flow["server_process"]["name"]..'", "source": "'..flow["cli.ip"]..
			'", "source_type": "host", "source_pid": -1, "source_name": "'.. getResolvedAddress(hostkey2hostinfo(flow["cli.ip"])) ..'", "type": "proc2host"}')
	       else
		  print('\n\t{"target": "'..flow["server_process"]["pid"]..'", "target_type": "proc", "target_pid": '.. flow["server_process"]["pid"] ..
			', "target_name": "'.. flow["server_process"]["name"].."@".. flow["srv.ip"] ..'", "source": "'..flow["cli.ip"]..
			'", "source_type": "host", "source_pid": -1, "source_name": "'.. getResolvedAddress(hostkey2hostinfo(flow["cli.ip"])) ..'", "type": "host2proc"}')
	       end
	    end
	 end
      end
   end
end

print("\n]\n")

