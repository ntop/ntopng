--
-- (C) 2014-17 - ntop.org
--

local callback_utils = require "callback_utils"

require "lua_utils" -- TODO:  remove
local json = require "dkjson"

local top_talkers_utils = {}
top_talkers_utils.MAX_NUM_ENTRIES = 10
top_talkers_utils.THRESHOLD_LOW = .05

local vlan_totals = {}
local asname_cache    = {}
local hostname_cache  = {}
local localhost_cache = {}

local function updateCache(cache, key, val)
   if cache[key] == nil then
      cache[key] = val
   end
end

local function getCache(cache, key)
   return cache[key]
end

local function updateRes(res, vlan, what_key, what_value, direction, delta)
   if res == nil then res = {} end
   if res[vlan] == nil then res[vlan] = {} end
   if res[vlan][what_key] == nil then res[vlan][what_key] = {} end
   if res[vlan][what_key][direction] == nil then res[vlan][what_key][direction] = {} end
   if res[vlan][what_key][direction][what_value] == nil then res[vlan][what_key][direction][what_value] = 0 end

   res[vlan][what_key][direction][what_value] = res[vlan][what_key][direction][what_value] + delta
end

local function sortRes(res)
   for vlan_k, vlan_val in pairs(res) do
      for what_key_k, what_key_val in pairs(vlan_val) do
	 for direction_key, direction_val in pairs(what_key_val) do
	    local total, count, other = 0, 0, 0

	    for what_val_k, delta in pairsByValues(direction_val, rev) do
	       count = count + 1
	       total = total + delta

	       if delta <= 0 or count > top_talkers_utils.MAX_NUM_ENTRIES then
		  if delta > 0 then other = other + delta end
		  direction_val[what_val_k] = nil
	       end
	    end

	    for what_val_k, delta in pairs(direction_val) do
	       if delta / total < top_talkers_utils.THRESHOLD_LOW then
		  if delta > 0 then other = other + delta end
		  direction_val[what_val_k] = nil
	       end
	    end

	    if other > 0 then
	       direction_val["Other"] = other
	    end
	 end
      end
   end
end

local function finalizeRes(res)
   for vlan_k, vlan_val in pairs(res) do
      for what_key_k, what_key_val in pairs(vlan_val) do
	 for direction_key, direction_val in pairs(what_key_val) do
	    for what_val_k, delta in pairs(direction_val) do
	       local url = ''
	       local label = what_val_k

	       if what_val_k ~= "Other" then
		  if what_key_k == "hosts" then
		     url = ntop.getHttpPrefix()..'/lua/host_details.lua?host='
		     label = getCache(hostname_cache, what_val_k)
		  elseif what_key_k == "asn" then
		     url = ntop.getHttpPrefix()..'/lua/hosts_stats.lua?asn='
		     label = getCache(asname_cache, what_val_k)
		  elseif what_key_k:contains("os") then
		     url = ntop.getHttpPrefix()..'/lua/hosts_stats.lua?os='
		  end
		  url = url..what_val_k
	       end

	       direction_val[what_val_k] = {address = what_val_k..'', value = delta, url = url, label = label}
	       if what_key_k == "hosts" then
		  direction_val[what_val_k]["local"] = tostring(getCache(localhost_cache, what_val_k) or "false")
	       end
	    end
	 end
      end
   end

   -- Convert to the previous format
   local p = {}
   for vlan_k, vlan_val in pairs(res) do
      p[#p + 1] = vlan_val

      for what_key_k, what_key_val in pairs(vlan_val) do
	 local s = {}
	 for _, sender in pairs(what_key_val["sent"]) do
	    s[#s + 1] = sender
	 end

	 local r = {}
	 for _, receiver in pairs(what_key_val["rcvd"]) do
	    r[#r + 1] = receiver
	 end

	 vlan_val[what_key_k] = {{senders = s, receivers = r}}
      end

      -- TODO: check and possibly remove the following fields
      vlan_val["label"] = vlan_k..''
      vlan_val["name"] = vlan_k..''
      vlan_val["url"] = ntop.getHttpPrefix()..'/lua/hosts_stats.lua?vlan='..vlan_k
      vlan_val["value"] = vlan_totals[vlan_k]
   end

   return {vlan = p}
end

function top_talkers_utils.makeTopJson(_ifname)
   local ifid = getInterfaceId(_ifname)

   local res = {}

   local in_time = callback_utils.foreachHost(_ifname, os.time() + 60 --[[1 minute --]], function (hostname, hoststats)
     local checkpoint_id = checkpointId("top_talkers")
     local checkpoint = interface.checkpointHost(ifid, hostname, checkpoint_id, "normal")

     local current, previous
     if checkpoint["previous"] then previous = json.decode(checkpoint["previous"]) end
     if checkpoint["current"] then current = json.decode(checkpoint["current"]) end

     local vlan = hoststats["vlan"]

     updateCache(hostname_cache, hostname, hoststats["name"])
     updateCache(localhost_cache, hostname, hoststats["localhost"])
     updateCache(asname_cache, hoststats["asn"], hoststats["asname"])

     if current and previous then
	for _, direction in pairs({"sent", "rcvd"}) do
	   local delta = current[direction]["bytes"] - previous[direction]["bytes"]

	   vlan_totals[vlan] = (vlan_totals[vlan] or 0) + delta

	   local os_key = "non-local os"
	   if hoststats["localhost"] then
	      os_key = "local os"
	   end

	   for what_key, what_value in
	   pairs({["hosts"] = hostname, ["asn"] = hoststats["asn"], [os_key] = hoststats["os"]}) do
	      updateRes(res, vlan, what_key, what_value, direction, delta)
	   end
	end
     end
   end)

   if not in_time then
      callback_utils.print(__FILE__(), __LINE__(),
			   "ERROR: Cannot complete top talkers generation in 1 minute. Is there a huge number of hosts in the system?")
   end

   sortRes(res)
   return json.encode(finalizeRes(res))
end

return top_talkers_utils
