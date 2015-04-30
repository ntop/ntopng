--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "top_talkers"
require "top_structure"
require "json"

local top_vlan_intf = {}

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/top_scripts/?.lua;" .. package.path
  local new = require("top_aggregate")
  if (type(new) ~= "table") then new = {} end
  -- Add pro methods to local method table
  for k,v in pairs(new) do
    top_vlan_intf[k] = v
  end
end

local function getTopVLAN(ifid, ifname)
  return getCurrentTopGroups(ifid, ifname, 10, true, false,
                             nil, nil, top_vlan_intf.key,
                             top_vlan_intf.JSONkey, true, nil,
                             top_vlan_intf.uniqueKey)
end

local function getTopVlanClean(ifid, ifname, param)
  top = getCurrentTopGroups(ifid, ifname, 10, true, false,
                            nil, nil, top_vlan_intf.key,
                            top_vlan_intf.JSONkey, false, nil,
                            top_vlan_intf.uniqueKey)
  section_beginning = string.find(top, '%[')
  if (section_beginning == nil) then
    return("[ ]\n")
  else
    return(string.sub(top, section_beginning))
  end
end

local function getTopVLANFromJSON(content, add_vlan)
  if(content == nil) then return("[ ]\n") end
  local table = parseJSON(content)
  if (table == nil or table[top_vlan_intf.JSONkey] == nil) then return "[ ]\n" end
  local nr_elements = 0

  local elements = "[\n"
  for i,vlan in pairs(table[top_vlan_intf.JSONkey]) do
    if (add_vlan ~= nil and tostring(vlan["label"]) == "0") then
      goto continue
    end
    elements = elements.."{ "
    for k,v in pairs(vlan) do
      if (type(v) ~= "table") then
        elements = elements..'"'..k..'": '
      end
      if (k == "value") then
        elements = elements..tostring(v)
      elseif (type(v) ~= "table") then
        elements = elements..'"'..tostring(v)..'"'
      end
      if (type(v) ~= "table") then
        elements = elements..", "
      end
    end
    elements = string.sub(elements, 1, -3)
    elements = elements.." },\n"
    nr_elements = nr_elements + 1
    ::continue::
  end
  if (nr_elements > 0) then
    elements = string.sub(elements, 1, -3)
  end
  elements = elements.."\n]"
  return elements
end

local function getHistoricalTopVLAN(ifid, ifname, epoch, add_vlan)
  if (epoch == nil) then
    return("[ ]\n")
  end
  return getTopVLANFromJSON(ntop.getMinuteSampling(ifid, tonumber(epoch)), add_vlan)
end

top_vlan_intf.name = "VLANs"
top_vlan_intf.infoScript = "hosts_stats.lua"
top_vlan_intf.infoScriptKey = "vlan"
top_vlan_intf.key = "vlan"
top_vlan_intf.JSONkey = "vlan"
top_vlan_intf.uniqueKey = "top_vlan"
top_vlan_intf.getTop = getTopVLAN
-- No getTopBy method as it must not be same level with others in JSON
top_vlan_intf.getTopClean = getTopVLANClean
top_vlan_intf.getTopFromJSON = getTopVLANFromJSON
top_vlan_intf.getHistoricalTop = getHistoricalTopVLAN
top_vlan_intf.numLevels = 1

return top_vlan_intf
