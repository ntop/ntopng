--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- #################################
-- Imports
require "lua_utils"
local rest_utils = require("rest_utils")

-- #################################

-- Format the hosts info
local ifid = _GET["ifid"]
local cli_or_srv = _GET["clisrv"]
local host_info = url2hostinfo(_GET)
local host_key = hostinfo2hostkey(host_info)
local res = {}

local host_ports = {}

-- Error! no param to get ports, it's not correct!
if isEmptyString(host_key) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

-- #################################

-- Search the Host in all Intefaces!
for _, iface in pairs(interface.getIfNames()) do
    interface.select(iface)
    local host = interface.getHostInfo(host_info["host"], host_info["vlan"])
    
    -- Host found, search for the server ports
    if host then
        -- Aggregate the informations in a single ports table
        for port, proto in pairs(host.used_ports.local_server_ports or {}) do
            local port_num = split(port, ":")[2]
            
            if not host_ports[port_num] then
                host_ports[port_num] = 1
            end 
        end
    end
end

-- Go back to the original interface
interface.select(ifid)

-- Format the answer
for port, _ in pairs(host_ports) do
    res[#res + 1] = {
        key = port,
        value = port
    }
end

rest_utils.answer(rest_utils.consts.success.ok, res)
