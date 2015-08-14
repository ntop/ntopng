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

-- Ask for MAC speed
SpeedMax = getSpeedMax(ifstats.name)

--print speed
--io.write(">>speed_max = "..SpeedMax..'\n')

-- Ask Redis for actual speed
ifSpeed = ntop.getCache(key)

if(_GET["ifSpeed"] ~= nil) then
   
   ifSpeed = _GET["ifSpeed"]
   
   if(ifSpeed ~= nil) then 
      ifSpeed = tonumber(ifSpeed) 
   end
   
   -- ifSpeed == nil assign the max value of speed
   if(ifSpeed == nil) then
      ifSpeed = SpeedMax
   end
   
   -- set Redis cache for the speed to the associated interface
   ntop.setCache(key, tostring(ifSpeed))

else
   if(ifSpeed ~= nil) then
      ifSpeed = tonumber(ifSpeed)
   else
      -- ifSpeed == nil assign the max value of speed
      ifSpeed = SpeedMax
   end
end

ifSpeed = math.floor(ifSpeed+0.5)




print [[<form class="form-horizontal" method="GET" >]]

print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[
	 <div class="container"> 
	 <div class="form-group">
	 
      <label class="control-label" for="ifSpeed">Interface Speed (Mbit) : </label>]]
print('\t'.."Max Speed availlable = [ "..SpeedMax..' (Mbit) ]\n')
print [[
         <br />	 
	 <input type="number" min="1" max="SpeedMax" step="1" name="ifSpeed" id="ifSpeed" value="]] print(ifSpeed) print [["/>]]

print [[
      
      </div>
	 
	 <div class="form-group">
      <label class="control-label" for="ifName">Custom Name: </label>

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
