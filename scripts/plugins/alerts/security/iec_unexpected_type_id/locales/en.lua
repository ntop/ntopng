--
-- (C) 2020 - ntop.org
--

return {
   iec104_description = "Trigger an alert when an unexpected TypeID is detected in IEC 104 protocol",
   iec104_title = "IEC Unexpected TypeID",
   -- #######################
   iec104_alert_title = "Invalid IEC Transition",
   iec104_alert_format = "Invalid transition detected [%{from} -> %{to}]",
   -- #######################
   title = "Allowed TypeIDs",
   description = "Comma separated values of IEC 60870-5-104 TypeIDs. Example: 1,2,3,4",
}
