
function flow_key()
   return "[ ".. flow.protocol() .. " ]" .. flow.cli() .. ":" .. flow.cli_port() .. " <-> ".. flow.srv() .. ":" .. flow.srv_port()
end

-- Triggers a demo alert for flows on port 53
if(flow.srv_port() == 53) then
   -- io.write(flow_key() .. " [bytes: ".. flow.bytes().."]\n")
   local value   = flow.cli_port()
   local message = "dummy alert message"

   flow.triggerAlert(value, message)
end

-- IMPORTANT: do not forget this return at the end of the script
return(0)
