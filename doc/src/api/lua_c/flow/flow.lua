--! @brief Check if the flow is blacklisted
--! @return true if blacklisted, false otherwise
function flow.isBlacklistedFlow()

--! @brief Get the status bitmap of the flow
--! @return the flow status bitmap
function flow.getStatus()

--! @brief Sets a bit into the flow status
--! @param status_bit the status bit to set, see flow_consts.lua
--! @notes This is used to indicate that the Flow has a possible problem.
function flow.addStatus(status_bit)

--! @brief Trigger an alert on the current flow
--! @param alerted_status the flow status which is causing the alert generation
--! @param alert_type the alert_id of the alert to generate (see alert_consts.alert_types)
--! @param alert_severity the severity_id of the alert to generate (see alert_consts.alert_types)
--! @notes alert_json an optional string message or json to store into the alert
function flow.triggerAlert(alerted_status, alert_type, alert_severity, alert_json = nil)

--! @brief Get the Layer-4 and the Layer-7 protocols
--! @return table:<br>
--! proto.ndpi_id: the L7 nDPI protocol ID<br>
--! proto.ndpi_breed: the nDPI protocol breed (e.g. Acceptable)<br>
--! proto.l4: the L4 protocol name (e.g. TCP)<br>
--! proto.ndpi_cat: the nDPI category name (e.g. Web)<br>
--! proto.ndpi_cat_id: the nDPI category ID<br>
--! proto.ndpi: the nDPI L7 protocol name (e.g. HTTP)<br>
function flow.getProtocols()
