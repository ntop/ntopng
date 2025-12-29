--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Return all interfaces enabled by ContinuousPing
-- Example: curl -u admin:admin -H "Content-Type: application/json"  http://localhost:3000/lua/rest/v2/get/ping/interfaces.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local interfaces = ntop.getPingIfNames()

for id, ifname in pairs(interfaces) do
  local custom_name = getHumanReadableInterfaceName(ifname)

  if isEmptyString(custom_name) then
    custom_name = nil
  end

  -- Note: returning in a format compatible with /lua/rest/v2/get/ntopng/interfaces.lua
  res[#res + 1] = {
    ifid = tonumber(id),
    ifname = ifname,
    name = custom_name or ifname,
    is_packet_interface = true,
    is_pcap_interface = false,
    is_zmq_interface = false,
  }
end

rest_utils.answer(rc, res)
