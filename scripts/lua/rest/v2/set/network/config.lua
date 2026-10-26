
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint" -- also ntop_utils: isAdministrator()
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local network_config_utils = require "network_config_utils"

-- append_only=1|true: the posted IPs are added to the saved list (duplicates skipped) instead of replacing it
local append_only = (_POST["append_only"] == "1" or _POST["append_only"] == "true")

-- Strips the spaces and, with append_only, merges the new IPs into the list already saved in redis
local function save_list(redis_key, value)
   local parsed = value:gsub("%s+", "")

   if append_only then
      local merged, seen = {}, {}
      for _, list in ipairs({ ntop.getCache(redis_key) or "", parsed }) do
         for ip in list:gmatch("[^,]+") do
            if not seen[ip] then
               seen[ip] = true
               merged[#merged + 1] = ip
            end
         end
      end
      parsed = table.concat(merged, ",")
   end

   ntop.setCache(redis_key, parsed)
end

-- Only the posted lists are changed (http_lint drops the invalid ones)
for _, server in ipairs(network_config_utils.servers) do
   local value = _POST[server.key]

   if value then
      save_list(server.redis_key, value)
   end
end

ntop.reloadServersConfiguration()

rest_utils.answer(rest_utils.consts.success.ok, {})
