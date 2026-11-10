--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Where a MAC address was seen on the monitored SNMP devices (bridge tables): the access ports
-- (one connected device) and the trunk ports. Enterprise M.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/mac/snmp_location.lua?ifid=0&host=AA:BB:CC:DD:EE:FF"
--

require "http_lint"
local rest_utils = require "rest_utils"

local ifid = _GET["ifid"]
local mac = _GET["host"]

if not (ntop.isEnterpriseM and ntop.isEnterpriseM()) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(ifid) or isEmptyString(mac) or not isMacAddress(mac) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "label_utils"
local snmp_location = require "snmp_location"

local trunk_ports, access_ports = snmp_location.get_host_snmp_ports(mac)
local device_names = {}

local function format_ports(ports)
   local res = {}
   for _, port in ipairs(ports or {}) do
      local device_ip = port["snmp_device_ip"]
      if device_names[device_ip] == nil then
         device_names[device_ip] = hostinfo2label(hostkey2hostinfo(device_ip))
      end
      local port_id = port.id or port.index
      res[#res + 1] = {
         device_ip = device_ip,
         device_name = device_names[device_ip],
         port_index = port_id,
         -- The alias of the interface has priority over its name
         port_name = (not isEmptyString(port.ifname) and port.ifname ~= port_id) and port.ifname
            or ((not isEmptyString(port.name) and port.name ~= port_id) and port.name or nil),
         trunk = port.trunk or false,
      }
   end
   return res
end

rest_utils.answer(rest_utils.consts.success.ok, {
   access_ports = format_ports(access_ports),
   trunk_ports = format_ports(trunk_ports),
})
