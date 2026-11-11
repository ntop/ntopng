--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Ports of an active host (host details > Ports): the server ports it answered on and the server ports it contacted, as "<l4 proto>:<port>" -> application.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/host/used_ports.lua?ifid=0&host=192.168.1.1@0"
--

require "http_lint"
require "label_utils"
local rest_utils = require "rest_utils"

local ifid = _GET["ifid"]
local host_key = _GET["host"]

if isEmptyString(ifid) or isEmptyString(host_key) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local host_info = hostkey2hostinfo(host_key)
local h = interface.getHostInfo(host_info["host"], host_info["vlan"])

if h == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

local used = h.used_ports or {}

rest_utils.answer(rest_utils.consts.success.ok, {
   local_server_ports = used.local_server_ports or {},
   remote_contacted_ports = used.remote_contacted_ports or {},
})
