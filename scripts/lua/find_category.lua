--
-- (C) 2013-23 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local query = string.lower(_GET["query"])

local max_num_to_find = 7
local results = {}

local categories = interface.getnDPICategories()

for cat, id in pairsByKeys(categories, asc_insensitive) do
  cat = getCategoryLabel(cat, id)

  if string.contains(string.lower(cat), query) then
    results[#results + 1] = {name=cat, key=id}
    if #results >= max_num_to_find then
      break
    end
  end
end

local res = {
  rsp = {
    results = results
  }
}

print(json.encode(res, nil, 1))
