--! @brief Get the status bitmap of the flow
--! @return the flow status bitmap
function flow.getStatus()

--! @brief Set a bit into the flow status
--! @param status_bit the status bit to set, see flow_consts.lua
--! @note This is used to indicate that the Flow has a possible problem.
function flow.setStatus(status_bit)

--! @brief Clear a bit into the flow status
--! @param status_bit the status bit to clear, see flow_consts.lua
function flow.clearStatus(status_bit)

--! @brief Sets a bit into the flow status and possibly trigger an alert
--! @param status_bit the flow status bit to set
--! @param alert_json an optional string message or json to store into the alert
--! @note An alert will be triggered only for the status with the highest priority
function flow.triggerStatus(status_bit, alert_json = nil)

--! @brief Check if the flow is blacklisted
--! @return true if blacklisted, false otherwise
function flow.isBlacklistedFlow()

--! @brief Get basic flow information.
--! @return table:<br>
--! cli.ip: the client IP address<br>
--! srv.ip: the server IP address<br>
--! cli.port: the client port<br>
--! srv.port: the server port<br>
--! proto.l4: the L4 protocol name (e.g. TCP)<br>
--! proto.ndpi: the nDPI L7 protocol name (e.g. HTTP)<br>
--! proto.ndpi_cat: the nDPI category name (e.g. Web)<br>
--! cli2srv.bytes: client-to-server bytes<br>
--! srv2cli.bytes: server-to-client bytes<br>
--! cli2srv.packets: client-to-server packets<br>
--! srv2cli.packets: server-to-client packets
function flow.getInfo()

--! @brief Get full information about the flow.
--! @return a table with flow information, see Flow::lua
--! @note This call is expensive and should be avoided. See flow.getInfo()
function flow.getFullInfo()

--! @brief Check if flow hosts are unicast or broadcast/multicast.
--! @return table:<br>
--! cli.broadmulticast: true if the client is broadcast/multicast<br>
--! srv.broadmulticast: true if the server is broadcast/multicast
function flow.getUnicastInfo()
