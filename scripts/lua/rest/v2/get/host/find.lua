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

local query = _GET["query"]
local hosts_only = _GET["hosts_only"]
local ifid = _GET["ifid"] or interface.getId()

local rc = rest_utils.consts.success.ok

local search_all_interfaces = (ntop.getPref("ntopng.prefs.search_in_all_interfaces") == '1')

local results = {}

if not isEmptyString(query) then
   -- clean trailing spaces
   query = trimString(query)
   -- remove any decorator from string end
   -- this is done because to the result we append additional
   -- information that the original string doesn't have
   -- example: 'Consglio nazionale della Sicurezza' doesn't contain
   -- the substring 'Consiglio Nazionale dei Ministri [xxxx]'
   query = query:gsub("% %[.*%]*", "")
end

if not isEmptyString(query) then
   -- Lookup
   if search_all_interfaces then
      results = find_utils.find_on_any_interface(query, hosts_only)
   else
      results = find_utils.find(query, hosts_only, tonumber(ifid))
   end
end

local data = {
   -- interface = ifname,
   results = results,
}

rest_utils.answer(rc, data)

