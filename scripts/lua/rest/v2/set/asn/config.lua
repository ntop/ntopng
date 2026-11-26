
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "http_lint"
local rest_utils = require "rest_utils"
local as_utils = require "as_utils"

--
-- Saves the posted ASN lists (keys of as_utils.asn_lists, comma separated ASNs).
-- Example: curl -u admin:admin -d "cdn_asn=13335,20940" http://localhost:3000/lua/rest/v2/set/asn/config.lua
--

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- The posted ASNs without spaces and empty items: C++ aborts on an empty one, e.g. ",2404" (ASNConfiguration::loadConfiguration)
local function normalize(value)
   local asns = {}
   for asn in value:gmatch("[^,%s]+") do
      asns[#asns + 1] = asn
   end
   return table.concat(asns, ",")
end

-- An ASN can be in one category only: the posted lists are checked together with the saved ones
local category_of_asn = {}
for _, list in ipairs(as_utils.asn_lists) do
   if list.group == "category" then
      for asn in (_POST[list.key] or ntop.getCache(list.redis_key) or ""):gmatch("[^,%s]+") do
         if category_of_asn[asn] and category_of_asn[asn] ~= list.key then
            rest_utils.answer(rest_utils.consts.err.invalid_args)
            return
         end
         category_of_asn[asn] = list.key
      end
   end
end

-- Only the posted lists are changed (http_lint drops the invalid ones)
for _, list in ipairs(as_utils.asn_lists) do
   local value = _POST[list.key]
   if value then
      ntop.setCache(list.redis_key, normalize(value))
   end
end

ntop.reloadASNConfiguration()

rest_utils.answer(rest_utils.consts.success.ok, {})
