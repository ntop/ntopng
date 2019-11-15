--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

-- https://mozilla.github.io/python-nss-docs/nss.ssl-module.html
local code_2_version = {
    [2] = "2",
  [768] = "3.0",
  [769] = "TLS 1.0",
  [770] = "TLS 1.1",
  [771] = "TLS 1.2",
  [772] = "TLS 1.3",
}

-- #################################################################

local function formatStatus(status, flowstatus_info)
  local msg = i18n("flow_details.tls_old_protocol_version")

  if(flowstatus_info and flowstatus_info.tls_version) then
    local ver_str = code_2_version[flowstatus_info.tls_version]

    if(ver_str == nil) then
      ver_str = string.format("%u", flowstatus_info.tls_version)
    end

    msg = msg .. " (" .. ver_str .. ")"
  end

  return(msg)
end

-- #################################################################

return {
  status_id = 25,
  relevance = 30,
  prio = 470,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_potentially_dangerous_protocol,
  i18n_title = "flow_details.tls_old_protocol_version",
  i18n_description = formatStatus,
}
