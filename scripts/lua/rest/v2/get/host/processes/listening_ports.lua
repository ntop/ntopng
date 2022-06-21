--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Retrieves all ntopng interfaces of a given host
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"host" : "192.168.1.1"}' http://localhost:3000/lua/rest/v1/get/host/interfaces.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}
local ip = _GET["host"] or ""
local vlan = _GET["vlan"] or ""

if isEmptyString(ip) and isEmptyString(vlan) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local host = interface.getHostInfo(ip, vlan)

for listening_type, data in pairs(host.listening_ports or {}) do
  for port, process_info in pairs(data) do
    local process = {}
    process["tcp_udp"] = listening_type
    process["port"] = port
    process["package"] = process_info["package"]
    process["process"] = process_info["process"]

    if table.len(process) > 0 then
      res[#res + 1] = process
    end
  end
end

rest_utils.answer(rc, res)
