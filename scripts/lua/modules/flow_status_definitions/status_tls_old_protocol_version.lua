--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatStatus(flowstatus_info)
  local msg = i18n("flow_details.tls_old_protocol_version")

  if(flowstatus_info and flowstatus_info.tls_version) then
    local ver_str = ntop.getTLSVersionName(flowstatus_info.tls_version)

    if(ver_str == nil) then
      ver_str = string.format("%u", flowstatus_info.tls_version)
    end

    msg = msg .. " (" .. ver_str .. ")"
  end

  return(msg)
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_tls_old_protocol_version,
  alert_type = alert_consts.alert_types.alert_potentially_dangerous_protocol,
  i18n_title = "flow_details.tls_old_protocol_version",
  i18n_description = formatStatus,
}
