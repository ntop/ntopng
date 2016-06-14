--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(_GET["id"])
ifstats = aggregateInterfaceStats(interface.getStats())
tcpFlowStats = ifstats["tcpFlowStats"]

sum = tcpFlowStats["numSynFlows"]+tcpFlowStats["numEstablishedFlows"]+tcpFlowStats["numResetFlows"]+tcpFlowStats["numFinFlows"]

print("[")

if(sum == 0) then
   print('{ "label": "No traffic yet", "value": 0 }\n')
else
   print [[ { "label": "SYN", "value": ]] print(tcpFlowStats["numSynFlows"].."") print [[ }, ]]
   print [[ { "label": "Established", "value": ]] print(tcpFlowStats["numEstablishedFlows"].."") print [[ }, ]]
   print [[ { "label": "RST", "value": ]] print(tcpFlowStats["numResetFlows"].."") print [[ }, ]]
   print [[ { "label": "FIN", "value": ]] print(tcpFlowStats["numFinFlows"].."") print [[ } ]]
end


print("]")
