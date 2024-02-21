--
-- (C) 2021-24 - ntop.org
--

-- ##############################################

-- IMPORTANT keep it in sync with ntop_typedefs.h enum CheckCategory
local alert_severity_groups = {
   group_none = {
      severity_group_id = 0,
      i18n_title = "severity_groups.group_none",
   },
   notice_or_lower = {
      severity_group_id = 1,
      i18n_title = "severity_groups.group_notice_or_lower",
   },
   warning = {
      severity_group_id = 2,
      i18n_title = "severity_groups.group_warning",
   },
   error = {
      severity_group_id = 3,
      i18n_title = "severity_groups.group_error",
   },
   critical = {
      severity_group_id = 4,
      i18n_title = "severity_groups.group_critical",
   },
   emergency = {
      severity_group_id = 5,
      i18n_title = "severity_groups.group_emergency",
   },
}

return alert_severity_groups