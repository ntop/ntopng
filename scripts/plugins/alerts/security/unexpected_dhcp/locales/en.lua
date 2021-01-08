--
-- (C) 2020 - ntop.org
--

return {
   unexpected_dhcp_description = "Trigger an alert when not allowed DHCP server is detected",
   unexpected_dhcp_title = "Unexpected DHCP",

-- ####################### Input builder strings

   title = "Allowed DHCP",
   description = "Comma separated values of allowed DHCP IPs. Example: 192.168.1.1",

-- ####################### Status strings

    status_unexpected_dhcp_description = "Unexpected DHCP server found: %{server}",

-- ####################### Alert strings

   alert_unexpected_dhcp_title = "Unexpected DHCP found"
}
