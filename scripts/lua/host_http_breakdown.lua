--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)

host_info = url2hostinfo(_GET)
mode = _GET["http_mode"]

host = interface.getHostInfo(host_info["host"],host_info["vlan"])

left = 0

print "[\n"

--for k,v in pairs(host["dns"][what]) do
--   print(k.."="..v.."<br>\n")
--end

if(host ~= nil) then
   http = host.http
   if(http ~= nil) then
      if(mode == "queries") then
	 if(http["sender"]["query"]["total"] > 0) then
	    min = (http["sender"]["query"]["total"] * 3)/100
	    comma = ""

	    if(http["sender"]["query"]["num_get"] > min) then
	       print(comma..'\t { "label": "GET", "value": '.. http["sender"]["query"]["num_get"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["sender"]["query"]["num_get"]
	    end

	    if(http["sender"]["query"]["num_post"] > min) then
	       print(comma..'\t { "label": "POST", "value": '.. http["sender"]["query"]["num_post"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["sender"]["query"]["num_post"]
	    end

	    if(http["sender"]["query"]["num_head"] > min) then
	       print(comma..'\t { "label": "HEAD", "value": '.. http["sender"]["query"]["num_head"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["sender"]["query"]["num_head"]
	    end

	    if(http["sender"]["query"]["num_put"] > min) then
	       print(comma..'\t { "label": "PUT", "value": '.. http["sender"]["query"]["num_put"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["sender"]["query"]["num_put"]
	    end

	    if((http["sender"]["query"]["num_other"]+left) > 0) then
	       print(comma..'\t { "label": "Other", "value": '.. (http["sender"]["query"]["num_other"]+left) .. '}\n')
	    end
	 end
      else
	 -- responses
	 if(http["receiver"]["response"]["total"] > 0) then
	    min = (http["receiver"]["response"]["total"] * 3)/100
	    comma = ""

	    if(http["receiver"]["response"]["num_1xx"] > min) then
	       print(comma..'\t { "label": "1xx", "value": '.. http["receiver"]["response"]["num_1xx"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["receiver"]["response"]["num_1xx"]
	    end

	    if(http["receiver"]["response"]["num_2xx"] > min) then
	       print(comma..'\t { "label": "2xx", "value": '.. http["receiver"]["response"]["num_2xx"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["receiver"]["response"]["num_2xx"]
	    end

	    if(http["receiver"]["response"]["num_3xx"] > min) then
	       print(comma..'\t { "label": "3xx", "value": '.. http["receiver"]["response"]["num_3xx"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["receiver"]["response"]["num_3xx"]
	    end

	    if(http["receiver"]["response"]["num_4xx"] > min) then
	       print(comma..'\t { "label": "4xx", "value": '.. http["receiver"]["response"]["num_4xx"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["receiver"]["response"]["num_4xx"]
	    end

	    if(http["receiver"]["response"]["num_5xx"] > min) then
	       print(comma..'\t { "label": "4xx", "value": '.. http["receiver"]["response"]["num_5xx"] .. '}\n')
	       comma = ","
	    else
	       left = left + http["receiver"]["response"]["num_5xx"]
	    end

	    if(left > 0) then
	       print(comma..'\t { "label": "Other", "value": '.. left .. '}\n')
	    end
	 end
      end
   end
end

print "\n]"




