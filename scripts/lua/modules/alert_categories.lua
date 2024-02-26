--
-- (C) 2021-24 - ntop.org
--

-- ##############################################

-- IMPORTANT keep it in sync with ntop_typedefs.h enum CheckCategory
local alert_categories = {
   other = {
      id = 0,
      icon = "fas fa-scroll",
      i18n_title = "checks.category_other",
      i18n_descr = "checks.category_other_descr"
   },
   security = {
      id = 1,
      icon = "fas fa-shield-alt",
      i18n_title = "checks.category_security",
      i18n_descr = "checks.category_security_descr"
   },
   internals = {
      id = 2,
      icon = "fas fa-wrench",
      i18n_title = "checks.category_internals",
      i18n_descr = "checks.category_internals_descr"
   },
   network = {
      id = 3,
      icon = "fas fa-network-wired",
      i18n_title = "checks.category_network",
      i18n_descr = "checks.category_network_descr"
   },
   system = {
      id = 4,
      icon = "fas fa-server",
      i18n_title = "checks.category_system",
      i18n_descr = "checks.category_system_descr"
   },
   ids_ips = {
      id = 5,
      icon = "fas fa-user-lock",
      i18n_title = "checks.category_ids_ips",
      i18n_descr = "checks.category_ids_ips_descr"
   },
   active_monitoring = {
      id = 6,
      icon = "fas fa-tachometer-alt",
      i18n_title = "checks.category_active_monitoring",
      i18n_descr = "checks.category_active_monitoring_descr"
   },
   snmp = {
      id = 7,
      icon = "fas fa-heartbeat",
      i18n_title = "checks.category_snmp",
      i18n_descr = "checks.category_snmp_descr"
   }
}

return alert_categories