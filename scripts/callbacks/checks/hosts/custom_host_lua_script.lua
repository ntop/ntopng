

if(false) then
   io.write("Hello ".. host.ip() .. " [custom_host_lua_script.lua]\n")
   
   local score   = 100
   local message = "dummy host alert message"
   
   host.triggerAlert(score, message)
end

-- IMPORTANT: do not forget this return at the end of the script
return(0)
