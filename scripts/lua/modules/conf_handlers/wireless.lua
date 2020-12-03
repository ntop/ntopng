--
-- (C) 2013-20 - ntop.org
--

local sys_utils = require("sys_utils")
local config = {}

config.DEFAULT_WIFI_DEVICE_NAME = "wlan0"
config.DEBUG = false

-- ##############################################

function config.supported()
   return ntop.exists("/lib/systemd/system/hostapd.service")
end

-- ##############################################

function config.execCmd(cmd, verbose)
   if verbose or config.DEBUG then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "[execCmd] "..cmd)
   end

   local out = sys_utils.execCmd(cmd)
   if verbose or config.DEBUG then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "[execCmd] -> ".. tostring(out))
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

   config.execCmd("/bin/systemctl unmask hostapd")
   config.execCmd("/bin/systemctl enable hostapd")
   config.execCmd("/bin/systemctl enable systemd-networkd")
   config.execCmd("/bin/systemctl restart hostapd")

   --config.execCmd("service hostapd enable", true)
   --config.execCmd("service hostapd restart", true)

   return(true)
end

-- ##############################################      

function config.disableWiFi()
   local wifi_dev = config.getWiFiDeviceName()

   if wifi_dev == "" then return false end

   config.execCmd("/bin/systemctl stop hostapd")
   config.execCmd("/bin/systemctl disable hostapd")

   --config.execCmd("service hostapd stop", true)
   --config.execCmd("service hostapd disable", true)

   config.execCmd("ifconfig "..wifi_dev.." power off", true)
   config.execCmd("ifconfig "..wifi_dev.." down", true)

   return(true)
end

-- ##############################################      

-- Configure wireless as access point
-- NOTE: password must be 8..63 chars        
function config.configureWiFiAccessPoint(nf, ssid, wpa_passphrase, network_conf)
   local p_len = string.len(wpa_passphrase)

   if p_len < 8 or p_len > 63 then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Wrong WPA password length")
      return false
   end

   nf:write("auto lo\n")
   nf:write("iface lo inet loopback\n\n")

   nf:write("auto eth0\n")
   nf:write("iface eth0 inet manual\n\n")

   nf:write("auto wlan0\n")
   nf:write("iface wlan0 inet manual\n")
   nf:write("	wireless-mode Master\n")

   local f = sys_utils.openFile("/etc/systemd/network/bridge-br0.netdev", "w")
   if not f then return false end
   f:write("[NetDev]\n")
   f:write("Name=br0\n")
   f:write("Kind=bridge\n")
   f:close()

   local f = sys_utils.openFile("/etc/systemd/network/br0-member-eth0.network", "w")
   if not f then return false end
   f:write("[Match]\n")
   f:write("Name=eth0\n")
   f:write("[Network]\n")
   f:write("Bridge=br0\n")
   f:close()

   -- Configure dhcp
   config.execCmd("sed -i '/^interface/ d' /etc/dhcpcd.conf")
   config.execCmd("sed -i '/^denyinterfaces/ d' /etc/dhcpcd.conf")
   local dhcpcd_deny = "wlan0 eth0"
   if network_conf.mode ~= "dhcp" then
      dhcpcd_deny = dhcpcd_deny.." br0"
   end
   config.execCmd("echo 'denyinterfaces "..dhcpcd_deny.."\\n' >> /etc/dhcpcd.conf")
   if network_conf.mode == "dhcp" then
      config.execCmd("echo 'interface br0\\n' >> /etc/dhcpcd.conf")
   end

   -- Create configuration file
   local f = sys_utils.openFile("/etc/hostapd/hostapd.conf", "w")
   if not f then return false end
   f:write("country_code=IT\n")
   f:write("interface=wlan0\n")
   f:write("bridge=br0\n")
   f:write("ssid="..ssid.."\n")
   f:write("hw_mode=g\n") -- hw_mode=a to use 5GHz
   f:write("channel=6\n")
   f:write("macaddr_acl=0\n")
   f:write("auth_algs=1\n")
   f:write("ignore_broadcast_ssid=0\n")
   f:write("wpa=2\n")
   f:write("wpa_passphrase="..wpa_passphrase.."\n")
   f:write("wpa_key_mgmt=WPA-PSK\n")
   f:write("wpa_pairwise=TKIP\n")
   f:write("rsn_pairwise=CCMP\n")
   f:close()

   -- Enable configuration file    
   config.execCmd("sed -i 's/#DAEMON_CONF/DAEMON_CONF/g' /etc/default/hostapd")

   -- Set configuration file path
   config.execCmd("sed -i 's/^DAEMON_CONF=.*/DAEMON_CONF=\"\\/etc\\/hostapd\\/hostapd.conf\"/g' /etc/default/hostapd")

   -- Change SSID 
   --config.execCmd("sed -i 's/^ssid=.*/ssid="..ssid.."/g' /etc/hostapd.conf")

   -- Set WPA2 / Channel 6
   --config.execCmd("sed -i 's/^wpa=.*/wpa=2/g' /etc/hostapd.conf")
   --config.execCmd("sed -i 's/^channel=.*/channel=6/g' /etc/hostapd.conf")

   -- Change WPA passphrase 
   --config.execCmd("sed -i 's/^wpa_passphrase=.*/wpa_passphrase="..wpa_passphrase.."/g' /etc/hostapd.conf")

   config.enableWiFi()

   return(true)
end

-- ##############################################

return config
