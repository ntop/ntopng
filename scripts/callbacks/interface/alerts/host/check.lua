--
-- (C) 2019 - ntop.org
--

local check = {}

-- #################################################################

local function cached_val_key(metric_name, granularity)
   return string.format("%s:%s", metric_name, granularity)
end

-- #################################################################

local function delta_val(metric_name, granularity, curr_val)
   local key = cached_val_key(metric_name, granularity)

   -- Read cached value and purify it
   local prev_val = host.getCachedAlertValue(key)
   prev_val = tonumber(prev_val) or 0

   -- Save the value for the next round
   host.setCachedAlertValue(key, tostring(curr_val))

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

function check.active(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["total_activity_time"])
end

-- #################################################################

function check.bytes(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["bytes.sent"] + info["bytes.rcvd"])
end

-- #################################################################

function check.packets(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["packets.sent"] + info["packets.rcvd"])
end

-- #################################################################

function check.flows(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["total_flows.as_client"] + info["total_flows.as_server"])
end

-- #################################################################

function check.idle(metric_name, info, granularity)
   return delta_val(metric_name, granularity, os.time() - info["seen.last"])
end

-- #################################################################

function check.dns(metric_name, info, granularity)
   return delta_val(metric_name, granularity, application_bytes(info, "DNS"))
end

-- #################################################################

function check.p2p(metric_name, info, granularity)
   local tot_p2p = application_bytes(info, "eDonkey") + application_bytes(info, "BitTorrent") + application_bytes(info, "Skype")

   return delta_val(metric_name, granularity, tot_p2p)
end

-- #################################################################

function check.throughput(metric_name, info, granularity)
   local duration = granularity2sec(granularity)

   return delta_val(metric_name, granularity, info["bytes.sent"] + info["bytes.rcvd"]) * 8 / duration
end

-- #################################################################

return check
