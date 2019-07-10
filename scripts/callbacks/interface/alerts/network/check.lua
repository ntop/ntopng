--
-- (C) 2019 - ntop.org
--

local check = {}

-- #################################################################

local function cached_val_key(metric_name, granularity_num)
   return string.format("%s:%s", metric_name, granularity_num)
end

-- #################################################################

local function delta_val(metric_name, granularity_num, curr_val)
   local key = cached_val_key(metric_name, granularity_num)

   -- Read cached value and purify it
   local prev_val = network.getCachedAlertValue(key, granularity_num)
   prev_val = tonumber(prev_val) or 0

   -- Save the value for the next round
   network.setCachedAlertValue(key, tostring(curr_val), granularity_num)

   -- Compute the delta
   return curr_val - prev_val
end

-- #################################################################

function check.egress(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, info["egress"])
end

-- #################################################################

function check.ingress(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, info["ingress"])
end

-- #################################################################

function check.inner(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, info["inner"])
end

-- #################################################################

return check
