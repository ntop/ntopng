--
-- (C) 2018 - ntop.org
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
      label = "badge-info",
      icon = "fas fa-bug text-info",
      -- color = "black",
      i18n_title = "alerts_dashboard.debug",
      syslog_severity = 7,
      emoji = "\xE2\x84\xB9"
   },
   info = {
      severity_id = 2,
      label = "badge-info",
      icon = "fas fa-info-circle text-info",
      -- color = "blue",
      i18n_title = "alerts_dashboard.info",
      syslog_severity = 6,
      emoji = "\xE2\x84\xB9"
   },
   notice = {
      severity_id = 3,
      label = "badge-info",
      icon = "fas fa-hand-paper text-primary",
      -- color = "blue",
      i18n_title = "alerts_dashboard.notice",
      syslog_severity = 5,
      emoji = "\xE2\x84\xB9"
   },
   warning = {
      severity_id = 4,
      label = "badge-warning",
      icon = "fas fa-exclamation-triangle text-warning",
      -- color = "gold",
      i18n_title = "alerts_dashboard.warning",
      syslog_severity = 4,
      emoji = "\xE2\x9A\xA0"
   },
   error = {
      severity_id = 5,
      label = "badge-danger",
      icon = "fas fa-exclamation-triangle text-danger",
      -- color = "red",
      i18n_title = "alerts_dashboard.error",
      syslog_severity = 3,
      emoji = "\xE2\x9D\x97"
   },
   critical = {
      severity_id = 6,
      label = "badge-danger",
      icon = "fas fa-exclamation-triangle text-danger",
      -- color = "purple",
      i18n_title = "alerts_dashboard.critical",
      syslog_severity = 2,
      emoji = "\xE2\x9D\x97"
   },
   alert = {
      severity_id = 7,
      label = "badge-danger",
      icon = "fas fa-bomb text-danger",
      -- color = "red",
      i18n_title = "alerts_dashboard.alert",
      syslog_severity = 1,
      emoji = "\xF0\x9F\x9A\xA9"
   },
   emergency = {
      severity_id = 8,
      label = "badge-danger text-danger",
      icon = "fas fa-bomb",
      -- color = "purple",
      i18n_title = "alerts_dashboard.emergency",
      syslog_severity = 0,
      emoji = "\xF0\x9F\x9A\xA9"
   }
}

-- ################################################################################

return alert_severities
