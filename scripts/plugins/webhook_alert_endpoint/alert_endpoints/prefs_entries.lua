--
-- (C) 2019 - ntop.org
--

return {
  endpoint_key = "webhook",
  entries = {
    toggle_webhook_notification = {
      title       = i18n("prefs.toggle_webhook_notification_title"),
      description = i18n("prefs.toggle_webhook_notification_description"),
    }, webhook_notification_severity_preference = {
      title       = i18n("prefs.webhook_notification_severity_preference_title"),
      description = i18n("prefs.webhook_notification_severity_preference_description"),
    }, webhook_url = {
      title       = i18n("prefs.webhook_url_title"),
      description = i18n("prefs.webhook_url_description"),
    }, webhook_sharedsecret = {
      title       = i18n("prefs.webhook_sharedsecret_title"),
      description = i18n("prefs.webhook_sharedsecret_description"),
    }, webhook_username = {
      title       = i18n("login.username"),
      description = i18n("prefs.webhook_username_description"),
    }, webhook_password = {
      title       = i18n("login.password"),
      description = i18n("prefs.webhook_password_description"),
    }
  }
}
