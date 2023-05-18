--
-- (C) 2014-22 - ntop.org
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
   return(bitsToSizeMultiplier(bits, 1000))
end

function format_utils.bytesToBPS(bytes)
   return(bitsToSizeMultiplier(bytes * 8, 1000))
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
   local day = os.date("!%d", epoch)
   local day_now = os.date("!%d", epoch_now)

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

function format_utils.formatHostNameAndAddress(hostname, address)
   local res = ""

   if address ~= hostname then
      res = string.format("%s [%s]", address, hostname)
   else
      res = hostname
   end

   return res
end
   
if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

return format_utils
