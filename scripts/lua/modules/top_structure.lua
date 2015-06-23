--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "top_talkers"

local function getVLANList(ifid, ifname)
   interface.select(ifname)
   hosts_stats = interface.getHostsInfo()
   vlans,total = groupStatsByColumn(ifid, ifname, "vlan")
   return vlans
end

function makeTopJSON(ifid, ifname)
  path = dirs.installdir .. "/scripts/lua/modules/top_scripts"
  path = fixPath(path)
  local files = ntop.readdir(path)
  local file_cnt = 0
  local vlan_cnt = 0

  vlan_list = getVLANList(ifid, ifname)
  if (next(vlan_list) == nil) then return "[ ]\n" end
  rsp = '{\n "vlan": [\n'
  for key,value in pairs(vlan_list) do
    rsp = rsp.."{\n"
    rsp = rsp..'\n"label": "'..key..'",\n"url": "'
            ..ntop.getHttpPrefix()..
            '/lua/hosts_stats.lua?vlan='..key..'",\n"name": "'
            ..vlan_list[key]["name"]..'",\n"value": '
            ..vlan_list[key]["vlan_bytes"]..",\n"
    file_cnt = 0
    for k,v in pairs(files) do
      if (v ~= nil) then
        fn,ext = v:match("([^.]+).lua")
        local topClass = require("top_scripts."..fn)
        if (topClass.getTopBy ~= nil) then
          rsp = rsp..topClass.getTopBy(ifid, ifname, "vlan", key)
          rsp = rsp..",\n"
          file_cnt = file_cnt + 1
        end
      end
    end
    if (file_cnt > 0) then
      -- Remove last return and comma to comply with JSON format
      rsp = string.sub(rsp, 1, -3)
    end
    rsp = rsp.."},\n"
    vlan_cnt = vlan_cnt + 1
  end
  if (vlan_cnt > 0) then
    -- Remove last return and comma to comply with JSON format
    rsp = string.sub(rsp, 1, -3)
  end
  rsp = rsp.."\n]\n}"

  return(rsp)
end

