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
bytes = ifstats["localstats"]["bytes"]

sum = bytes["local2remote"]+bytes["local2local"]+bytes["remote2local"]+bytes["remote2remote"]
five = 0.05*sum
other = 0

print [[
[
]]

n = 0

if(bytes["local2remote"] > five) then print [[  { "label": "Local->Remote", "value": ]] print(bytes["local2remote"].."") print [[ } ]] n = n + 1 else other = other + bytes["local2remote"] end
if(bytes["local2local"] > five) then if(n > 0) then print(",") end print [[   { "label": "Local->Local", "value": ]] print(bytes["local2local"].."") print [[ } ]]  n = n + 1 else other = other + bytes["local2local"] end
if(bytes["remote2local"] > five) then if(n > 0) then print(",") end print [[   { "label": "Remote->Local", "value": ]] print(bytes["remote2local"].."") print [[ } ]]  n = n + 1 else other = other + bytes["remote2remote"] end
if(bytes["remote2remote"] > five) then if(n > 0) then print(",") end print [[   { "label": "Remote->Remote", "value": ]] print(bytes["remote2remote"].."") print [[ } ]]  n = n + 1 else other = other + bytes["remote2remote"] end

if(other > 0) then  if(n > 0) then print(",") end  print('{ "label": "Other", "value": '..other..' }\n') end

if(sum == 0) then print('{ "label": "No traffic yet", "value": 0 }\n') end
print [[
]
]]
