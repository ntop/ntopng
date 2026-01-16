--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local find_utils = require "find_utils"

local rest_utils = require("rest_utils")

--
-- Read information about a host
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "query" : "192.168.1.1"}' http://localhost:3000/lua/rest/v2/get/host/find.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

if not isEmptyString(_GET["ifid"]) then
   interface.select(_GET["ifid"])
else
   interface.select(ifname)
end

local query = _GET["query"]
local hosts_only = _GET["hosts_only"]

local ifid = interface.getId()

if (isEmptyString(query)) then
   query = ""
else
   -- clean trailing spaces
   query = trimString(query)
   -- remove any decorator from string end
   -- this is done because to the result we append additional
   -- information that the original string doesn't have
   -- example: 'Consglio nazionale della Sicurezza' doesn't contain
   -- the substring 'Consiglio Nazionale dei Ministri [xxxx]'
   query = query:gsub("% %[.*%]*", "")
end

-- Empty query
if(isEmptyString(query)) then
   local data = {
      interface = ifname,
      results = {},
   }
   
   rest_utils.answer(rc, data)
   return
end

-- Lookup
local results = find_utils.find(query, hosts_only, ifid)

local data = {
   interface = ifname,
   results = results,
}

rest_utils.answer(rc, data)

