--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")
local top_talkers_utils = require("top_talkers_utils")

sendHTTPContentTypeHeader('text/html')

local ifid = getInterfaceId(ifname)
local epoch = _GET["epoch"] or os.time()
local add_vlan = _GET["addvlan"]

-- TODO clean up

local function getTopTalkersFromJSONDirection(table, wantedDir, add_vlan)
   local elements = ""

   -- For each VLAN, get hosts and concatenate them
   local host_container = {}
   local sort_helper    = {}
   for i,vlan in pairs(table["vlan"]) do
      top_talkers_utils.enrichVlanInformation(vlan)
      local vlanid = vlan["label"]
      local vlanname = vlan["name"]
      -- XXX hosts is an array of (senders, receivers) pairs?

      for i2,hostpair in pairs(vlan["hosts"]) do
	 -- hostpair is { "senders": [...], "receivers": [...] }
	 
	 local direction = hostpair[wantedDir]
	 if direction == nil then direction = {} end
	 for _, host in pairs(direction) do
	    top_talkers_utils.enrichRecordInformation("hosts", host, add_vlan)
	    local addr = host["address"]
	    local val = tonumber(host["value"])
	    if addr == nil or val == nil then goto continue end
	    sort_helper[addr] = val
	    if(add_vlan ~= nil) then
	       host["vlanm"] = vlanname
	       host["vlan"] = vlanid
	    end
	    host_container[addr] = host
	    ::continue::
	 end
      end
   end

   for addr, val in pairsByValues(sort_helper, rev) do
      elements = elements.."{ "
      local n_el = 0
      for k3,v3 in pairs(host_container[addr]) do
	 elements = elements..'"'..k3..'": '
	 if(k3 == "value") then
	    elements = elements..tostring(v3)
	 else
	    elements = elements..'"'..v3..'"'
	 end
	 elements = elements..", "
	 n_el = n_el + 1
      end
      if(n_el ~= 0) then
	 elements = string.sub(elements, 1, -3)
      end
      elements = elements.." },\n"
   end

   return elements
end

local function printTopTalkersFromTable(table, add_vlan)
   if(table == nil or table["vlan"] == nil) then return "[ ]\n" end

   local elements = "{\n"
   elements = elements..'"senders": [\n'
   local result = getTopTalkersFromJSONDirection(table, "senders", add_vlan)
   if(result ~= "") then
      result = string.sub(result, 1, -3) --remove comma
   end
   elements = elements..result
   elements = elements.."],\n"
   elements = elements..'"receivers": [\n'
   result = getTopTalkersFromJSONDirection(table, "receivers", add_vlan)
   if(result ~= "") then
      result = string.sub(result, 1, -3) --remove comma
   end
   elements = elements..result
   elements = elements.."]\n"
   elements = elements.."}\n"

   return elements
end

local function getTopTalkersFromJSON(content, add_vlan)
  if(content == nil) then return("[ ]\n") end
  local table = json.decode(content, 1)
  local rsp = printTopTalkersFromTable(table, add_vlan)
  if(rsp == nil or rsp == "") then return "[ ]\n" end
  return rsp
end

local function getHistoricalTopTalkers(ifid, ifname, epoch, add_vlan)
   if(epoch == nil) then
      return("[ ]\n")
   end

   res = ntop.getMinuteSampling(ifid, tonumber(epoch))

   return getTopTalkersFromJSON(res, add_vlan)
end

if (module == nil) then
  print("[ ]\n")
else
  epoch = epoch+60 -- we return the minute before the event as epochs are stored in the DB 'past' the time period
  top = getHistoricalTopTalkers(ifid, ifname, epoch, add_vlan)
  print(top)
end
