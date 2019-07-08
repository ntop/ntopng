--
-- (C) 2019 - ntop.org
--

-- #################################################################

local function cached_val_key(metric_name, granularity)
   return string.format("%s:%s", metric_name, granularity)
end

-- #################################################################

local function delta_val(metric_name, granularity, curr_val)
   local key = cached_val_key(metric_name, granularity)

   -- Read cached value and purify it
   local prev_val = interface.getCachedAlertValue(key)
   prev_val = tonumber(prev_val) or 0

   -- Save the value for the next round
   interface.setCachedAlertValue(key, tostring(curr_val))

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

function active_local_hosts(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["stats"]["local_hosts"])
end

-- #################################################################

function bytes(metric_name, info, granularity)
  return delta_val(metric_name, granularity, info["stats"]["bytes"])
end

-- #################################################################

function dns(metric_name, info, granularity)
   return delta_val(metric_name, granularity, application_bytes(info, "DNS"))
end

-- #################################################################

function idle(metric_name, info, granularity)
   return delta_val(metric_name, granularity, os.time() - info["seen.last"])
end

-- #################################################################

function p2p(metric_name, info, granularity)
   local tot_p2p = application_bytes(info, "eDonkey") + application_bytes(info, "BitTorrent") + application_bytes(info, "Skype")

   return delta_val(metric_name, granularity, tot_p2p)
end

-- #################################################################

function packets(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["stats"]["packets"])
end

-- #################################################################

function throughput(metric_name, info, granularity)
   local duration = granularity2sec(granularity)

   return delta_val(metric_name, granularity, info["stats"]["bytes"]) * 8 / duration
end
