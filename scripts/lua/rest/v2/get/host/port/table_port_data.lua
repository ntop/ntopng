--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Imports
require "lua_utils"
local rest_utils = require "rest_utils"

-- Local variables

local ifid        = _GET["ifid"] or interface.getId()
local host_ip     = _GET["host"]
local host_vlan   = _GET["vlan"] or 0
local requested_proto = _GET["protocol"]
local mode        = _GET["mode"]

interface.select(tostring(ifid))

if isEmptyString(host_ip) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local host = interface.getHostInfo(host_ip, host_vlan)
local rsp = {}

if not host then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

-- ##################################

-- No used_ports when the host has no port information
local used_ports = host.used_ports or {}
local ports
if mode == "remote" then
  ports = used_ports.remote_contacted_ports or {}
else
  ports = used_ports.local_server_ports or {}
end

-- ##################################

for k, l7_proto in pairs(ports) do
  local res = split(k, ":")
  local protocol = res[1]
  local port = tonumber(res[2])

  if port and protocol then
    if(protocol == requested_proto) then
      rsp[#rsp + 1] = {
        port_info = {
          l7_proto = l7_proto,
          port = port
        }
      }
    end
  end
end

-- ##################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
