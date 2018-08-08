--
-- (C) 2014-18 - ntop.org
--

local format_utils = {}

function format_utils.round(num, idp)
   if(num == nil) then return(0) end
   return tonumber(string.format("%." .. (idp or 0) .. "f", num))
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

	 msg = years .. " year"
	 if(years > 1) then msg = msg .. "s" end
      end

      if(days > 0) then
	 if(string.len(msg) > 0) then  msg = msg .. ", " end
	 msg = msg .. days .. " day"
	 if(days > 1) then msg = msg .. "s" end
      end
   end

   if(string.len(msg) > 0) then  msg = msg .. ", " end

   if(hours > 0) then
      msg = msg .. string.format("%02d:", truncate(hours))
   end
   msg = msg .. string.format("%02d:", truncate(minutes))
   msg = msg .. string.format("%02d", truncate(sec));

   return msg
end

function format_utils.msToTime(ms)
   if(ms > 1000) then
      return format_utils.secondsToTime(ms/1000)
   else
      if(ms < 1) then
	 return("< 1 ms")
      else
	 return(round(ms, 4).." ms")
      end
   end
end

-- Convert bytes to human readable format
function format_utils.bytesToSize(bytes)
   if(bytes == nil) then
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
      return round(bits / kilobit, precision) .. ' kbit/s';
   elseif((bits >= megabit) and (bits < gigabit)) then
      return round(bits / megabit, precision) .. ' Mbit/s';
   elseif((bits >= gigabit) and (bits < terabit)) then
      return round(bits / gigabit, precision) .. ' Gbit/s';
   elseif(bits >= terabit) then
      return round(bits / terabit, precision) .. ' Tbit/s';
   else
      return round(bits, precision) .. ' bit/s';
   end
end

function format_utils.bitsToSize(bits)
   return(bitsToSizeMultiplier(bits, 1000))
end

-- maxRateToString
function format_utils.maxRateToString(max_rate)
   if((max_rate == nil) or (max_rate == "")) then max_rate = -1 end
   max_rate = tonumber(max_rate)

   if(max_rate < 1000) then
      return(max_rate.." Kbit/s")
   else
      local mr
      mr = round(max_rate / 1000, 2)

      if(mr < 1000) then
	 return(mr.." Mbit/s")
      else
	 gbit = mr /1000
	 return(gbit.." Gbit/s")
      end
   end
end

function format_utils.formatEpoch(epoch)
  if epoch == 0 then
    return("-")
  else
    return(os.date("%d/%m/%Y %X", epoch))
  end
end

return format_utils
