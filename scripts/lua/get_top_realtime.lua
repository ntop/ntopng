--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")
local top_talkers_utils = require("top_talkers_utils")
local direction = _GET["senders_receivers"] or "senders"
sendHTTPContentTypeHeader('text/html')

local top_type = _GET["module"]
local data = {}

local json_res = top_talkers_utils.makeTopJson(ifname, false --[[ do not save checkpoint as we are not in minute.lua ]])

if json_res ~= nil then
  local res = json.decode(json_res)

  if res and res.vlan[1] then
    res = res.vlan[1]

    if top_type == "top_asn" then
      res = res.asn[1]
    else
      res = res.hosts[1]
    end

    if res ~= nil then
      data = res[direction]

      local min_percentage = 0.08
      local tot = 0
      local other_value = 0

      for _, item in pairs(data) do
        tot = tot + item.value
      end

      local final_data = {}

      for _, item in pairs(data) do
        local perc = item.value / tot

        if (perc >= min_percentage) and (item.address ~= "Other") then
          if isEmptyString(item.label) then item.label = item.address end

          if top_type == "top_talkers" then
            item.url = ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. item.address
          elseif top_type == "top_asn" then
            item.url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=" .. item.address
          end

          final_data[#final_data + 1] = item
        else
          other_value = other_value + item.value
        end
      end

      if other_value > 0 then
        final_data[#final_data + 1] = {
          label = i18n("other"),
          value = other_value,
        }
      end

      data = final_data
    end
  end
end

print(json.encode(data))
