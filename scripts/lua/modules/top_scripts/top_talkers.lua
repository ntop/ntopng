--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "top_talkers"

local top_talkers_intf = {}

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/top_scripts/?.lua;" .. package.path
   local new = require("top_aggregate")
   if(type(new) ~= "table") then new = {} end
   -- Add pro methods to local method table
   for k,v in pairs(new) do
      top_talkers_intf[k] = v
   end
end

local function getTopTalkers(ifid, ifname)
   return getCurrentTopTalkers(ifid, ifname, nil, nil, true, nil, nil,
			       top_talkers_intf.uniqueKey)
end

local function getTopTalkersBy(ifid, ifname, filter_col, filter_val)
   return getCurrentTopTalkers(ifid, ifname, filter_col, filter_val, true, nil, nil,
			       top_talkers_intf.uniqueKey)
end

local function getTopTalkersClean(ifid, ifname, param)
   top = getCurrentTopTalkers(ifid, ifname, nil, nil, false, param, true,
			      top_talkers_intf.uniqueKey)
   section_beginning = string.find(top, '%[')
   if(section_beginning == nil) then
      return("[ ]\n")
   else
      return(string.sub(top, section_beginning))
   end
end

local function printTopTalkersTable(tbl)
   local rsp = "{\n"

   for i,v in pairs(tbl) do
      local outouterlooped = 0
      for dk,dv in pairs(v) do
	 rsp = rsp..'"'..dk..'": [\n'
	 local keys = getKeys(dv, "value")
	 local outerlooped = 0
	 for tv,tk in pairsByKeys(keys, rev) do
	    rv = dv[tk]
	    rsp = rsp.."{ "
	    local looped = 0
	    for k,v in pairs(rv) do
	       rsp = rsp..'"'..k..'": '
	       if(k == "value") then
		  rsp = rsp..tostring(v)
	       else
		  rsp = rsp..'"'..v..'"'
	       end
	       rsp = rsp..", "
	       looped = looped + 1
	    end
	    if(looped > 0) then
	       rsp = string.sub(rsp, 1, -3)
	    end
	    rsp = rsp.."},\n"
	    outerlooped = outerlooped + 1
	 end
	 if(outerlooped > 0) then
	    rsp = string.sub(rsp, 1, -3)
	 end
	 rsp = rsp.."],\n"
	 outouterlooped = outouterlooped + 1
      end
      if(outouterlooped > 0) then
	 rsp= string.sub(rsp, 1, -3)
      end
   end

   rsp = rsp.."\n}"

   return rsp

end

local function topTalkersSectionInTableOP(tblarray, arithOp)
   local ret = {}
   local outer_cnt = 1
   local num_glob = 1

   for _,tbl in pairs(tblarray) do
      for _,outer in pairs(tbl) do
	 if(ret[outer_cnt] == nil) then ret[outer_cnt] = {} end
	 for key, value in pairs(outer) do
	    for _,record in pairs(value) do
	       local found = false
	       if(ret[outer_cnt][key] == nil) then ret[outer_cnt][key] = {} end
	       for _,el in pairs(ret[outer_cnt][key]) do
		  if(found == false and el["address"] == record["address"]) then
		     el["value"] = arithOp(el["value"], record["value"])
		     found = true
		  end
	       end
	       if(found == false) then
		  ret[outer_cnt][key][num_glob] = record
		  num_glob = num_glob + 1
	       end
	    end
	 end
      end
   end

   return ret
end

