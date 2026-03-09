--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local graph_utils = require "graph_utils"

local ifid      = _GET["ifid"] or interface.getId()
local host_ip   = _GET["host"]
local host_vlan = _GET["vlan"] or 0
interface.select(tostring(ifid))

local host = interface.getHostInfo(host_ip, host_vlan)
local data = {}

local client = tonumber((host and host.cardinality and host.cardinality.num_contacted_hosts_as_client) or 0)
local server = tonumber((host and host.cardinality and host.cardinality.num_contacted_hosts_as_server) or 0)

if client > 0 then
  data[#data + 1] = { label = i18n("traffic_page.num_contacted_hosts_as_client"), value = client }
end

if server > 0 then
  data[#data + 1] = { label = i18n("traffic_page.num_contacted_hosts_as_server"), value = server }
end

rest_utils.answer(rest_utils.consts.success.ok, data)