--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)

mode = _GET["direction"]
type = _GET["distr"]
host_info = url2hostinfo(_GET)
host = interface.getHostInfo(host_info["host"],host_info["vlan"])


if(host == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> This flow cannot be found (expired ?)</div>")
else

if((type == nil) or (type == "size")) then
  
   if((mode == nil) or (mode == "sent")) then
     
      what = host["pktStats.sent"]
      
   else
     
      what = host["pktStats.recv"]
   end
end

tot = 0
for key, value in pairs(what) do
   tot = tot + value
end

threshold = (5 * tot) / 100

print "[\n"
num = 0
s = 0
for key, value in pairs(what) do
   if(value > threshold) then
      if(num > 0) then
	 print ",\n"
      end
   
      print("\t { \"label\": \"" .. key .."\", \"value\": ".. value .." }") 
      num = num + 1
      s = s + value
   end
end

if(tot > s) then
   print(",\t { \"label\": \"Other\", \"value\": ".. (tot-s) .." }") 
end


print "\n]"

end
