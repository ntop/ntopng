--
-- (C) 2017-18 - ntop.org
--

--
-- https://www.internetsociety.org/resources/doc/2016/overview-of-the-digital-object-architecture-doa/
-- https://tools.ietf.org/id/draft-durand-object-exchange-00.html
--
-- Update DNS with command
-- nsupdate -k Kntop.org.+157+16148.private -v /tmp/ox.update
--

local base64 = require "base64"

local ox = {}

local function initOX(path)
   return(io.open(path, "w"))
end
ox.init = initOX

local function printOXHeader(fd)
   fd:write("server localhost\n")
   fd:write("zone ntop.org.\n")
end
ox.header = printOXHeader

local function printOXFooter(fd)
   fd:write("send\n")
end
ox.footer = printOXFooter

local function device2OX(fd, dev)
   -- update add FE5400577C58.ntop.org.  3600 IN  OX   35632 1  1    "text/plain"  c2FtcGxlIERPQSB0ZXh0IHJlY29yZA==
   local mac = dev.mac:gsub(":", "")
   local base_string = "update add ".. mac ..".ntop.org 3600 IN OX 35632 "
   local v

   -- Delete record first
   fd:write("update delete ".. mac ..".ntop.org. OX\n")
  
   -- 101 - Operating System
   if(dev.operatingSystem ~= nil) then
      fd:write(base_string.."101 1 \"text/plain\" "..base64.enc(dev.operatingSystem).."\n")
   end

   -- 102 - Device Type
   if(dev.device_type ~= nil) then
      fd:write(base_string.."102 1 \"text/plain\" "..base64.enc(dev.device_type).."\n")
   end
   
   -- 103 - Device (Symbolic) Name
   if(dev.sym ~= nil) then
      v = dev.sym
   elseif(dev.symIP ~= nil) then
      v = dev.symIP
   else
      v = nil
   end
   if(v ~= nil) then
      fd:write(base_string.."103 1 \"text/plain\" "..base64.enc(v).."\n")
   end

   -- 104 - Provided services (SSDP)
   if(dev.information ~= nil) then
      v = table.concat(dev.information, ",")
      if(v ~= "") then
	 fd:write(base_string.."104 1 \"text/plain\" "..base64.enc(table.concat(dev.information, ",")).."\n")
      end
   end
   
   -- 105 - Description
   if((dev.device_info ~= nil) and (dev.device_info ~= "")) then
      -- io.write("=========> [device_info] "..dev.device_info.."\n")
      fd:write(base_string.."105 2 \"text/plain\" "..base64.enc(dev.device_info).."\n")
   end

   -- 106 - (SSDP) URL
   if(dev.url ~= nil) then
      fd:write(base_string.."106 2 \"text/plain\" "..base64.enc(dev.url).."\n")
   end
end
ox.device2OX = device2OX

local function termOX(fd)
   fd:close()
end
ox.term = termOX

return ox

