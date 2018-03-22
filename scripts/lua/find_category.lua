--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

max_num_to_find = 7
local res = {results={}}
local results = res.results

local query = string.lower(_GET["query"])

local categories = interface.getnDPICategories()

for cat, id in pairsByKeys(categories, asc_insensitive) do
  if string.contains(string.lower(cat), query) then
    results[#results + 1] = {name=cat, key=id}
    if #results >= max_num_to_find then
      break
    end
  end
end

print(json.encode(res, nil, 1))
