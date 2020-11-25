--
-- (C) 2020 - ntop.org
--

return {
   unexpected_ntp_description = "Trigger an alert when not allowed NTP server is detected",
   unexpected_ntp_title = "Unexpected NTP server",

-- ####################### Input builder strings

   title = "Allowed NTP servers",
   description = "Comma separated values of NTP servers IPs. Example: 173.194.76.109,52.97.232.242",

-- ####################### Status strings

    status_unexpected_ntp_description = "Unexpected NTP server found: %{server}",

-- ####################### Alert strings

   alert_unexpected_ntp_title = "Unexpected NTP server found"
}
