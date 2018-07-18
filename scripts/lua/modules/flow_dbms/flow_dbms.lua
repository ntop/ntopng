--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/flow_dbms/drivers/?.lua;" .. package.path
local flow_dbms = {}
local driver

local available_tops = {"host", "src_host", "dst_host",
			"port", "src_port", "dst_port",
			"conversations"}

local function checkTop(what_k)
   for _, k in pairs(available_tops) do
      if k == what_k then return true end
   end

   return false
end

function flow_dbms:new()
   if ntop.getPrefs().is_dump_flows_to_mysql_enabled == true then
      driver = require("mysql"):new()
   else --[[ if nindex is enabled... --]]
   end

   local obj = {
      driver = driver
   }

   setmetatable(obj, self)
   self.__index = self

   return obj
end

function flow_dbms:queryTopk(ifid, what_k, filter)
   if not driver then
      return {} -- TODO: handle error
   end

   if not checkTop(what_k) then
      return {} -- TODO: handle error
   end

   return driver:topk(ifid, what_k, filter)
end

return flow_dbms
