--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

max_num_to_find = 7
local res = {results={}}
local results = res.results

local ifid = _GET["ifId"]
local query = string.lower(_GET["query"])
local skip_critical = _GET["skip_critical"]
local category_filter = _GET["category"]

interface.select(ifid)

if not isEmptyString(category_filter) and starts(category_filter, "cat_") then
  category_filter = split(category_filter, "cat_")[2]
end

local protocols = interface.getnDPIProtocols(tonumber(category_filter), toboolean(skip_critical))

for proto, id in pairsByKeys(protocols, asc_insensitive) do
  if string.contains(string.lower(proto), query) then
    results[#results + 1] = {name=proto, key=id}
    if #results >= max_num_to_find then
      break
    end
  end
end

print(json.encode(res, nil, 1))
