--
-- (C) 2021 - ntop.org
--
-- This file contains the alert severity constants

local dirs = ntop.getDirs()

-- ################################################################################

-- Emoji Unicode Icons
-- https://apps.timwhitlock.info/emoji/tables/unicode
-- https://www.unicode.org/emoji/charts/full-emoji-list.html

-- Alerts (Keep severity_id in sync with ntop_typedefs.h AlertLevel)
-- each table entry is an array as:
-- {"alert html string", "alert C enum value", "plain string", "syslog severity"}
local alert_severities = {
   debug = {
      severity_id = 1,
      label = "bg-info",
      icon = "fas fa-fw fa-bug text-info",
      color = "#a8e4ef",
      i18n_title = "alerts_dashboard.debug",
      syslog_severity = 7,
      emoji = "\xE2\x84\xB9"
   },
   info = {
      severity_id = 2,
      label = "bg-info",
      icon = "fas fa-fw fa-info-circle text-info",
      color = "#c1f0c1",
      i18n_title = "alerts_dashboard.info",
      syslog_severity = 6,
      used_by_alerts = true,
      emoji = "\xE2\x84\xB9"
   },
   notice = {
      severity_id = 3,
      label = "bg-info",
      icon = "fas fa-fw fa-hand-paper text-primary",
      color = "#5cd65c",
      i18n_title = "alerts_dashboard.notice",
      syslog_severity = 5,
      used_by_alerts = true,
      emoji = "\xE2\x84\xB9"
   },
   warning = {
      severity_id = 4,
      label = "bg-warning",
      icon = "fas fa-fw fa-exclamation-triangle text-warning",
      color = "#ffc007",
      i18n_title = "alerts_dashboard.warning",
      syslog_severity = 4,
      used_by_alerts = true,
      emoji = "\xE2\x9A\xA0"
   },
   error = {
      severity_id = 5,
      label = "bg-danger",
      icon = "fas fa-fw fa-exclamation-triangle text-danger",
      color = "#ff3231",
      i18n_title = "alerts_dashboard.error",
      syslog_severity = 3,
      used_by_alerts = true,
      emoji = "\xE2\x9D\x97"
   },
   critical = {
      severity_id = 6,
      label = "bg-danger",
      icon = "fas fa-fw fa-exclamation-triangle text-danger",
      color = "#fb6962",
      i18n_title = "alerts_dashboard.critical",
      syslog_severity = 2,
      emoji = "\xE2\x9D\x97"
   },
   alert = {
      severity_id = 7,
      label = "bg-danger",
      icon = "fas fa-fw fa-bomb text-danger",
      color = "#fb6962",
      i18n_title = "alerts_dashboard.alert",
      syslog_severity = 1,
      emoji = "\xF0\x9F\x9A\xA9"
   },
   emergency = {
      severity_id = 8,
      label = "bg-danger text-danger",
      icon = "fas fa-fw fa-bomb",
      color = "#fb6962",
      i18n_title = "alerts_dashboard.emergency",
      syslog_severity = 0,
      emoji = "\xF0\x9F\x9A\xA9"
   }
}

-- ################################################################################

return alert_severities
