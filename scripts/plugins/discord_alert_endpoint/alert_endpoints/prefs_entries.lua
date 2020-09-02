--
-- (C) 2020 - ntop.org
--

return {
  endpoint_key = "discord",
  entries = {
    toggle_discord_notification = {
      title       = i18n("prefs.toggle_discord_notification_title"),
      description = i18n("prefs.toggle_discord_notification_description"),
    }, discord_url = {
      title       = i18n("prefs.discord_url_title"),
      description = i18n("prefs.discord_url_description"),
    }, discord_sender = {
      title       = i18n("prefs.discord_sender_title"),
      description = i18n("prefs.discord_sender_description"),
    }
  }
}
