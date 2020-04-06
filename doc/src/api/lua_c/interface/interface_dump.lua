--! @brief Starts a live packet capture from the selected interface.
--! @param host host/host@vlan to restrict capture only to the selected host. If nil, all interface traffic will be captured
--! @return Success, or nil in case of failure.
function interface.liveCapture(string host)

--! @brief Dump active live captures for the specified web user
--! @return table containing live captures for the specified user
function interface.dumpLiveCaptures()
