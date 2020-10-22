--
-- (C) 2020 - ntop.org
--

return {
   description = "Trigger alerts when an IP address, previously seen with a MAC address, is now seen with another MAC address. This alert might indicate an ARP spoof attempt. Only works for the builtin alert recipient.", -- 
   title = "IP Reassignment",
}
