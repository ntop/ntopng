--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

interface.select(ifname)
hosts_stats = interface.getHostsInfo()
hosts_stats = hosts_stats["hosts"]

print [[
{
 "name": "flare",
 "children": [
  {
   "name": "analytics",
   "children": [
    {
     "name": "Local Hosts",
     "children": [
  ]]

tot = 0
for key, value in pairs(hosts_stats) do
   tot = tot +  hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"]
end
threshold = tot/40

other = 0
num = 0
for key, value in pairs(hosts_stats) do
   val = hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"]

   if(val > threshold) then

   if(num > 0) then print(",\n") else print("\n") end
   res = getResolvedAddress(hostkey2hostinfo(key))

   --if(res == nil) then res = "AAA" end
   print("{ \"name\": \"" .. res .. "\", \"size\": " .. (hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"]).. "} ")
   num = num + 1

else
   other = other + val
end
end


print [[

]
}
]]

if(other > 0) then
print [[,
  {
   "name": "Remote Hosts",
   "children": [
]]

print("{ \"name\": \"Other Hosts\", \"size\": " .. other .. "} ")

print [[
   ]
}
]]
end

print [[
]
}
]
}

]]
