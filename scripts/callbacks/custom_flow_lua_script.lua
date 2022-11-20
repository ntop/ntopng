
function flow_key()
   return "[ ".. flow.protocol() .. " ]" .. flow.cli() .. ":" .. flow.cli_port() .. " <-> ".. flow.srv() .. ":" .. flow.srv_port()
end

io.write(flow_key() .. " [bytes: ".. flow.bytes().."]\n")
return(0)
