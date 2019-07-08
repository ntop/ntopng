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
   local prev_val = host.getCachedAlertValue(key, granularity_num)
   prev_val = tonumber(prev_val) or 0
   -- Save the value for the next round
   host.setCachedAlertValue(key, tostring(curr_val), granularity_num)

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

function check.active(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, info["total_activity_time"])
end

-- #################################################################

function check.bytes(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, info["bytes.sent"] + info["bytes.rcvd"])
end

-- #################################################################

function check.packets(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, info["packets.sent"] + info["packets.rcvd"])
end

-- #################################################################

function check.flows(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, info["total_flows.as_client"] + info["total_flows.as_server"])
end

-- #################################################################

function check.idle(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, os.time() - info["seen.last"])
end

-- #################################################################

function check.dns(metric_name, info, granularity, granularity_num)
   return delta_val(metric_name, granularity_num, application_bytes(info, "DNS"))
end

-- #################################################################

function check.p2p(metric_name, info, granularity, granularity_num)
   local tot_p2p = application_bytes(info, "eDonkey") + application_bytes(info, "BitTorrent") + application_bytes(info, "Skype")

   return delta_val(metric_name, granularity_num, tot_p2p)
end

-- #################################################################

function check.throughput(metric_name, info, granularity, granularity_num)
   local duration = granularity_num2sec(granularity_num)

   return delta_val(metric_name, granularity_num, info["bytes.sent"] + info["bytes.rcvd"]) * 8 / duration
end

-- #################################################################

return check
