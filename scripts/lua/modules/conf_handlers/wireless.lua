--
-- (C) 2013-20 - ntop.org
--

local sys_utils = require("sys_utils")
local config = {}

config.APPLY_ON_REBOOT = true
config.DEFAULT_BRIDGE_DEVICE_NAME = "br0"
config.DEFAULT_WIRED_DEVICE_NAME = "eth0"
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
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "[execCmd] Output: ".. tostring(out))
   end
end

-- ##############################################

function config.readCmd(cmd)
   return sys_utils.execShellCmd(cmd)
end

-- ##############################################

function config.getWiFiDeviceName()
   local rsp = config.readCmd("cat /proc/net/wireless | grep ':'| cut -d ':' -f 1 | tr -d '[:blank:]'")
   local dev = string.gsub(rsp, "\n", "")

   if isEmptyString(dev) then
      dev = config.DEFAULT_WIFI_DEVICE_NAME
   end

   return dev
end

-- ##############################################

function config.enableWiFi()
   local wifi_dev = config.getWiFiDeviceName()
   if wifi_dev == "" then return false end

   if not config.APPLY_ON_REBOOT then
      config.execCmd("ifconfig "..wifi_dev.." up")
      config.execCmd("ifconfig "..wifi_dev.." power auto")
   end

   config.execCmd("/bin/systemctl unmask hostapd")
   config.execCmd("/bin/systemctl enable hostapd")
   --config.execCmd("service hostapd enable", true)

   config.execCmd("/bin/systemctl enable systemd-networkd")

   if not config.APPLY_ON_REBOOT then
      config.execCmd("/bin/systemctl restart hostapd")
      --config.execCmd("service hostapd restart", true)
   end

   return true
end

-- ##############################################      

function config.disableWiFi()
   local wifi_dev = config.getWiFiDeviceName()
   if wifi_dev == "" then return false end

   if not config.APPLY_ON_REBOOT then
      config.execCmd("/bin/systemctl stop hostapd")
      --config.execCmd("service hostapd stop", true)
   end

   config.execCmd("/bin/systemctl disable hostapd")
   --config.execCmd("service hostapd disable", true)

   if not config.APPLY_ON_REBOOT then
      config.execCmd("ifconfig "..wifi_dev.." power off", true)
      config.execCmd("ifconfig "..wifi_dev.." down", true)
   end

   return true
end

-- ##############################################      

-- Configure wireless as access point
-- NOTE: password must be 8..63 chars        
function config.configureWiFiAccessPoint(nf, ssid, wpa_passphrase, network_conf)
   local bridge_dev = config.DEFAULT_BRIDGE_DEVICE_NAME;
   local wired_dev = config.DEFAULT_WIFI_DEVICE_NAME
   local wifi_dev = config.getWiFiDeviceName()
   if wifi_dev == "" then return false end

   local p_len = string.len(wpa_passphrase)
   if p_len < 8 or p_len > 63 then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Wrong WPA password length")
      return false
   end

   nf:write("auto "..wired_dev.."\n")
   nf:write("iface "..wired_dev.." inet manual\n\n")

   nf:write("auto "..wifi_dev.."\n")
   nf:write("iface "..wifi_dev.." inet manual\n")
   nf:write("	wireless-mode Master\n")

   local f = sys_utils.openFile("/etc/systemd/network/bridge-"..bridge_dev..".netdev", "w")
   if not f then return false end
   f:write("[NetDev]\n")
   f:write("Name="..bridge_dev.."\n")
   f:write("Kind=bridge\n")
   f:close()

   local f = sys_utils.openFile("/etc/systemd/network/"..bridge_dev.."-member-"..wired_dev..".network", "w")
   if not f then return false end
   f:write("[Match]\n")
   f:write("Name="..wired_dev.."\n")
   f:write("[Network]\n")
   f:write("Bridge="..bridge_dev.."\n")
   f:close()

   -- Configure dhcp
   config.execCmd("sed -i '/^interface/ d' /etc/dhcpcd.conf")
   config.execCmd("sed -i '/^denyinterfaces/ d' /etc/dhcpcd.conf")
   local dhcpcd_deny = wifi_dev.." "..wired_dev
   if network_conf.mode ~= "dhcp" then
      dhcpcd_deny = dhcpcd_deny.." "..bridge_dev
   end
   config.execCmd("echo 'denyinterfaces "..dhcpcd_deny.."\\n' >> /etc/dhcpcd.conf")
   if network_conf.mode == "dhcp" then
      config.execCmd("echo 'interface "..bridge_dev.."\\n' >> /etc/dhcpcd.conf")
   end

   -- Create configuration file
   local f = sys_utils.openFile("/etc/hostapd/hostapd.conf", "w")
   if not f then return false end
   f:write("country_code=IT\n")
   f:write("interface="..wifi_dev.."\n")
   f:write("bridge="..bridge_dev.."\n")
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

   return true
end

-- ##############################################

return config
