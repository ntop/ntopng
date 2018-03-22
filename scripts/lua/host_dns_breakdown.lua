--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)

host_info = url2hostinfo(_GET)
mode = _GET["direction"]

if(mode == "sent") then
   what = "sent"
else
   what = "rcvd"
end

host = interface.getHostInfo(host_info["host"],host_info["vlan"])

left = 0

print "[\n"

--for k,v in pairs(host["dns"][what]) do
--   print(k.."="..v.."<br>\n")
--end

if(host ~= nil) then
   tot = host["dns"][what]["queries"]["num_a"] + host["dns"][what]["queries"]["num_ns"] + host["dns"][what]["queries"]["num_cname"] + host["dns"][what]["queries"]["num_soa"] + host["dns"][what]["queries"]["num_ptr"] + host["dns"][what]["queries"]["num_mx"]  + host["dns"][what]["queries"]["num_txt"] + host["dns"][what]["queries"]["num_aaaa"] + host["dns"][what]["queries"]["num_any"]
   
   if(tot > 0) then
      min = (tot * 3)/100
      comma = ""

      if(host["dns"][what]["queries"]["num_a"] > min) then 
	 print('\t { "label": "A", "value": '.. host["dns"][what]["queries"]["num_a"] .. '}\n')
	 comma = "," 
      else 
	 left = left + host["dns"][what]["queries"]["num_a"]
      end

      if(host["dns"][what]["queries"]["num_ns"] > min) then
	 print(comma..'\t { "label": "NS", "value": '.. host["dns"][what]["queries"]["num_ns"] .. '}\n')
	 comma = "," 
      else
	 left = left + host["dns"][what]["queries"]["num_ns"]
      end

      if(host["dns"][what]["queries"]["num_cname"] > min) then
	 print(comma..'\t { "label": "CNAME", "value": '.. host["dns"][what]["queries"]["num_cname"] .. '}\n') 
	 comma = "," 
      else
	 left = left + host["dns"][what]["queries"]["num_cname"] 
      end

      if(host["dns"][what]["queries"]["num_soa"] > min) then
	 print(comma..'\t { "label": "SOA", "value": '.. host["dns"][what]["queries"]["num_soa"] .. '}\n') 
	 comma = "," 
      else
	 left = left + host["dns"][what]["queries"]["num_soa"] 
      end

      if(host["dns"][what]["queries"]["num_ptr"] > min) then
	 print(comma..'\t { "label": "PTR", "value": '.. host["dns"][what]["queries"]["num_ptr"] .. '}\n') 
	 comma = "," 
      else
	 left = left + host["dns"][what]["queries"]["num_ptr"]
      end

      if(host["dns"][what]["queries"]["num_mx"] > min) then
	 print(comma..'\t { "label": "MX", "value": '.. host["dns"][what]["queries"]["num_mx"] .. '}\n') 
	 comma = "," 
      else
	 left = left + host["dns"][what]["queries"]["num_mx"] 
      end

      if(host["dns"][what]["queries"]["num_txt"] > min) then
	 print(comma..'\t { "label": "TXT", "value": '.. host["dns"][what]["queries"]["num_txt"] .. '}\n')
	 comma = "," 
      else
	 left = left + host["dns"][what]["queries"]["num_txt"]
      end

      if(host["dns"][what]["queries"]["num_aaaa"] > min) then
	 print(comma..'\t { "label": "AAAA", "value": '.. host["dns"][what]["queries"]["num_aaaa"] .. '}\n') 
	 comma = "," 
      else
	 left = left + host["dns"][what]["queries"]["num_aaaa"]
      end

      if(host["dns"][what]["queries"]["num_any"] > min) then
	 print(comma..'\t { "label": "ANY", "value": '.. host["dns"][what]["queries"]["num_any"] .. '}\n') 
	 comma = "," 
      else
	 left = left + host["dns"][what]["queries"]["num_any"] 
      end
      
      other = host["dns"][what]["queries"]["num_other"] + left
      if(other > 0) then print(comma..'\t { "label": "Other", "value": '.. other .. '}\n') 
      end
   end
end
	 
print "\n]"




