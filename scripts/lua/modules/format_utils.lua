--
-- (C) 2014-24 - ntop.org
--

local format_utils = {}

local clock_start = os.clock()

function format_utils.round(num, idp)
   num = tonumber(num)
   local res

   if num == nil then
      return 0
   end

   if math.abs(num) == math.huge then
      -- This is an infinite, e.g., 1/0 or -1/0
      res = num
   elseif num == math.floor(num) then
      -- This is an integer, so represent it
      -- without decimals
      res = string.format("%d", math.floor(num))
   else
      -- This is a number with decimal, so represent
      -- it with a number of decimal digits equal to idp
      res = string.format("%." .. (idp or 0) .. "f", num)
   end

   return tonumber(res) or 0
end

local round = format_utils.round

function format_utils.timeToSeconds(time)
   if(isEmptyString(time)) then return 0 end

   local seconds = 0
   -- Remove the sec string at the end, e.g. 00:01 sec
   local time_splitted = time:split(" ") or {}
   if table.len(time_splitted) == 2 then
      time_splitted = time_splitted[1]
   else
      time_splitted = time
   end

   local index = 1 -- represents which time we are analyzing, seconds, minutes, ecc.
   -- Split by : to get days, hours, minutes and seconds
   for _, time_in_string in pairsByKeys(time_splitted:split(":") or {}, rev) do
      if index == 1 then
         -- Seconds
         seconds = seconds + tonumber(time_in_string)
      elseif index == 2 then
         -- Minutes
         seconds = seconds + tonumber(time_in_string) * 60
      elseif index == 3 then
         -- Hours
         seconds = seconds + tonumber(time_in_string) * 3600
      elseif index == 4 then
         -- Days
         seconds = seconds + tonumber(time_in_string) * 86400
      end

      index = index + 1
   end 

   return seconds
end

function format_utils.secondsToTime(seconds)
   local seconds = tonumber(seconds)
   if(seconds == nil) then return "" end

   if(seconds < 1) then
      return("< 1 sec")
   end

   local days = math.floor(seconds / 86400)
   local hours =  math.floor((seconds / 3600) - (days * 24))
   local minutes = math.floor((seconds / 60) - (days * 1440) - (hours * 60))
   local sec = seconds % 60
   local msg = ""

   if(days > 0) then
      years = math.floor(days/365)

      if(years > 0) then
	 days = days % 365

	 msg = years .. " "

	 if(years == 1) then
	    msg = msg .. i18n("year")
	 else
	    msg = msg .. i18n("years")
	 end
      end

      if(days > 0) then
	 if(string.len(msg) > 0) then  msg = msg .. ", " end

	 if(days > 1) then
	    msg = msg .. days .. " " .. i18n("metrics.days")
	 else
	    msg = msg .. days .. " " .. i18n("day")
	 end
      end
   end

   if(string.len(msg) > 0) then  msg = msg .. ", " end

   if(hours > 0) then
      msg = msg .. string.format("%02d:", truncate(hours))
   end
   msg = msg .. string.format("%02d:", truncate(minutes))
   msg = msg .. string.format("%02d", truncate(sec));

   if(seconds < 60) then msg = msg .. " sec" end

   return msg
end

function format_utils.msToTime(ms)
   if(ms > 10000) then -- 10 sec+
      return format_utils.secondsToTime(ms/1000)
   else
      if(ms < 1) then
	 return("< 1 ms")
      else
	 return(round(ms, 2).." ms")
      end
   end
end

-- Convert bytes to human readable format
function format_utils.bytesToSize(bytes)
   if(tonumber(bytes) == nil) then
      return("0")
   else
      local precision = 2
      local kilobyte = 1024;
      local megabyte = kilobyte * 1024;
      local gigabyte = megabyte * 1024;
      local terabyte = gigabyte * 1024;

      bytes = tonumber(bytes)
      if bytes == 1 then return "1 Byte"
      elseif((bytes >= 0) and (bytes < kilobyte)) then
	 return round(bytes, precision) .. " Bytes";
      elseif((bytes >= kilobyte) and (bytes < megabyte)) then
	 return round(bytes / kilobyte, precision) .. ' KB';
      elseif((bytes >= megabyte) and (bytes < gigabyte)) then
	 return round(bytes / megabyte, precision) .. ' MB';
      elseif((bytes >= gigabyte) and (bytes < terabyte)) then
	 return round(bytes / gigabyte, precision) .. ' GB';
      elseif(bytes >= terabyte) then
	 return round(bytes / terabyte, precision) .. ' TB';
      else
	 return round(bytes, precision) .. ' Bytes';
      end
   end
