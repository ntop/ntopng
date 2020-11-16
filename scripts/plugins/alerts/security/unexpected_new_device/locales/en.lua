--
-- (C) 2020 - ntop.org
--

return {
   unexpected_new_device_title = "Unexpected Device Connected",
   unexpected_new_device_description = "Trigger an alert first time an unexpected (i.e. not part of the allowed MAC addresses list) device connects to the network.",

   -- ####################### Input builder strings

   description = "Comma separated values of allowed MAC Addresses. Example: FF:FF:FF:FF:FF:FF",
   title = "Allowed MAC Addresses",

   -- ####################### Status strings

   status_unexpected_new_device_description = "Unexpected MAC address device <a href=\"%{host_url}\">%{mac_address}</a> connected to the network.",
   status_unexpected_new_device_description_pro = "Unexpected MAC address device <a href=\"%{host_url}\">%{mac_address}</a> connected to the network. SNMP Device <a href=\"%{ip_url}\">%{ip}</a> on Port <a href=\"%{port_url}\">%{port}</a> <span class='badge badge-secondary'>%{interface_name}</span>",

   -- ####################### Alert strings

   alert_unexpected_new_device_title = "Unexpected Device Connected"
}
