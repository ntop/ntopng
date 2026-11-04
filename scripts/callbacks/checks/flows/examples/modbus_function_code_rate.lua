--
-- (C) 2026 - ntop.org
--
-- Example custom flow script: copy it to /etc/ntopng/custom_checks/flows/ and adapt it.
--
-- Alert when a Modbus server receives a (custom) function code more often than allowed,
-- e.g. a proprietary command polled too frequently by a tampered client.
-- The function codes are dissected by ntopng (flow.ot().modbus.function_codes), so the flows
-- must be seen by ntopng on a packet interface or exported by nProbe with the Modbus plugin.
--

-- Function codes to watch (decimal, 65 = 0x41) and calls allowed per server per minute
local WATCHED = { [65] = true, [66] = true }
local MAX_PER_MINUTE = 100

-- Per flow: the counters already seen (function_codes are totals since the flow start),
-- removed when not updated for 10 minutes (the flow is gone)
local seen = {}
local calls = 0

local function forget_old_flows(now)
  for k, v in pairs(seen) do
    if now - v.when > 600 then seen[k] = nil end
  end
end

return {
  title = "Modbus custom function code rate",
  score = 100,
  hooks = { "periodic", "end" },
  filter = { l7_proto = "Modbus" },

  check = function(flow)
    local modbus = flow.ot().modbus
    if not modbus or not modbus.function_codes then return end

    local now = os.time()
    local flow_key = flow.cli() .. ":" .. flow.cli_port() .. "-" .. flow.srv() .. ":" .. flow.srv_port()
    local prev = seen[flow_key] and seen[flow_key].codes or {}

    calls = calls + 1
    if calls % 1000 == 0 then forget_old_flows(now) end

    for fc, total in pairs(modbus.function_codes) do
      local code = tonumber(fc)

      if WATCHED[code] then
        local delta = total - (prev[fc] or 0)

        if delta > 0 then
          -- Calls to this server in the current minute, from all its flows
          local calls = counter.inc(flow.srv() .. "/" .. fc, 60, delta)

          if calls > MAX_PER_MINUTE then
            flow.triggerAlert(string.format("Function code %d called %d times in the last minute on %s",
                                            code, calls, flow.srv()))
          end
        end
      end
    end

    seen[flow_key] = { codes = modbus.function_codes, when = now }
  end,
}