end

function format_utils.formatValue(amount)
   local formatted = amount

   if(formatted == nil) then return(0) end
   while true do
      formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
      if(k==0) then
	 break
      end
   end

   return formatted
end

function format_utils.formatPackets(amount)
   local amount = tonumber(amount)
   if (amount == 1) then return "1 Pkt" end
   return format_utils.formatValue(amount).." Pkts"
end

function format_utils.formatFlows(amount)
   local amount = tonumber(amount)
   if (amount == 1) then return "1 Flow" end
   return format_utils.formatValue(amount).." Flows"
end

-- Convert packets to pps readable format
function format_utils.pktsToSize(pkts)
   local precision = 2
   if(pkts >= 1000000) then
      return round(pkts/1000000, precision)..' Mpps';
   elseif(pkts >= 1000) then
      return round(pkts/1000, precision)..' Kpps';
   else
      return round(pkts, precision)..' pps';
   end
end

-- Convert bits to human readable format

function format_utils.bitsToSizeMultiplier(bits, multiplier)
   if(bits == nil) then return(0) end

   local precision = 2
   local kilobit = 1000;
   local megabit = kilobit * multiplier;
   local gigabit = megabit * multiplier;
   local terabit = gigabit * multiplier;

   if((bits >= kilobit) and (bits < megabit)) then
      return round(bits / kilobit, precision) .. ' kbps';
   elseif((bits >= megabit) and (bits < gigabit)) then
      return round(bits / megabit, precision) .. ' Mbps';
   elseif((bits >= gigabit) and (bits < terabit)) then
      return round(bits / gigabit, precision) .. ' Gbps';
   elseif(bits >= terabit) then
      return round(bits / terabit, precision) .. ' Tbps';
   else
      return round(bits, precision) .. ' bps';
   end
end

function format_utils.bitsToSize(bits)
   return(format_utils.bitsToSizeMultiplier(bits, 1000))
end

function format_utils.bytesToBPS(bytes)
   return(format_utils.bitsToSizeMultiplier(bytes * 8, 1000))
end

-- parse a SQL DATETIME date and convert to epoch
function format_utils.parseDateTime(tstamp)
   if tstamp and not isEmptyString(tstamp) then
      local year, month, day, hour, min, sec = tstamp:match('^(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)$')
      local epoch = os.time({month=month, day=day, year=year, hour=hour, min=min, sec=sec})
      return epoch
   end

   return ""
end

-- format an epoch using ISO 8601 format
function format_utils.formatEpochISO8601(epoch)
  if epoch == nil then
    epoch = os.time()
  end

  if epoch == 0 then
    return("")
  end

  return os.date("!%Y-%m-%dT%TZ", epoch)
end

-- format an epoch according to RFC 2822 format (email)
-- E.g. "Tue, 3 Apr 2018 14:58:00 +0100"
function format_utils.formatEpochRFC2822(epoch)
  if epoch == nil then
    epoch = os.time()
  end

  -- Compute local time diff
  local now_ts = os.time()
  local d1 = os.date("*t", now_ts)
  local d2 = os.date("!*t", now_ts)
  d1.isdst = false
  local diff = -os.difftime(os.time(d1), os.time(d2))

  -- Format zone offset E.g. "+0100"
  local sign
  local hours 
  local minutes
  if diff > 0 then
    sign = '-'
    hours = math.floor(diff / (60*60))
    minutes = (diff % (60*60)) / 60
  else
    sign = '+'
    hours = math.floor(-diff / (60*60))
    minutes = (-diff % (60*60)) / 60
  end

  -- Format date
  local d = os.date("%a, %d %b %Y %X", epoch) -- E.g. "Tue, 3 Apr 2018 14:58:00"

  -- Format final date with zone offset
  return string.format("%s %s%02d%02d", d, sign, hours, minutes) -- E.g. "Tue, 3 Apr 2018 14:58:00 +0100"
