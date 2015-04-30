--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.select(ifname)
ifstats = interface.getStats()

print('<hr><h2>'..ifstats.description..' Preferences</H2></br>\n')

key = 'ntopng.prefs.'..ifname..'.name'
if(_GET["ifName"] ~= nil) then
   custom_name = tostring(_GET["ifName"])
   ntop.setCache(key, custom_name)
else
   custom_name = ntop.getCache(key)
end

key = 'ntopng.prefs.'..ifname..'.speed'
if(_GET["ifSpeed"] ~= nil) then
   ifSpeed = _GET["ifSpeed"]
   if(ifSpeed ~= nil) then ifSpeed = tonumber(ifSpeed) end
   if((ifSpeed == nil) or (ifSpeed > 10000)) then
      ifSpeed = 10000
   end
   
   ntop.setCache(key, tostring(ifSpeed))
else
   ifSpeed = ntop.getCache(key)

   if((ifSpeed ~= nil) and (ifSpeed ~= "")) then
      ifSpeed = tonumber(ifSpeed)  
   else
      ifSpeed = 1000
   end
end

ifSpeed = math.floor(ifSpeed+0.5)



print [[

<form class="form-horizontal" method="GET" >
   ]]

print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[
<div class="container"> 
<div class="form-group">
    <label class="control-label" for="ifSpeed">Interface Speed (Mbit):</label>
    
 <input type="number" min="1" max="10000" step="1" name="ifSpeed" id="IfSpeed" value="]] print(ifSpeed) print [["/>
    
</div>

<div class="form-group">
    <label class="control-label" for="ifName">Custom Name:</label>
   
 <input type="text" name="ifName" id="IfName" value="]] print(custom_name) print [["/>
   
</div>


<div class="form-group">

<button type="submit" class="btn btn-primary">Save</button> <button class="btn btn-default" type="reset">Reset Form</button>

</div>
</div>
</form>

]]



dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")