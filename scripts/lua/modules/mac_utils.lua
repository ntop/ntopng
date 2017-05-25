require "lua_utils"

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local now = os.time()

function macAddIcon(mac, pre)
   if not isSpecialMac(mac) then
      local icon = getHostIcon(mac)
      if not isEmptyString(icon) then
         return pre.."&nbsp;"..icon
      end
   end

   return pre
end

function mac2link(mac)
   local link = "<A HREF='"..ntop.getHttpPrefix()..'/lua/mac_details.lua?'..hostinfo2url(mac).."' title='"..mac.."'>"..mac..'</A>'
   return macAddIcon(mac, link)
end

function mac2record(mac)
   local record = {}
   record["key"] = hostinfo2jqueryid(mac)

   record["column_mac"] = mac2link(mac["mac"])

   local manufacturer = get_manufacturer_mac(mac["mac"])
   if(manufacturer == nil) then manufacturer = "" end
   record["column_manufacturer"] = manufacturer

   record["column_arp_sent"] = formatValue(mac["arp_requests.sent"] + mac["arp_replies.sent"])
   record["column_arp_rcvd"] = formatValue(mac["arp_requests.rcvd"] + mac["arp_replies.rcvd"])

   record["column_hosts"] = mac["num_hosts"]..""
   record["column_since"] = secondsToTime(now - mac["seen.first"]+1)

   local sent2rcvd = round((mac["bytes.sent"] * 100) / (mac["bytes.sent"] + mac["bytes.rcvd"]), 0)
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar progress-bar-warning' style='width: "
      .. sent2rcvd .."%;'>Sent</div><div class='progress-bar progress-bar-info' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   if(throughput_type == "pps") then
      record["column_thpt"] = pktsToSize(mac["throughput_pps"])
   else
      record["column_thpt"] = bitsToSize(8*mac["throughput_bps"])
   end

   record["column_traffic"] = bytesToSize(mac["bytes.sent"] + mac["bytes.rcvd"])

   return record
end

