--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Imports
require "lua_utils"
local graph_utils = require "graph_utils"
local rest_utils = require "rest_utils"

-- Local variables

local ifid        = _GET["ifid"] or interface.getId()
local host_ip     = _GET["host"]
local host_vlan   = _GET["vlan"] or 0
interface.select(tostring(ifid))

local host = interface.getHostInfo(host_ip, host_vlan)
local total_bytes_rcvd = 0
local total_bytes_sent = 0
local colors = {}

if host then
  for id, _ in ipairs(l4_keys) do
    local key = l4_keys[id][2]
    local traffic = 0
    
    if(host[key..".bytes.sent"] ~= nil) then 
      traffic = traffic + host[key..".bytes.sent"] 
      total_bytes_sent = total_bytes_sent + host[key..".bytes.sent"] 
    end
    
    if(host[key..".bytes.rcvd"] ~= nil) then 
      traffic = traffic + host[key..".bytes.rcvd"] 
      total_bytes_rcvd = total_bytes_rcvd + host[key..".bytes.rcvd"] 
    end
  end
end

colors[#colors + 1] =  graph_utils.get_html_color(#colors + 1)
colors[#colors + 1] =  graph_utils.get_html_color(#colors + 1)

-- Bytes sent vs Bytes rcvd
local rsp = {
  ["series"] = { total_bytes_sent, total_bytes_rcvd },
  ["labels"] = { i18n("traffic_page.bytes_sent"), i18n("traffic_page.bytes_rcvd") },
  ["colors"] = colors -- Still two colors like the second serie, reuse it
}

-- ##################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
