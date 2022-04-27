--
-- (C) 2017-22 - ntop.org
--
local dirs = ntop.getDirs()

require "lua_utils"
local alert_severities = require "alert_severities"
local checks = require "checks"
local host_pools = require "host_pools":create()
local am_utils = require "am_utils"

-- ##############################################

local recipients_rest_utils = {}

-- ##############################################

-- @brief Parses and validates a comma-separated list of user script category ids into a lua array
-- @return A lua array of valid user script category ids
function recipients_rest_utils.parse_check_categories(categories_string)
   local categories = {}

    if isEmptyString(categories_string) then return categories end

    -- Unfold the categories csv
    categories = categories_string:split(",") or {categories_string}

    local res = {}
    for _, category_id in pairs(categories) do
       local category_id = tonumber(category_id)

       for _, category in pairs(checks.check_categories) do
	  if category_id == category.id then
	     res[#res + 1] = category_id
	     break
	  end
       end
    end

    return res
end

-- ##############################################

-- @brief Parses and validates a comma-separated list of host pool ids into a lua array
-- @return A lua array of valid ids
function recipients_rest_utils.parse_host_pools(pools_string)
   local pools = host_pools:get_all_pools()
   local pools_list = {}

    if isEmptyString(pools_string) then return pools_list end

    -- Unfold the pools csv
    pools_list = pools_string:split(",") or {pools_string}

    local res = {}
    for _, pool_id in pairs(pools_list) do
       local pool_id = tonumber(pool_id)

       for _, pool in pairs(pools) do
	  if pool_id == pool.pool_id then
	     res[#res + 1] = pool_id
	     break
	  end
       end
    end

    return res
end

-- ##############################################

-- @brief Parses and validates a comma-separated list of active monitoring hosts into a lua array
-- @return A lua array of valid ids
function recipients_rest_utils.parse_am_hosts(hosts_string)
   local hosts_list = {}

    if isEmptyString(hosts_string) then return hosts_list end

    -- Unfold the hosts csv
    hosts_list = hosts_string:split(",") or {hosts_string}

    local am_hosts = am_utils.getHosts()

    local res = {}
    for _, host_id in pairs(hosts_list) do
       if am_hosts[host_id] then
	  res[#res + 1] = host_id
       else
          -- Debug
          tprint(host_id .. " AM host not found")
       end
    end

    return res
end

-- ##############################################

-- @brief Parses and validates a severity id string and returns it as a number
-- @param minimum_severity_id_string An string with an integer severity id as found in `alert_severities`
-- @return A valid integer severity id or nil when validation fails
function recipients_rest_utils.parse_minimum_severity(minimum_severity_id_string)
   local minimum_severity_id = tonumber(minimum_severity_id_string)

   for _, alert_severity in pairs(alert_severities) do
      if minimum_severity_id == alert_severity.severity_id then
	 return minimum_severity_id
      end
   end

   return nil
 end

-- ##############################################

return recipients_rest_utils
