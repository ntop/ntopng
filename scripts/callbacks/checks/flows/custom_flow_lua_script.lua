
function flow_key()
   return "[ ".. flow.protocol() .. " ]" .. flow.cli() .. ":" .. flow.cli_port() .. " <-> ".. flow.srv() .. ":" .. flow.srv_port()
end

-- Trigger an alert for flows on port 53
if(flow.srv_port() == 53) then
   io.write(flow_key() .. " [bytes: ".. flow.bytes().."]\n")
   flow.triggerAlert(flow.cli_port(), "dummy alert message [".. flow_key() .."]")
end

-- IMPORTANT: do not forget this return at the end of the script
return(0)
