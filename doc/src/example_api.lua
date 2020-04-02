--! @brief This is an API function
--! @param first the first int parameter of the function
--! @param second the second string parameter of the function
--! @param third the third optional parameter of the function
--! @return table<br>
--! one: First field<br>
--! secondo: Second field<br>
--! @note An additional note
function interface.dropFlowTraffic(int first, string second, table third=nil)

function flow.getInfo()
---! @brief Get basic flow information.
---! @return table:<br>
---! cli.ip: the client IP address<br>
---! srv.ip: the server IP address<br>
---! cli.port: the client port<br>
---! srv.port: the server port<br>
---! proto.l4: the L4 protocol name (e.g. TCP)<br>
---! proto.ndpi: the nDPI L7 protocol name (e.g. HTTP)<br>
---! proto.ndpi_cat: the nDPI category name (e.g. Web)<br>
---! cli2srv.bytes: client-to-server bytes<br>
---! srv2cli.bytes: server-to-client bytes<br>
---! cli2srv.packets: client-to-server packets<br>
---! srv2cli.packets: server-to-client packets
