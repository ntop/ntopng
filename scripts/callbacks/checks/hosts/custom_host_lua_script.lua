--
-- (C) 2013-22 - ntop.org
--

if(host.is_unicast()) then
   local as_client = host.getNumContactedPeersAsClientTCPNoTX()
   local as_server = host.getNumContactsFromPeersAsServerTCPNoTX()
   local num_server_ports = host.getNumContactedTCPServerPortsNoTX()

   if((as_client > 0) or (as_server > 0)) then
      io.write(
	 os.date("%d/%m/%Y %H:%M:%S")
	 .. " - " ..host.ip() .."\t"
	 .. " [TCP No TX Peer Contacts: (as client: ".. as_client ..")"
	 .. " (as server: ".. as_server ..")]"
	 .. " [Num Contacted Host Ports: ".. num_server_ports .."]"
	 .. "\n")
   end
end

-- IMPORTANT: do not forget this return at the end of the script
return(0)