end

-- format an epoch
function format_utils.formatEpoch(epoch, full_time)
  if epoch == nil then
    epoch = os.time()
  end

  if epoch == 0 then
    return("")
  else
   local t = epoch
   local key = ""
   local time = ""

   if _SESSION then
      key = ntop.getPref('ntopng.user.' .. (_SESSION["user"] or "") .. '.date_format')
   end

   if(key == "big_endian") then
      -- do NOT specify the ! to indicate UTC time; the time must be in Local Server Time
      time = "%Y/%m/%d"
   elseif( key == "middle_endian") then
      -- do NOT specify the ! to indicate UTC time; the time must be in Local Server Time
      time = "%m/%d/%Y"
   else
      -- do NOT specify the ! to indicate UTC time; the time must be in Local Server Time
      time = "%d/%m/%Y"
   end
   
   if(full_time == nil) or (full_time == true) then      
      time = time .. " %X"
   end

   return os.date(time, t)
  end
end

function format_utils.formatPastEpochShort(input_epoch)
   local epoch_now = os.time()
   local epoch = input_epoch or epoch_now
   local day = os.date("*t", epoch).day
   local day_now = os.date("*t", epoch_now).day

   if day == day_now then
      return os.date("%X", epoch)
   end

   return format_utils.formatEpoch(epoch)
end

-- See also format_utils.msToTime
function format_utils.formatMillis(x)
   if(x == 0) then return 0 end
   if(x < 0.1) then return "< 0.1 ms" end

   return string.format("%.2f ms", format_utils.formatValue(x))
end

function format_utils.formatContainer(cont)
   local name = ''

   if cont["k8s.name"] then
      name = cont["k8s.name"]
   elseif cont["docker.name"] then
      name = cont["docker.name"]
   elseif cont["id"] then
      name = cont["id"]
   end

   return string.format("%s", name)
end

function format_utils.formatPod(cont)
   local name = ''

   if cont["k8s.pod"] then
      name = cont["k8s.pod"]
   end

   return string.format("%s", name)
end

function format_utils.formatExporterInterface(port_idx, port_info)
   if port_info["container"] then
      return format_utils.formatContainer(port_info["container"])
   end

   return(port_info["ifName"] or port_idx)
end

function format_utils.formatContainerFromId(cont_id)
   -- NOTE: this is expensive, use format_utils.formatContainer when possible
   local containers = interface.getContainersStats()
   if((containers[cont_id] ~= nil) and (containers[cont_id].info ~= nil)) then
      return format_utils.formatContainer(containers[cont_id].info)
   else
      return shortenString(cont_id, 12)
   end
end

