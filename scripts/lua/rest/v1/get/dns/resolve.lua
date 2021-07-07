--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local rest_utils = require("rest_utils")

--
-- Resolve a name
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"hostname" : "www.google.com"}' http://localhost:3000/lua/rest/v1/get/dns/resolve.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local hostname = _GET["hostname"]

if isEmptyString(hostname) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

if string.find(hostname, '://') then
   -- Looks like an URI, strip the scheme
   local uri_info = string.split(hostname, "://")
   if #uri_info == 2 then
      hostname = uri_info[2]
   end
end

if string.find(hostname, ':') then
   local host_port_info = string.split(hostname, ":")
   if #host_port_info == 2 then
      -- Looks like host:port, strip the port
      hostname = host_port_info[1]
   end
end

local resolved = ntop.resolveHost(hostname, true --[[ IPv4 --]])
if not resolved then
   resolved = ntop.resolveHost(hostname, false --[[ IPv6 --]])
end

if not resolved then
   rest_utils.answer(rest_utils.consts.err.resolution_failed)
   return
end

res = resolved

rest_utils.answer(rc, res)
