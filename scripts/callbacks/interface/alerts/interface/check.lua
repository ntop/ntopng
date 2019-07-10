--
-- (C) 2019 - ntop.org
--

-- #################################################################

local function cached_val_key(metric_name, granularity_num)
   return string.format("%s:%s", metric_name, granularity_num)
end

-- #################################################################

local function delta_val(metric_name, granularity_num, curr_val)
   local key = cached_val_key(metric_name, granularity_num)

   -- Read cached value and purify it
   local prev_val = interface.getCachedAlertValue(key, granularity_num)
   prev_val = tonumber(prev_val) or 0

   -- Save the value for the next round
   interface.setCachedAlertValue(key, tostring(curr_val), granularity_num)

   -- Compute the delta
   return curr_val - prev_val
end

-- #################################################################

local function application_bytes(info, application_name)
   local curr_val = 0

   if info["ndpi"] and info["ndpi"][application_name] then
      curr_val = info["ndpi"][application_name]["bytes.sent"] + info["ndpi"][application_name]["bytes.rcvd"]
   end

   return curr_val
end

-- #################################################################

function active_local_hosts(metric_name, info, granularity, granularity_num)
   return(info["stats"]["local_hosts"])
end

-- #################################################################

function bytes(metric_name, info, granularity, granularity_num)
  return delta_val(metric_name, granularity_num, info["stats"]["bytes"])
end

-- #################################################################

function dns(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, application_bytes(info, "DNS"))
end

-- #################################################################

function idle(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, os.time() - info["seen.last"])
end

-- #################################################################

function p2p(metric_name, info, granularity, granularity_num)
   local tot_p2p = application_bytes(info, "eDonkey") + application_bytes(info, "BitTorrent") + application_bytes(info, "Skype")

   return delta_val(metric_name, granularity_num, tot_p2p)
end

-- #################################################################

function packets(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, info["stats"]["packets"])
end

-- #################################################################

function throughput(metric_name, info, granularity, granularity_num)
   local duration = granularity_num2sec(granularity_num)

   return delta_val(metric_name, granularity_num, info["stats"]["bytes"]) * 8 / duration
end
