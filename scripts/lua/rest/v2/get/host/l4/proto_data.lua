--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local rest_utils = require "rest_utils"

local ifid        = _GET["ifid"] or interface.getId()
local host_ip     = _GET["host"]
local host_vlan   = _GET["vlan"] or 0
interface.select(tostring(ifid))

local host = interface.getHostInfo(host_ip, host_vlan)
local max_num_entries = 5
local proto_stats = {}
local data = {}

-- ##################################

if host then
  for id, _ in ipairs(l4_keys) do
    local key = l4_keys[id][2]
    local traffic = 0

    if host[key..".bytes.sent"] ~= nil then
      traffic = traffic + host[key..".bytes.sent"]
    end

    if host[key..".bytes.rcvd"] ~= nil then
      traffic = traffic + host[key..".bytes.rcvd"]
    end

    if traffic > 0 then
      proto_stats[l4_keys[id][1]] = traffic
    end
  end
end

local color_index = 1
for key, value in pairsByValues(proto_stats, rev) do
  data[#data + 1] = {
    label  = key,
    value = value
  }
  color_index = color_index + 1
  max_num_entries = max_num_entries - 1

  if max_num_entries == 1 then
    break
  end
end

-- Just in case no data were found put an empty entry
if table.len(data) == 0 then
  data[1] = {
    label  = i18n('no_data_available'),
    value = 0
  }
end

-- ##################################

rest_utils.answer(rest_utils.consts.success.ok, { data = data })