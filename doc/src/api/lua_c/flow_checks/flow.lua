--! @brief Get the complete status bitmap of the flow, which includes all the current problems of the flow.
--! @return the flow status bitmap
function flow.getStatus()

--! @brief Set a bit into the flow status bitmap, effectively marking the flow as misbehaving.
--! @param flow_status_type the flow status to set. The possible values can be obtained by printing `flow_consts.status_types`
--! @param flow_score the score (a quantitative indicator of the problem) to associate to this status
--! @param cli_score the score increment on the client host.
--! @param srv_score the score increment on the server host.
--! @return true if the flow status was updated, false if the flow status is unchanged.
function flow.setStatus(table flow_status_type, int flow_score, int cli_score, int srv_score)

--! @brief Clear a bit into the flow status bitmap.
--! @param flow_status_type the flow status to clear. The possible values can be obtained by printing `flow_consts.status_types`
function flow.clearStatus(table flow_status_type)

--! @brief Set a bit into the flow status bitmap, and trigger an alert.
--! @param flow_status_type the flow status to set. The possible values can be obtained by printing `flow_consts.status_types`
--! @param status_info a string message or lua table to associate to this status
--! @param flow_score the score (a quantitative indicator of the problem) to associate to this status
--! @param cli_score the score increment on the client host.
--! @param srv_score the score increment on the server host.
function flow.triggerStatus(table flow_status_type, table status_info, int flow_score, int cli_score, int srv_score)

--! @brief Check if a a bit into the flow status bitmap is set
--! @param status_key the numberic ID of the status, e.g. `flow_consts.status_types.status_blacklisted.status_key`
--! @return true if the provided status is set, false otherwise
function flow.isStatusSet(int status_key)

--! @brief Get full information about the flow.
--! @return a table with flow information, see Flow::lua
--! @note This call is expensive and should be avoided. Use the other API methods when possible.
function flow.getFullInfo()

--! @brief Check if the client of the flow is a unicast IP address.
--! @return true if the client is unicast, false otherwise
function flow.isClientUnicast()

--! @brief Check if the server of the flow is a unicast IP address.
--! @return true if the server is unicast, false otherwise
function flow.isServerUnicast()

--! @brief Check if both the client and the server of the flow are unicast IP addresses.
--! @return true if the flow is unicast, false otherwise
function flow.isUnicast()

--! @brief Check if both the client and the server are remote hosts.
--! @return true if the flow is remote to remote, false otherwise
function flow.isRemoteToRemote()

--! @brief Check if the client is a local host and the server is a remote host.
--! @return true if the flow is local to remote, false otherwise
function flow.isLocalToRemote()

--! @brief Check if the client is a remote host and the server is a local host.
--! @return true if the flow is remote to local, false otherwise
function flow.isRemoteToLocal()

--! @brief Check if both the client and the server are local hosts.
--! @return true if the flow is local, false otherwise
function flow.isLocal()

--! @brief Check if the flow is blacklisted
--! @return true if blacklisted, false otherwise
function flow.isBlacklisted()

--! @brief Check if the flow is TCP and the three way handshake is completed.
--! @return true if the flow is TCP and the 3WH is completed, false otherwise
function flow.isTwhOK()

--! @brief Check if the flow has seen packets in both the directions.
--! @return true if the flow is bidirectional, false otherwise
function flow.isBidirectional()

--! @brief Get the unique flow key.
--! @return the unique flow key.
function flow.getKey()

--! @brief Get the flow start Unix timestamp.
--! @return the flow first seen.
function flow.getFirstSeen()

--! @brief Get the Unix timestamp of the last time traffic for the flow was seen.
--! @return the flow last seen.
function flow.getLastSeen()

--! @brief Get the total duration in seconds of the flow.
--! @return the flow duration.
function flow.getDuration()

--! @brief Get the client to server packets sent.
--! @return the packets sent.
function flow.getPacketsSent()

--! @brief Get the client to server packets received.
--! @return the packets received.
function flow.getPacketsRcvd()

--! @brief Get the total packets seen for the flow.
--! @return the total flow packets.
function flow.getPackets()

--! @brief Get the client to server bytes sent.
--! @return the bytes sent.
function flow.getBytesSent()

--! @brief Get the client to server bytes received.
--! @return the bytes received.
function flow.getBytesRcvd()

--! @brief Get the total bytes seen for the flow.
--! @return the total flow bytes.
function flow.getBytes()

--! @brief Get the total goodput bytes seen for the flow.
--! @return the total goodput flow bytes.
function flow.getGoodputBytes()

--! @brief Get the unique key of the client.
--! @return the client key.
function flow.getClientKey()

--! @brief Get the unique key of the server.
--! @return the server key.
function flow.getServerKey()

--! @brief Get the detected nDPI category name of the flow.
--! @return the flow nDPI category name.
function flow.getnDPICategoryName()

--! @brief Get the detected nDPI protocol name of the flow.
--! @return the flow nDPI protocol name.
function flow.getnDPIProtocolName()

--! @brief Get the detected nDPI category ID of the flow.
--! @return the flow nDPI category ID.
function flow.getnDPICategoryId()

--! @brief Get the detected nDPI master protocol ID of the flow.
--! @return the flow nDPI master protocol ID.
function flow.getnDPIMasterProtoId()

--! @brief Get the detected nDPI application protocol ID of the flow.
--! @return the flow nDPI application protocol ID.
function flow.getnDPIAppProtoId()

--! @brief Get the DNS query of the flow.
--! @return the flow DNS query if found, an empty string otherwise.
function flow.getDnsQuery()

--! @brief Get the client country code.
--! @return the client country code if detected, nil otherwise.
function flow.getClientCountry()

--! @brief Get the server country code.
--! @return the server country code if detected, nil otherwise.
function flow.getServerCountry()

--! @brief Get the TLS version as number.
--! @return the TLS version number if detected, 0 otherwise.
function flow.getTLSVersion()

--! @brief Get the nDPI matching packet 
--! @return the lenght and payload of the packet matching nDPI
function flow.getnDPIMatchPacket()

--! @brief Get the total flow score (see flow.setStatus).
--! @return the flow score.
function flow.getScore()

--! @brief Check if the flow traffic is not blocked.
--! @return true if the flow traffic is not blocked, false otherwise.
--! @note This requires nEdge.
function flow.isPassVerdict()
