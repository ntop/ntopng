--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_subtype A string with the subtype of the alert
-- @param pool The host pool structure
-- @param proto The Layer-7 application which exceeded the quota
-- @param value The latest measured value
-- @param quota The quota set
-- @return A table with the alert built
local function createPoolQuotaExceeded(alert_severity, alert_subtype, pool, proto, value, quota)
   local host_pools_utils = require("host_pools_utils")

   local built = {
      alert_subtype = alert_subtype,
      alert_severity = alert_severity,
      alert_type_params = {
	 pool = host_pools_utils.getPoolName(interface.getId(), pool),
	 proto = proto,
	 value = value,
	 quota = quota,
      },
   }

   return built
end

-- #######################################################

local function quotaExceededFormatter(ifid, alert, info)
  local quota_str
  local value_str
  local subject_str

  if alert.alert_subtype == "traffic_quota" then
    quota_str = bytesToSize(info.quota)
    value_str = bytesToSize(info.value)
    subject_str = i18n("alert_messages.proto_bytes_quotas", {proto=info.proto})
  else
    quota_str = secondsToTime(info.quota)
    value_str = secondsToTime(info.value)
    subject_str = i18n("alert_messages.proto_time_quotas", {proto=info.proto})
  end

  return(i18n("alert_messages.subject_quota_exceeded", {
    pool = info.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
    subject = subject_str,
    quota = quota_str,
    value = value_str
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_quota_exceeded,
  i18n_title = "alerts_dashboard.quota_exceeded",
  i18n_description = quotaExceededFormatter,
  icon = "fas fa-thermometer-full",
  creator = createPoolQuotaExceeded,
}
