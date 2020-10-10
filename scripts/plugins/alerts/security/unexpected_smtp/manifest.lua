--
-- (C) 2019-20 - ntop.org
--

return {
  --[[ i18n function is currently not available in manifest.lua
    title = i18n("unexpected_smtp.unexpected_smtp_title"),
  description = i18n("unexpected_smtp.unexpected_smtp_description"), --]]
  
  title = "Unexpected SMTP server",
  description = "Trigger an alert when not allowed SMTP server is detected",
  author = "Daniele Zulberti, Luca Argentieri",
  dependencies = {},
}