local function getTopTalkersFromJSONDirection(table, wantedDir, add_vlan)
   local elements = ""

   -- For each VLAN, get hosts and concatenate them
   for i,vlan in pairs(table["vlan"]) do
      local vlanid = vlan["label"]
      local vlanname = vlan["name"]
      -- XXX hosts is an array of (senders, receivers) pairs?
      for i2,hostpair in pairs(vlan[top_talkers_intf.JSONkey]) do
	 -- hostpair is { "senders": [...], "receivers": [...] }
	 for k2,direction in pairs(hostpair) do
	    -- direction is "senders": [...] or "receivers": [...]
	    if(k2 ~= wantedDir) then goto continue end
	    -- scan hosts
	    for i2,host in pairs(direction) do
	       -- host is { "label": ..., "value": ..., "url": ... }
	       elements = elements.."{ "
	       local n_el = 0
	       for k3,v3 in pairs(host) do
		  elements = elements..'"'..k3..'": '
		  if(k3 == "value") then
		     elements = elements..tostring(v3)
		  else
		     elements = elements..'"'..v3..'"'
		  end
		  elements = elements..", "
		  n_el = n_el + 1
	       end
	       if(add_vlan ~= nil) then
		  elements = elements..'"vlanm": "'..vlanname..'", '
		  elements = elements..'"vlan": "'..vlanid..'", '
	       end
	       if(n_el ~= 0) then
		  elements = string.sub(elements, 1, -3)
	       end
	       elements = elements.." },\n"
	    end
	    ::continue::
	 end
      end
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

local function getHistoricalTopTalkersInInterval(ifid, ifname, epoch_start, epoch_end, add_vlan)

   -- retrieves Aggregated top Talkers value from sqlite
   local json = require ("dkjson")
   if epoch_start == nil or epoch_end == nil or epoch_start == "" or epoch_end == "" then
      return json.encode({}, nil)
   end

   local query = ntop.getMinuteSamplingsInterval(ifid, tonumber(epoch_start), tonumber(epoch_end))
   -- sum up the selected 1-minute top talker statistics to have an aggregated 'top'
   -- please keep in mind that this is an approximation of the real top talkers
   -- the resulting table will be like the following
   --[[
   table
   senders table
   senders.216.58.210.238 number 7743
   senders.173.194.112.169 number 2586
   ...
   receivers table
   receivers.216.58.210.238 number 5281
   receivers.173.194.112.169 number 3093
   ...
   --]]
   local res = {["senders"] = {}, ["receivers"] = {}}
   for record,_ in pairs(query) do
      record = json.decode(record, 1)
      if not record or not next(record) or not record["vlan"] then goto next_record end
      -- tprint(record)
      for _, vlan in pairs(record["vlan"]) do
	   local vlanid = vlan["label"]
	   local vlanname = vlan["name"]
	   -- TODO: handle vlans
	   if not vlan["hosts"] then goto next_vlan end
	   for _, host_pair in pairs(vlan["hosts"]) do
	      for direction, top_hosts in pairs(host_pair) do
		 for _, host in pairs(top_hosts) do
		    local label = host["address"]
		    local traffic = tonumber(host["value"])
		    if label == nil then label = "" end
		    if traffic == nil then traffic = 0 end
		    if res[direction][label] == nil then
		       res[direction][label] = traffic
		    else
		       res[direction][label] = res[direction][label] + traffic
		    end
		 end
	      end
	   end
	   ::next_vlan::
      end
      ::next_record::
   end
   -- tprint(res)
   -- reformat the output so that it becomes easier to parse
   local pretty_res = {}
   for direction, hosts in pairs(res) do
      local t = {}
      for addr, traffic in pairs(hosts) do
	 table.insert(pretty_res, {["addr"] = addr, ["bytes"] = traffic, ["direction"] = direction})
      end
   end
   res = pretty_res
   return res
end

top_talkers_intf.name = "Top Talkers"
top_talkers_intf.infoScript = "host_details.lua"
top_talkers_intf.infoScriptKey = "host"
top_talkers_intf.key = "host"
top_talkers_intf.JSONkey = "hosts"
top_talkers_intf.uniqueKey = "top_talkers"
top_talkers_intf.getTop = getTopTalkers
top_talkers_intf.getTopBy = getTopTalkersBy
top_talkers_intf.getTopClean = getTopTalkersClean
top_talkers_intf.getTopFromJSON = getTopTalkersFromJSON
top_talkers_intf.printTopTable = printTopTalkersTable
top_talkers_intf.getHistoricalTop = getHistoricalTopTalkers
top_talkers_intf.getHistoricalTopInInterval = getHistoricalTopTalkersInInterval
top_talkers_intf.topSectionInTableOp = topTalkersSectionInTableOP
top_talkers_intf.numLevels = 2

return top_talkers_intf
