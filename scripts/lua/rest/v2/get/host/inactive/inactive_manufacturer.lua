--
-- (C) 2013-23 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Imports
require "lua_utils"
local graph_utils = require "graph_utils"
local rest_utils = require "rest_utils"
local inactive_hosts_utils = require "inactive_hosts_utils"

-- Local variables

local ifid        = _GET["ifid"] or interface.getId()
interface.select(tostring(ifid))

local inactive_hosts_manufacturer = inactive_hosts_utils.getManufacturerFilters(ifid)--, inactive_hosts_utils.getFilters())
local series = {}
local labels = {}
local colors = {}
local rsp = {
  series = {},
  labels = {},
  colors = {},
  yaxis = {
    labels = {}
  },
  tooltip = {
    y = {}
  }
}

for _, info in pairs(inactive_hosts_manufacturer) do
  if info.count then
    series[#series + 1] = info.count
    labels[#labels + 1] = info.label
    colors[#colors + 1] =  graph_utils.get_html_color(#colors + 1)
  end
end

rsp.series = series
rsp.labels = labels
rsp.colors = colors

-- ##################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
