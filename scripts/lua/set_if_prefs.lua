--
-- (C) 2013-16 - ntop.org
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

print('<hr><h2>'..ifstats.name..' Preferences</H2></br>\n')

key = 'ntopng.prefs.'..ifname..'.name'

if(_GET["ifName"] ~= nil) then
   custom_name = tostring(_GET["ifName"])
   ntop.setCache(key, custom_name)
else
   custom_name = ntop.getCache(key)
end

key = 'ntopng.prefs.'..ifname..'.speed'

ifstats.name = tostring(ifstats.name)

-- Ask Redis for actual speed
ifSpeed = ntop.getCache(key)

if((_GET["ifSpeed"] ~= nil) and (string.len(_GET["ifSpeed"]) > 0)) then
   ifSpeed = _GET["ifSpeed"]
   
   if(ifSpeed ~= nil) then 
      ifSpeed = tonumber(ifSpeed) 
   end
   
   -- ifSpeed == nil assign the max value of speed
   if(ifSpeed == nil) then
      ifSpeed = ifstats.speed
   end
   
   -- set Redis cache for the speed to the associated interface
   ntop.setCache(key, tostring(ifSpeed))
elseif _GET["ifSpeed"] ~= nil and _GET["ifSpeed"] == "" then
   -- reset to the default detected value
   ntop.setCache(key, tostring(ifstats.speed))
   ifSpeed = ifstats.speed
else
   if((ifSpeed ~= nil) and (string.len(ifSpeed) > 0)) then
      ifSpeed = tonumber(ifSpeed)
   else
      -- ifSpeed == nil assign the max value of speed
      ifSpeed = ifstats.speed
   end
end

ifSpeed = math.floor(ifSpeed+0.5)

print [[<form class="form-horizontal" method="GET" >]]

print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[
	 <div class="container"> 
	 <div class="form-group">
	 
      <label class="control-label" for="ifSpeed">Interface Speed (Mbit) : </label>]]
print('<br /><input type="number" min="1" step="1" name="ifSpeed" id="ifSpeed" value="'..ifSpeed..'"/>')

print [[
      
      </div>
	 
	 <div class="form-group">
      <label class="control-label" for="ifName">Custom Interface Name: </label>

	 <br />
	 
	 <input type="text" name="ifName" id="IfName" value="]] print(custom_name) print [["/>
      
      </div>
	 	 
	 <div class="form-group">
	 <p></p>
	 <button type="submit" class="btn btn-primary">Save</button> <button class="btn btn-default" type="reset">Reset Form</button>
	 
	 </div>
	 </div>
	 </form>
	 
      ]]


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
