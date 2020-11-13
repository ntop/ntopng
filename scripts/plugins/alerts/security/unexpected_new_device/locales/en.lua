--
-- (C) 2020 - ntop.org
--

return {
   unexpected_new_device_title = "Unexpected Device Connected",
   unexpected_new_device_description = "Trigger an alert when an unexpected device connects to the network.",

   -- ####################### Input builder strings

   description = "Comma separated values of allowed MAC Addresses. Example: FF:FF:FF:FF:FF:FF", -- 
   title = "Allowed MAC Addresses",

   -- ####################### Status strings

   status_unexpected_new_device_description = "Unexpected mac address device <a href=\"%{url}\">%{device}</a> connected to the network.",
   status_unexpected_new_device_description_pro = "Unexpected mac address device <a href=\"%{url}\">%{device}</a> connected to the network. Snmp infos: <a href=\"" .. hostinfo2detailsurl(mac, {page = "snmp"}) .. "\">%{device}</a>",

   -- ####################### Alert strings

   alert_unexpected_new_device_title = "Unexpected Device Connected"
}
