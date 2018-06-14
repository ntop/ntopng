require "lua_utils"
local discover = require "discover_utils"

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local now = os.time()

function macAddIcon(mac, pre)
   local pre = pre or mac
   if not isSpecialMac(mac) then
      local icon = discover.devtype2icon(mac.devtype)

      if not isEmptyString(icon) then
         return pre.."&nbsp;"..icon
      end
   end

   return pre
end

function mac2link(mac)
   local macaddress = mac["mac"]
   return "<A HREF='"..ntop.getHttpPrefix()..'/lua/mac_details.lua?'..hostinfo2url(mac).."' title='"..macaddress.."'>"..macaddress..'</A>'
end

function mac2record(mac)
   local record = {}
   record["key"] = hostinfo2jqueryid(mac)

   record["column_mac"] = mac2link(mac)

   if(mac.fingerprint ~= "") then
      record["column_mac"] = record["column_mac"]..' <i class="fa fa-hand-o-up fa-lg" aria-hidden="true" title="DHCP Fingerprinted"></i>'
      -- io.write(mac.fingerprint.."\n")
   end

   if(mac.dhcpHost) then
      record["column_mac"] = record["column_mac"]..'  <i class="fa fa-flash fa-lg" aria-hidden="true" title="DHCP Host"></i>'
   end
   
   record["column_mac"] = record["column_mac"]..getOperatingSystemIcon(mac.operatingSystem)   
   local manufacturer = get_manufacturer_mac(mac["mac"])
   if(manufacturer == nil) then manufacturer = "" end

   if(mac["model"] ~= nil) then
      local _model = discover.apple_products[mac["model"]] or mac["model"]
      manufacturer = manufacturer .. " [ ".. shortenString(_model) .." ]"
   end
   
   record["column_manufacturer"] = manufacturer

   record["column_arp_total"] = formatValue(mac["arp_requests.sent"]
					       + mac["arp_replies.sent"]
					       + mac["arp_requests.rcvd"]
					       + mac["arp_replies.rcvd"])

   record["column_device_type"] = discover.devtype2string(mac["devtype"]).." "..discover.devtype2icon(mac["devtype"])

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

   record["column_name"] = getDeviceName(mac["mac"], true)

   return record
end

