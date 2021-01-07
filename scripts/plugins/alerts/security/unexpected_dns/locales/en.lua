--
-- (C) 2020 - ntop.org
--

return {
   unexpected_dns_description = "Trigger an alert when not allowed DNS server is detected",
   unexpected_dns_title = "Unexpected DNS",

-- ####################### Input builder strings

   title = "Allowed DNS",
   description = "Comma separated values of allowed DNS IPs. Example: 8.8.8.8,8.8.4.4,1.1.1.1",

-- ####################### Status strings

    status_unexpected_dns_description = "Unexpected DNS server found: %{server}",

-- ####################### Alert strings

   alert_unexpected_dns_title = "Unexpected DNS Server Found"
}
