--
-- (C) 2014-18 - ntop.org
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

-- ########################################################

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

	    count = 0
	    for what_val_k, delta in pairs(direction_val) do
	       count = count + 1
	       -- at least 5
	       if (count > top_talkers_utils.MAX_NUM_ENTRIES / 2
		   and delta / total < top_talkers_utils.THRESHOLD_LOW) then
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
	       local label = what_val_k

	       if (what_val_k ~= "Other") and (what_val_k ~= "Hidden Hosts") then
		  if what_key_k == "hosts" then
		     label = getCache(hostname_cache, what_val_k)
		  elseif what_key_k == "asn" then
		     label = getCache(asname_cache, what_val_k)
		  end
	       end

	       if label == what_val_k then
	         -- Skip this label, as it is the same as the address
	         label = nil
	       end

	       direction_val[what_val_k] = {address = what_val_k..'', value = delta, label = label}
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

      vlan_val["value"] = vlan_totals[vlan_k]
      vlan_val["address"] = vlan_k..""
   end

   return {vlan = p}
end

-- ########################################################

function top_talkers_utils.makeTopJson(_ifname, save_checkpoint)
   local ifid = getInterfaceId(_ifname)
   if save_checkpoint == nil then save_checkpoint = true end

   local res = {}

   local in_time = callback_utils.foreachHost(_ifname, os.time() + 60 --[[1 minute --]], function (hostname, hoststats)
      local checkpoint = interface.checkpointHostTalker(ifid, hostname, save_checkpoint)

      if(checkpoint == nil) then 
        goto continue
      end

      local current, previous
      if checkpoint["previous"] then previous = checkpoint["previous"] end
      if checkpoint["current"] then current = checkpoint["current"] end

      if not save_checkpoint and not previous then
        previous = {sent=0, rcvd=0}
      end

     local vlan = hoststats["vlan"]

     updateCache(hostname_cache, hostname, hoststats["name"])
     updateCache(localhost_cache, hostname, hoststats["localhost"])
     updateCache(asname_cache, hoststats["asn"], hoststats["asname"])

     if current and previous then
	for _, direction in pairs({"sent", "rcvd"}) do
	   local delta = current[direction] - previous[direction]

	   vlan_totals[vlan] = (vlan_totals[vlan] or 0) + delta

	   local os_key = "non-local os"
	   if hoststats["localhost"] then
	      os_key = "local os"
	   end

	   local country = interface.getHostCountry(hostname)

	   for what_key, what_value in pairs({
	       ["hosts"] = hostname, ["asn"] = hoststats["asn"],[os_key] = hoststats["os"],
	       ["countries"] = ternary(not isEmptyString(country), country, nil),
	       ["networks"] = hoststats["local_network_id"],
	    }) do
	      if hoststats.hiddenFromTop then
	        what_value = "Hidden Hosts"
	      end

	      updateRes(res, vlan, what_key, what_value, direction, delta)
	   end
	end
     end

     ::continue::
   end)

   if not in_time then
      print("[".. _ifname .."] ERROR: Cannot complete top talkers generation in 1 minute. Is there a huge number of hosts in the system?")
   end

   sortRes(res)
   return json.encode(finalizeRes(res))
end

-- ########################################################

-- Computes label and url during visualization
function top_talkers_utils.enrichRecordInformation(class_key, rec, show_vlan)
  local url = ""
  local label = rec.label or rec.address

  if (rec.address ~= "Other") and (rec.address ~= "Hidden Hosts") then
    if class_key == "hosts" then
      url = ntop.getHttpPrefix()..'/lua/host_details.lua?always_show_hist=true&host='
      -- Use the host alias as label, if set
      local alt_name = getHostAltName(rec.address)
      if not isEmptyString(alt_name) and (alt_name ~= rec.address) then
        label = alt_name
      else
        local hinfo = hostkey2hostinfo(rec.address)
        if not show_vlan then hinfo.vlan = 0 end
        alt_name = host2name(hinfo.host, hinfo.vlan)

        if not isEmptyString(alt_name) and (alt_name ~= rec.address) then
           label = alt_name
        else
           label = rec.address
        end
      end
    elseif class_key == "asn" then
      url = ntop.getHttpPrefix()..'/lua/hosts_stats.lua?asn='
    elseif class_key == "networks" then
      url = ntop.getHttpPrefix()..'/lua/hosts_stats.lua?network='

      local network_name = nil
      if rec.address == "-1" then
	 network_name = i18n("remote_networks")
      else
	 network_name = ntop.getNetworkNameById(tonumber(rec.address))
      end
      if not isEmptyString(network_name) then
	 label = network_name
      end
    elseif class_key:contains("os") then
      url = ntop.getHttpPrefix()..'/lua/hosts_stats.lua?os='
    end

    if not isEmptyString(url) then
      url = url .. rec.address
    end
  end

  -- Update record information
  rec.url = url
  rec.label = label
end

-- ########################################################

function top_talkers_utils.enrichVlanInformation(vlan_tbl)
   local vlan_id = ternary(vlan_tbl.address, tostring(vlan_tbl.address), "0")
   vlan_tbl["label"] = vlan_id
   vlan_tbl["name"] = vlan_id
   vlan_tbl["url"] = ntop.getHttpPrefix()..'/lua/hosts_stats.lua?vlan='..vlan_id
end

-- ########################################################

return top_talkers_utils