-- @brief Formatter function for two flow statuses. Places here to ease reuse.
--        Current flow statuses sharing this function are status_tcp_severe_connection_issues
--        and status_tcp_connection_issues
function format_utils.formatConnectionIssues(info)
   local res = ""

   if info and info.client_issues and info.tcp_stats and type(info.tcp_stats) == "table" and info.cli2srv_pkts then
      local retx = info.tcp_stats["cli2srv.retransmissions"]
      local ooo =  info.tcp_stats["cli2srv.out_of_order"]
      local lost = info.tcp_stats["cli2srv.lost"]

      local what = {}

      if retx > 0 then
	 what[#what + 1] = i18n("alerts_dashboard.x_retx", {retx = format_utils.formatValue(retx)})
      end
      if ooo > 0 then
	 what[#what + 1] = i18n("alerts_dashboard.x_ooo", {ooo = format_utils.formatValue(ooo)})
      end
      if lost > 0 then
	 what[#what + 1] = i18n("alerts_dashboard.x_lost", {lost = format_utils.formatValue(lost)})
      end

      if retx + ooo + lost > 0 then
	 if info.cli2srv_pkts > 0 then
	    what[#what + 1] = i18n("alerts_dashboard.out_of_x_total_packets", {tot = format_utils.formatValue(info.cli2srv_pkts)})
	 end

	 if #what > 0 then
	    res = res.." "..string.format("[%s: %s]", i18n("client_to_server"), table.concat(what, ", "))
	 end
      end
   end

   if info and info.server_issues and info.tcp_stats and type(info.tcp_stats) == "table" and info.srv2cli_pkts then
      local retx = info.tcp_stats["srv2cli.retransmissions"]
      local ooo =  info.tcp_stats["srv2cli.out_of_order"]
      local lost = info.tcp_stats["srv2cli.lost"]

      local what = {}

      if retx > 0 then
	 what[#what + 1] = i18n("alerts_dashboard.x_retx", {retx = format_utils.formatValue(retx)})
      end
      if ooo > 0 then
	 what[#what + 1] = i18n("alerts_dashboard.x_ooo", {ooo = format_utils.formatValue(ooo)})
      end
      if lost > 0 then
	 what[#what + 1] = i18n("alerts_dashboard.x_lost", {lost = format_utils.formatValue(lost)})
      end

      if retx + ooo + lost > 0 then
	 if info.srv2cli_pkts > 0 then
	    what[#what + 1] = i18n("alerts_dashboard.out_of_x_total_packets", {tot = format_utils.formatValue(info.srv2cli_pkts)})
	 end

	 if #what > 0 then
	    res = res.." "..string.format("[%s: %s]", i18n("server_to_client"), table.concat(what, ", "))
	 end
      end
   end

   return res
end

function format_utils.formatFullAddressCategory(host)
   local addr_category = ""

   if host ~= nil then
      addr_category = format_utils.formatMainAddressCategory(host)
      
      if(host["is_broadcast"] == true) then 
         addr_category = addr_category .. " <abbr title=\"".. i18n("broadcast") .."\"><span class='badge bg-dark'>" ..i18n("short_broadcast").. "</span></abbr>"
      end
      
      if(host["broadcast_domain_host"] == true) then
         addr_category = addr_category .. " <span class='badge bg-info' style='cursor: help;'><i class='fas fa-sitemap' title='"..i18n("hosts_stats.label_broadcast_domain_host").."'></i></span>"
      end
      
      if(host["privatehost"] == true) then 
         addr_category = addr_category .. ' <abbr title=\"'.. i18n("details.label_private_ip") ..'\"><span class="badge bg-warning">'..i18n("details.label_short_private_ip")..'</span></abbr>'
      end

      if(host["dhcpHost"] == true) then
         addr_category = addr_category .. ' <i class=\"fas fa-bolt\" title=\"'..i18n("details.label_dhcp")..'\"></i>'
      end
   end
   
   return addr_category
end

function format_utils.formatMainAddressCategory(host)
   local addr_category = ""

   if host ~= nil then      
      if(host["country"] and not isEmptyString(host["country"])) then
	 addr_category = addr_category .. " <a href='".. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?country="..host.country.."'><img src='".. ntop.getHttpPrefix() .. "/dist/images/blank.gif' class='flag flag-".. string.lower(host.country) .."'></a>"
      end
      
      if(host["is_blacklisted"] == true) then
        addr_category = addr_category .. " <i class=\'fas fa-ban fa-sm\' title=\'"..i18n("hosts_stats.blacklisted").."\'></i>"
      end
           
      if(host["crawlerBotScannerHost"] == true) then
        addr_category = addr_category .. " <i class=\'fas fa-spider fa-sm\' title=\'"..i18n("hosts_stats.crawler_bot_scanner").."\'></i>"
      end
     

      if(host["is_multicast"] == true) then 
         addr_category = addr_category .. " <abbr title=\"".. i18n("multicast") .."\"><span class='badge bg-primary'>" ..i18n("short_multicast").. "</span></abbr>"
      elseif(host["localhost"] == true) then
         addr_category = addr_category .. ' <abbr title=\"'.. i18n("details.label_local_host") ..'\"><span class="badge bg-success">'..i18n("details.label_short_local_host")..'</span></abbr>'
      else 
         addr_category = addr_category .. ' <abbr title=\"'.. i18n("details.label_remote") ..'\"><span class="badge bg-secondary">'..i18n("details.label_short_remote")..'</span></abbr>'
      end

      if(host.is_blackhole == true) then
	 addr_category = addr_category .. ' <abbr title=\"'.. i18n("details.label_blackhole") ..'\"><span class="badge bg-info">'..i18n("details.label_short_blackhole")..'</span></abbr>'
      end
   end

   return addr_category
end

-- ##############################################

function format_utils.formatMainAddressCategoryNoHTML(host, host_info)
   if isEmptyString(host_info) then
      host_info = {}
   end
   if host["systemhost"] then
      host_info.system_host = true
   end
   if host["country"] then
      host_info.country = host["country"]
   end
   if host["is_blacklisted"] then
      host_info.is_blacklisted = host["is_blacklisted"]
   end
   if host["crawlerBotScannerHost"] then
      host_info.crawler_bot_scanner_host = host["crawlerBotScannerHost"]
   end
   if host["is_multicast"] then
      host_info.is_multicast = true
   elseif host["localhost"] then
      host_info.localhost = true
   else
      host_info.remotehost = true
   end
   if host["is_blackhole"] then
      host_info.is_blackhole = host["is_blackhole"]
   end

   return host_info
end

-- ##############################################

function format_utils.formatHostNameAndAddress(hostname, address)
   local res = ""

   if address ~= hostname then
      res = string.format("%s [%s]", address, hostname)
   else
      res = hostname
   end

   return res
end

-- ######################################################

local function format_report_email(notification)
  return [[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0" />
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>ntopng</title>
</head>
<body style="width: 100%; padding:0; margin:0; background-color: #D6EAF8">
	<div width="100%" height="100%" style="padding: 50px">
		<div width="800px" align="center" style="padding: 0 0 50px 0;">
			<div id="ntop-logo" style="padding: 0 0 40px 0">
				<svg xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:cc="http://creativecommons.org/ns#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" id="svg8" version="1.1" viewBox="0 0 13.758333 13.758334" height="52" width="52">
					<g id="layer1">
						<g style="font-style:normal;font-weight:normal;font-size:16.9333px;line-height:1.25;font-family:sans-serif;letter-spacing:0px;word-spacing:0px;fill:#ff7500;fill-opacity:1;stroke:none;stroke-width:0.264583" id="text835" aria-label="n">
							<path d="M 2.7739989,9.5828812 V 4.216811 q 0,-0.9839173 0.3224603,-1.4552054 0.3307285,-0.4795564 1.008722,-0.4795564 0.4051424,0 0.7193345,0.2149735 Q 5.1387078,2.7037281 5.378486,3.1336751 5.808433,2.662387 6.3706715,2.4474135 6.93291,2.2324399 7.7349267,2.2324399 q 1.5792286,0 2.4143183,0.9012352 0.835089,0.9012352 0.835089,2.6210235 v 3.8281826 q 0,0.9839178 -0.330728,1.4634738 -0.330729,0.479556 -1.0087222,0.479556 -0.6779934,0 -1.0087219,-0.479556 Q 8.3054333,10.566799 8.3054333,9.5828812 V 6.5649835 q 0,-1.1162088 -0.3389967,-1.5874969 -0.3307285,-0.4795563 -1.0996723,-0.4795563 -0.7276027,0 -1.0748677,0.4960927 -0.3472649,0.4878246 -0.3472649,1.5378876 v 3.0509706 q 0,0.9839178 -0.3307285,1.4634738 -0.3307286,0.479556 -1.008722,0.479556 -0.6779935,0 -1.008722,-0.479556 Q 2.7739989,10.566799 2.7739989,9.5828812 Z" style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-family:'VAGRounded BT';-inkscape-font-specification:'VAGRounded BT';fill:#ff7500;fill-opacity:1;stroke-width:0.264583" id="path873"></path>
						</g>
					</g>
				</svg>
			</div>
			<div style="max-width: 480px; margin: 0 auto; padding: 40px 20px 40px 20px; font-weight:400; font-size:13px; letter-spacing:0.025em; line-height:26px; color:#000; font-family:'Poppins', sans-serif; mso-line-height-rule: exactly; background: white;">
				<span style="font-weight:300; font-size:24px; letter-spacing:0.025em; line-height:23px; color: black; font-family: 'Poppins', sans-serif; mso-line-height-rule: exactly;">
					]] .. notification.title .. [[
				</span>
				<p>
					]] .. notification.message .. " " .. notification.note .. [[
				</p>
				<p><strong>Check it out!</strong></p>
				<div width="220" height="45" style="width: 180px; margin: 0; border-radius: 3px; padding: 5px 5px; background-color:#8FBE00">
					<a href="]] .. notification.link.url .. [[" style="font-weight:500; font-size:17px; letter-spacing:0.025em; line-height:26px; color:#FFF; font-family:'Poppins', sans-serif; mso-line-height-rule: exactly; text-decoration:none;">
						]] .. notification.link.label .. [[
					</a>
				</div>
			</div>
		</div>
	</div>
</body>
</html>
  ]]
end

-- ######################################################

local function format_no_html_vs_report_message(message) 
   local formatted_message = message
   formatted_message = formatted_message:gsub("<br>", "")
   formatted_message = formatted_message:gsub("</br>","\n")
   formatted_message = formatted_message:gsub("<a href='","")
   formatted_message = formatted_message:gsub("'>","")
   formatted_message = formatted_message:gsub("</a>","")
   return formatted_message
end

-- ######################################################

local function format_notification_subject(notifications)
   
   if not notifications or #notifications < 1 then
      subject = ""

   else
      local notification = notifications[1]

      if notification.notification_type == "reports" then
         subject = i18n("report.traffic_report")

      elseif notification.notification_type == "vulnerability_scans" then
         subject = i18n("vulnerability_scan.report")

      else
         local subject = i18n("alert_messages.alert")
         if #notifications > 1 then
            subject = i18n("alert_messages.x_alerts", {num=#notifications})
         end
      end
   end

   return subject
end

-- ######################################################

-- This is a basic function used to format notifications
local function format_notification(notification, options)
   local message = notification.message or ""
   local handled = false

   -- TODO: add the support to options 

   if notification.notification_type == "reports" and 
      (not options or not options.nohtml) then
      message = format_report_email(notification)
      handled = true

   elseif (notification.notification_type == "vulnerability_scans") then
      if(not options or not options.nohtml) then
          -- nothing to do
      else
         message = format_no_html_vs_report_message(message) 
      end
      handled = true

   end

   return handled, message
end

-- ######################################################

function format_utils.formatSubject(notifications)
   return format_notification_subject(notifications)
end

-- ######################################################

-- This function is used to format alerts/message from recipients
-- so it's going to convert a table into a message delivered to the
-- various recipients.
-- Currently there are two types of messages, alerts and notifications
function format_utils.formatMessage(notification, options)
   if not notification.score or notification.score == 0 then
      -- In case it is just a message/report (so no score), format like a normal msg
      local handled, message = format_notification(notification, options)

      if handled then
         return message
      end
   end
   
   -- In case it is an alert, format it by using the standard function
   local alert_utils = require "alert_utils"
   local message = alert_utils.formatAlertNotification(notification, options)

   return message
end

-- ######################################################
-- This function removes '>' and '<' from email list and
-- adds a space after the commas
function format_utils.formatEmailList(email_list)
   local email_list_formatted = replace(email_list,"<","")
    email_list_formatted = replace(email_list_formatted, ">", "")
    email_list_formatted = replace(email_list_formatted, ",", ", ")
    return email_list_formatted
end

-- ##############################################

-- This function, given a record and a name return a  standard formatted value
-- and if the value is 0, an empty string is returned
-- e.g.   1000 -> 1,000    | 0 -> 
function format_utils.format_high_num_value_for_tables(record, name)
  local formatted_record = format_utils.formatValue(record[name] or 0)
  if formatted_record == '0' then
    formatted_record = ''
  end

  return formatted_record
end

-- ##############################################

function format_utils.format_name_value(name, value, shorten)
    local formatted_name_value = value

    if not isEmptyString(name) and name ~= value then
        if (shorten) and (shorten == true) then
            formatted_name_value = shortenString(name)
        else
            formatted_name_value = name
        end
    end

    local idx = string.find(formatted_name_value, value)

    if (idx == nil) then
        formatted_name_value = formatted_name_value .. " [" .. value .. "]"
    end

    return formatted_name_value
end

-- ######################################################

return format_utils
