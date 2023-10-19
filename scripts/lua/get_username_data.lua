--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

local mode     = _GET["ebpf_data"] or "processes"
local host     = _GET["host"]
local username = _GET["username"]
local uid      = _GET["uid"]

local pageinfo = {
   ["sortColumn"] = "column_bytes",
   ["maxHits"] = 15,
   ["a2zSortOrder"] = false,
   ["hostFilter"] = host,
   ["usernameFilter"]  = username,
   ["detailsLevel"] = "high", -- to obtain processes information
}

local flows_stats = interface.getFlowsInfo(host, pageinfo)
local res = {}

if not flows_stats then
   res[#res + 1] = {label = "Other", value = 1}
   --    print('[ { "label": "Other", "value": 1 } ]') -- No flows found
else
   flows_stats = flows_stats["flows"]

   local tot = 0

   local aggregation = {}
   for _, f in pairs(flows_stats or {}) do
      local key

      -- Prepare aggregation parameter
      if mode == "processes" then
	 if f["client_process"] and f["client_process"]["user_name"] == username then
	    key = f["client_process"]["name"]
	 elseif f["server_process"] and f["server_process"]["user_name"] == username then
	    key = f["server_process"]["name"]
	 end
      elseif mode == "applications" then
	 key = f["proto.ndpi"]
      elseif mode == "breeds" then
	 key = f["proto.ndpi_breed"]
      elseif mode == "categories" then
	 key = f["proto.ndpi_cat"]
      end

      -- Do aggregation
      if key then
	 if aggregation[key] == nil then aggregation[key] = 0 end
	 local v = f["cli2srv.bytes"] + f["srv2cli.bytes"]
	 aggregation[key] = aggregation[key] + v
	 tot = tot + v
      end
   end

   -- Print up to this number of entries
   local max_num_entries = 10

   -- Print entries whose value >= 5% of the total
   local threshold = (tot * 5) / 100

   local num = 0
   local accumulate = 0
   for key, value in pairsByValues(aggregation, rev) do
      if value < threshold and num > 0 then
	 break
      end

      res[#res + 1] = {label = key, value = value}

      accumulate = accumulate + value
      num = num + 1

      if num >= max_num_entries then
	 break
      end
   end

   -- In case there is some leftover do print it as "Other"
   if accumulate < tot then
      res[#res + 1] = {label = "Other", value = (tot - accumulate)}
   end

end

print(json.encode(res))

