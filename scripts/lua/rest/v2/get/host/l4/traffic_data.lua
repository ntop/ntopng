--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local rest_utils = require "rest_utils"

local ifid      = _GET["ifid"] or interface.getId()
local host_ip   = _GET["host"]
local host_vlan = _GET["vlan"] or 0
interface.select(tostring(ifid))

local host = interface.getHostInfo(host_ip, host_vlan)
local total_bytes_sent = 0
local total_bytes_rcvd = 0

if host then
  for id, _ in ipairs(l4_keys) do
    local key = l4_keys[id][2]

    if host[key..".bytes.sent"] ~= nil then
      total_bytes_sent = total_bytes_sent + host[key..".bytes.sent"]
    end

    if host[key..".bytes.rcvd"] ~= nil then
      total_bytes_rcvd = total_bytes_rcvd + host[key..".bytes.rcvd"]
    end
  end
end

local data = {
  { label = i18n("traffic_page.bytes_sent"), value = total_bytes_sent },
  { label = i18n("traffic_page.bytes_rcvd"), value = total_bytes_rcvd},
}

rest_utils.answer(rest_utils.consts.success.ok, data)