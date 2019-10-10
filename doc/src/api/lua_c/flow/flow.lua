--! @brief Get the status of the flow
--! @return table:<br>
--! flow.status: the most relevant flow status, see flow_consts.lua<br>
--! flow.idle: true if the flow is idle<br>
--! status_map: the flow status bitmap
function flow.getStatus()

--! @brief Get the Layer-4 and the Layer-7 protocols
--! @return table:<br>
--! proto.ndpi_id: the L7 nDPI protocol ID<br>
--! proto.ndpi_breed: the nDPI protocol breed (e.g. Acceptable)<br>
--! proto.l4: the L4 protocol name (e.g. TCP)<br>
--! proto.ndpi_cat: the nDPI category name (e.g. Web)<br>
--! proto.ndpi_cat_id: the nDPI category ID<br>
--! proto.ndpi: the nDPI L7 protocol name (e.g. HTTP)<br>
function flow.getProtocols()
