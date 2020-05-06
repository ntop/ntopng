--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local datasources_utils = require("datasources_utils")
local widgets_utils     = require("widgets_utils")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

local datasources = datasources_utils.get_all_sources()
local widgets     = widgets_utils.get_all_widgets()

-- Now report what datasources are in use

local ds_in_use = {}
for k,v in pairs(widgets) do
   if(ds_in_use[v.ds_hash] == nil) then
      ds_in_use[v.ds_hash] = {}
   end
   
   table.insert(ds_in_use[v.ds_hash], v.key)
end

for k,v in pairs(datasources) do
   if(ds_in_use[v.hash] ~= nil) then
      datasources[k].in_use = true
      datasources[k].widgets = ds_in_use[v.hash]
   else
      datasources[k].in_use = false
      datasources[k].widgets = {}
   end
end

print(json.encode(datasources))
