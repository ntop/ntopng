--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

function hasLocalTraffic(stats, locals, host_a)
   for key, value in pairs(stats) do
      if((flows_stats[key]["cli.ip"] == host_a) and (locals[flows_stats[key]["srv.ip"]] ~= nil)) then
	 if(not(isBroadcastMulticast(flows_stats[key]["srv.ip"]))) then
	    return true
	 end
      end

      if((flows_stats[key]["srv.ip"] == host_a) and (locals[flows_stats[key]["cli.ip"]] ~= nil)) then
	 if(not(isBroadcastMulticast(flows_stats[key]["cli.ip"]))) then
	    return true
	 end
      end
   end -- for

   return false
end

function getTraffic(stats, host_a, host_b)
   sent_total = 0
   rcvd_total = 0

   -- io.write(">>> "..host_a.." / "..host_b.."\n")

   for key, value in pairs(stats) do
      client = hostinfo2hostkey(flows_stats[key],"cli")
      server = hostinfo2hostkey(flows_stats[key],"srv")
      -- io.write(">>> "..flows_stats[key]["cli.ip"].." / "..flows_stats[key]["srv.ip"].."\n")

      if((client == host_a) and (server == host_b)) then
	 sent_total = sent_total +  flows_stats[key]["cli2srv.bytes"]
	 rcvd_total = rcvd_total + flows_stats[key]["srv2cli.bytes"]
      elseif((server == host_a) and (client == host_b)) then
	 sent_total = sent_total +  flows_stats[key]["srv2cli.bytes"]
	 rcvd_total = rcvd_total + flows_stats[key]["cli2srv.bytes"]
      end
   end

   rc = { sent_total, rcvd_total }
   return(rc)
end

interface.select(ifname)
hosts_stats = interface.getLocalHostsInfo()
flows_stats = interface.getFlowsInfo(nil, {clientMode="local", serverMode="local"})
hosts_stats = hosts_stats["hosts"]
flows_stats = flows_stats["flows"]

localhosts = {}
found = false
for key, value in pairs(hosts_stats) do
   -- print(hosts_stats[key]["name"].."<p>\n")

   if(hosts_stats[key]["ip"] ~= nil) then
      -- exclude multicast / NoIP / broadcast
      if(not(isBroadcastMulticast(hosts_stats[key]["ip"]))) then
	 if(hasLocalTraffic(flows_stats, hosts_stats, key)) then
	    name_host_1 = getResolvedAddress(hostkey2hostinfo(key));
	    localhosts[key] = hosts_stats[key]
	    localhosts[key]["name"] = name_host_1
	    found = true
	 end
      end
   end
end

if(found == false) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("local_flow_matrix.error_no_local_hosts") .."</div>")
else
   print("<hr><h2>" .. i18n("local_flow_matrix.local_hosts_active_flows_matrix") .. "</h2>\n<p>&nbsp;<p>\n<table class=\"table table-striped table-bordered\">\n")

   -- Header
   print("<tr><th>&nbsp;</th>")
   for key, value in pairs(localhosts) do
      if((localhosts[key]["name"] ~= "") and (localhosts[key]["name"] ~= localhosts[key]["ip"])) then
	 t = string.split(localhosts[key]["name"], "%.")

	 if(t ~= nil) then 
	    n = shortHostName(t[1])
	 else
	    n = shortHostName(localhosts[key]["name"])
	 end
      else
	 n = localhosts[key]["ip"]
      end
      
      print("<th style=text-align:center>"..n.."</th>\n")
   end
   print("</tr>\n")

   for row_key, row_value in pairs(localhosts) do
      if(row_value["ip"] ~= nil) then
	 if(row_value["name"] ~= nil and row_value["name"] ~= "" and row_value["name"] ~= row_value["ip"]) then
            t = string.split(row_value["name"], "%.")
            if (t ~= nil and t[1] ~= nil) then
                n = shortHostName(t[1])
            else  -- fallback, string split has not been possible
                n = shortHostName(row_value["name"])
            end
	 else
	    n = localhosts[row_key]["ip"]
	 end

	 print("<tr><th><A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..row_key.."\">"..n.."</A></th>\n")
	 for column_key, column_value in pairs(localhosts) do
	    val = "&nbsp;"
	    if(row_key ~= column_key) then
	       rsp = getTraffic(flows_stats, row_key, column_key)

	       if((rsp[1] > 0) or (rsp[2] > 0)) then
		  val = ""
		  if(rsp[1] > 0) then val = val .. '<span class="label label-warning" data-toggle="tooltip" data-placement="top" title="'..localhosts[row_key]["name"]..' -> ' .. localhosts[column_key]["name"] .. '\">'..bytesToSize(rsp[1]) .. '</span> ' end
		  if(rsp[2] > 0) then val = val .. '<span class="label label-info" data-toggle="tooltip" data-placement="bottom" title="'..localhosts[column_key]["name"]..' -> ' .. localhosts[row_key]["name"]..'\">'..bytesToSize(rsp[2]) .. '</span> ' end
	       end
	    end
	    print("<td align=center>" .. val .. "</td>\n")
	 end
	 print("</tr>\n")
      end
   end
   print("</table>\n")
end


-- Activate tooltips
print [[
	 <script type="text/javascript">
	 $(document).ready(function () { $("span").tooltip({ 'selector': '', 'placement': 'bottom'  });});
			   </script>
			      </script>
			]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
