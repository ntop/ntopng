--
-- (C) 2019 - ntop.org
--

return {
  endpoint_key = "slack",
  entries = {
    toggle_slack_notification = {
      title       = i18n("prefs.toggle_slack_notification_title", {url="http://www.slack.com"}),
      description = i18n("prefs.toggle_slack_notification_description", {url="https://github.com/ntop/ntopng/blob/dev/doc/README.slack"}),
    }, sender_username = {
      title       = i18n("prefs.sender_username_title"),
      description = i18n("prefs.sender_username_description"),
    }, slack_webhook = {
      title       = i18n("prefs.slack_webhook_title"),
      description = i18n("prefs.slack_webhook_description"),
    },
  }
}
