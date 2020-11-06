--
-- (C) 2020 - ntop.org
--

return {
   zero_tcp_window_description = "Trigger an alert when a flow TCP window is zero",
   zero_tcp_window_title = "Zero TCP Window",

-- ####################### Status strings

   status_zero_tcp_window_description     = "Reported TCP window zero value for ",
   status_zero_tcp_window_description_c2s = "Reported client TCP window zero value for ",
   status_zero_tcp_window_description_sec = "Reported server TCP window zero value for ",

-- ####################### Alert strings

   status_zero_tcp_window_title = "Reported TCP window zero value"
}
