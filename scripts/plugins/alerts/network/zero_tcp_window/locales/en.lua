--
-- (C) 2020 - ntop.org
--

return {
   zero_tcp_window_description = "Trigger an alert when a flow TCP window is zero",
   zero_tcp_window_title = "Zero TCP Window",

-- ####################### Status strings

   status_zero_tcp_window_description     = "Reported TCP Zero Window",
   status_zero_tcp_window_description_c2s = "Reported client TCP zero window",
   status_zero_tcp_window_description_sec = "Reported server TCP zero window ",

-- ####################### Alert strings

   alert_zero_tcp_window_title = "TCP Zero Window",
   alert_zero_tcp_window_description = "Reported TCP Zero Window",
}
