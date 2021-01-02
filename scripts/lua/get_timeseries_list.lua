--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local ts_utils = require "ts_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('text/json')

local schemas = ts_utils.getLoadedSchemas() 

local families = {}

for k,v in pairs(schemas) do
   if(type(v) == "table") then   
      local s = split(k, ":")
      if((s ~= nil) and (s[1] ~= nil)) then
	 local tags = {}
	 local metrics = {}
	 
	 if(families[s[1]] == nil) then
	    families[s[1]] = {}
	 end

	 for t,_ in pairs(v.tags)    do table.insert(tags, t) end
	 for m,_ in pairs(v.metrics) do table.insert(metrics, m) end

	 if(#metrics > 0) then
	    table.insert(families[s[1]], { schema=k, tags=tags, metrics=metrics })
	 end
      end
   end
end

print(json.encode(families))
