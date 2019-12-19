--
-- (C) 2019 - ntop.org
--

return {
  endpoint_key = "syslog",
  entries = {
    syslog_alert_format = {
      title       = i18n("prefs.syslog_alert_format_title"),
      description = i18n("prefs.syslog_alert_format_description"),
    }, toggle_alert_syslog = {
      title       = i18n("prefs.toggle_alert_syslog_title"),
      description = i18n("prefs.toggle_alert_syslog_description"),
    }
  }
}
