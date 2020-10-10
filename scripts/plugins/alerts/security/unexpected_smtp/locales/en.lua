--
-- (C) 2020 - ntop.org
--

return {
   unexpected_smtp_description = "Trigger an alert when not allowed SMTP server is detected",
   unexpected_smtp_title = "Unexpected SMTP server",

-- ####################### Input builder strings

   title = "Allowed SMTP servers",
   description = "Comma separated values of SMTP servers IPs. Example: 173.194.76.109,52.97.232.242",

-- ####################### Status strings

    status_unexpected_smtp_description = "Unexpected SMTP server found:",

-- ####################### Alert strings

   alert_unexpected_smtp_title = "Unexpected SMTP server found"
}
