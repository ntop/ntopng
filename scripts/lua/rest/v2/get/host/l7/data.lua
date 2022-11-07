--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Imports
require "lua_utils"
local rest_utils = require "rest_utils"

-- Local variables
local host_ip = _GET["host"]
local vlan = _GET["vlan"]
local view = _GET["view"]
local host = interface.getHostInfo(host_ip, vlan) or {}
local total_bytes = 0
local rsp = {}

-- Applications
if view == 'applications' and host then
  local host_applications = host["ndpi"] or {}

  -- Calculate the total bytes sent and received, to calculate the percentages
  for _, v in pairs(host_applications) do
    total_bytes = total_bytes + (v["bytes.rcvd"] or 0) + (v["bytes.sent"] or 0)
  end

  -- Now format the values
  for k, v in pairs(host_applications) do
    local tot_l7_bytes = (v["bytes.sent"] or 0) + (v["bytes.rcvd"] or 0)

    rsp[#rsp + 1] = {
      application = {
        id = interface.getnDPIProtoId(k), 
        label = k,
      },
      duration    = (v["duration"] or 0),
      bytes_sent  = (v["bytes.sent"] or 0),
      bytes_rcvd  = (v["bytes.rcvd"] or 0),
      tot_bytes   = tot_l7_bytes,
      percentage  = (tot_l7_bytes * 100) / total_bytes,
    }
  end
elseif host then
-- Categories
  local categories_utils = require "categories_utils"
  local host_categories = host["ndpi_categories"] or {}

  -- Calculate the total bytes sent and received, to calculate the percentages
  for _, v in pairs(host_categories) do
    total_bytes = total_bytes + (v["bytes"] or 0)
  end

  -- Now format the values
  for k, v in pairs(host_categories) do
    rsp[#rsp + 1] = {
      category     = {
        id = interface.getnDPICategoryId(k),
        label = getCategoryLabel(k, v.category),
      },
      applications = categories_utils.get_category_protocols_list(v.category, true),
      duration     = (v["duration"] or 0),
      tot_bytes    = (v["bytes"] or 0),
      percentage   = ((v["bytes"] or 0) * 100) / total_bytes,
    }
  end
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
