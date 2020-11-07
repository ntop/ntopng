--
-- (C) 2020 - ntop.org
--

return {
   zero_tcp_window_description = "Emette un allarme quando la TCP window di un flusso ha dimensione zero",
   zero_tcp_window_title = "TCP Window Zero",

-- ####################### Status strings

   status_zero_tcp_window_description     = "La TCP window è zero",
   status_zero_tcp_window_description_c2s = "La TCP window del client è zero",
   status_zero_tcp_window_description_s2c = "La TCP window del server è zero",

-- ####################### Alert strings

   alert_zero_tcp_window_title = "TCP Window Zero",
   alert_zero_tcp_window_description = "La TCP Window è Zero",
}
