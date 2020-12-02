--
-- (C) 2013-20 - ntop.org
--

local sys_utils = require("sys_utils")
local config = {}

config.DEFAULT_WIFI_DEVICE_NAME = "wlan0"
config.DEBUG = true

-- ##############################################

function config.execCmd(cmd, verbose)
   local out = sys_utils.execCmd(cmd)
   if verbose or config.DEBUG then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "[execCmd][output] ".. out)
   end
end

-- ##############################################

function config.readCmd(cmd)
   return sys_utils.execShellCmd(cmd)
end

-- ##############################################

function config.getWiFiDeviceName()
   local rsp = config.readCmd("cat /proc/net/wireless | grep ':'| cut -d ':' -f 1 | tr -d '[:blank:]'")

   return(string.gsub(rsp, "\n", ""))
end

-- ##############################################

function config.enableWiFi()
   local wifi_dev = config.getWiFiDeviceName()

   if wifi_dev == "" then return false end

   config.execCmd("ifconfig "..wifi_dev.." up")
   config.execCmd("ifconfig "..wifi_dev.." power auto")

   config.execCmd("service hostapd enable", true)
   config.execCmd("service hostapd start", true)

   return(true)
end

-- ##############################################      

function config.disableWiFi()
   local wifi_dev = config.getWiFiDeviceName()

   if wifi_dev == "" then return false end

   config.execCmd("service hostapd stop", true)
   config.execCmd("service hostapd disable", true)

   config.execCmd("ifconfig "..wifi_dev.." power off", true)
   config.execCmd("ifconfig "..wifi_dev.." down", true)

   return(true)
end

-- ##############################################      

-- Configure wireless as access point
-- NOTE: password must be 8..63 chars        
function config.configureWiFiAccessPoint(ssid, wpa_passphrase)
   local p_len = string.len(wpa_passphrase)

   if((p_len < 8) or (p_len > 63)) then
      return(false)
   end

   -- Enable configuration file    
   config.execCmd("sed -i 's/#DAEMON_CONF/DAEMON_CONF/g' /etc/default/hostapd")

   -- set SSID 
   config.execCmd("sed -i 's/^ssid=.*/ssid="..ssid.."/g' /etc/hostapd.conf")

   -- set WPA2 / Channel 6
   config.execCmd("sed -i 's/^wpa=.*/wpa=2/g' /etc/hostapd.conf")
   config.execCmd("sed -i 's/^channel=.*/channel=6/g' /etc/hostapd.conf")

   -- Set WPA passphrase 
   config.execCmd("sed -i 's/^wpa_passphrase=.*/wpa_passphrase="..wpa_passphrase.."/g' /etc/hostapd.conf")

   config.enableWiFi()
   config.execCmd("service hostapd restart")

   return(true)
end

-- ##############################################

return config
