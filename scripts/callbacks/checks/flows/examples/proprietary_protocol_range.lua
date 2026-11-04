--
-- (C) 2026 - ntop.org
--
-- Example custom flow script: copy it to /etc/ntopng/custom_checks/flows/ and adapt it.
--
-- Alert when a proprietary protocol carries values outside the allowed range.
-- ntopng cannot read the payload of collected flows: an nProbe plugin extracts the fields of
-- the protocol and exports them with the flow, ntopng gives them to the script in flow.json_info().
-- The field names below (PROP_CMD, PROP_SETPOINT) are placeholders: use the names exported by
-- your plugin (print them once with: for k, v in pairs(flow.json_info()) do print(k, v) end).
--

local SETPOINT_MIN, SETPOINT_MAX = 0, 500
local ALLOWED_COMMANDS = { [1] = true, [2] = true, [7] = true }

return {
  title = "Proprietary protocol out of range",
  score = 120,
  hooks = { "periodic", "end" },
  -- The protocol port and the network of the devices
  filter = { srv_port = 20000, l4_proto = "TCP", ip = "10.10.0.0/16" },

  check = function(flow)
    local info = flow.json_info()
    local cmd = tonumber(info["PROP_CMD"])
    local setpoint = tonumber(info["PROP_SETPOINT"])

    if cmd and not ALLOWED_COMMANDS[cmd] then
      flow.triggerAlert("Unexpected command " .. cmd .. " to " .. flow.srv())
    elseif setpoint and (setpoint < SETPOINT_MIN or setpoint > SETPOINT_MAX) then
      flow.triggerAlert(string.format("Setpoint %s out of range [%d, %d] on %s",
                                      tostring(setpoint), SETPOINT_MIN, SETPOINT_MAX, flow.srv()))
    end
  end,
}
