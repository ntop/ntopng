--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(_GET["id"])
-- ifstats = aggregateInterfaceStats(interface.getFlowsStatus())
ifstats = interface.getFlowsStatus()
--tprint(ifstats)

tcpFlowStats = ifstats

sum = tcpFlowStats["SYN"]+tcpFlowStats["Established"]+tcpFlowStats["RST"]+tcpFlowStats["FIN"]

print("[")

if(sum == 0) then
   print('{ "label": "No traffic yet", "value": 0 }\n')
else
   n = 0
   if(tcpFlowStats["Established"] > 0) then print [[ { "label": "Established", "value": ]] print(tcpFlowStats["Established"].."") print [[ } ]] n = 1 end
   if(tcpFlowStats["SYN"] > 0) then if(n > 0) then n = 0 print(",") end print [[ { "label": "SYN", "value": ]] print(tcpFlowStats["SYN"].."") print [[ } ]] n = 1 end
   if(tcpFlowStats["RST"] > 0) then if(n > 0) then n = 0 print(",") end print [[ { "label": "RST", "value": ]] print(tcpFlowStats["RST"].."") print [[ } ]] n = 1 end
   if(tcpFlowStats["FIN"] > 0) then if(n > 0) then n = 0 print(",") end print [[ { "label": "FIN", "value": ]] print(tcpFlowStats["FIN"].."") print [[ } ]] end
end


print("]")
