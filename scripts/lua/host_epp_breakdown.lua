--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

local epp_cmd_description = {
  [ 1 ] = "Domain-create",
  [ 2 ] = "Domain-update",
  [ 3 ] = "Domain-delete",
  [ 4 ] = "Domain-restore",
  [ 5 ] = "Domain-transfer",
  [ 6 ] = "Domain-transfer-trade",
  [ 7 ] = "Domain-transfer-request",
  [ 8 ] = "Domain-transfer-trade-request",
  [ 9 ] = "Domain-transfer-cancel",
  [ 10 ] = "Domain-transfer-approve",
  [ 11 ] = "Domain-transfer-reject",
  [ 12 ] = "Contact-create",
  [ 13 ] = "Contact-update",
  [ 14 ] = "Contact-delete",
  [ 15 ] = "Domain-update-hosts",
  [ 16 ] = "Domain-update-statuses",
  [ 17 ] = "Domain-update-contacts",
  [ 18 ] = "Domain-trade",
  [ 19 ] = "Domain-update-simple",
  [ 20 ] = "Domain-info",
  [ 21 ] = "Contact-info",
  [ 22 ] = "Domain-check",
  [ 23 ] = "Contact-check",
  [ 24 ] = "Poll-request",
  [ 25 ] = "Domain-transfer-trade-cancel",
  [ 26 ] = "Domain-transfer-trade-approve",
  [ 27 ] = "Domain-transfer-trade-reject",
  [ 28 ] = "Domain-transfer-query",
  [ 29 ] = "Login",
  [ 30 ] = "Login-change-pwd",
  [ 31 ] = "Logout",
  [ 32 ] = "Poll-ack",
  [ 33 ] = "Hello",
  [ 34 ] = "Unknown-command"
 }

interface.select(ifname)


host_info = url2hostinfo(_GET)
mode = _GET["mode"]

if(mode == "sent") then
   what = "sent"
else
   what = "rcvd"
end

host = interface.getHostInfo(host_info["host"],host_info["vlan"])

left = 0

print "[\n"

if(false) then
   for k,v in pairs(host["epp"][what]) do
      print(k.."="..v.."<br>\n")
   end
end

if(host ~= nil) then
   tot = 0

   for i=1,35 do 
      if(host["epp"][what]["num_cmd_"..i] ~= nil) then
	 tot = tot + host["epp"][what]["num_cmd_"..i]
      end
   end


   if(tot > 0) then
      min = (tot * 3)/100
      comma = ""

      for i=1,35 do 
	 n = host["epp"][what]["num_cmd_"..i]

	 if(n ~= nil) then 
	    if(n > min) then 
	       label = epp_cmd_description[i]
	       if(label == nil) then label = i end

	       print('\t '..comma..'{ "label": "'..label..'", "value": '.. n .. '}\n')
	       comma = "," 
	    else 
	       left = left + n
	    end
	 end
      end
            
      if(left > 0) then print(comma..'\t { "label": "Other", "value": '.. left .. '}\n') 
      end
   end
end
	 
print "\n]"




