--
-- (C) 2018 - ntop.org
--

-- NOTE: use the slim utils version here
require("ntop_utils")

local os_utils = require("os_utils")

-- ########################################################

-- host_or_network: host or network name.
-- If network, must be prefixed with 'net:'
-- If profile, must be prefixed with 'profile:'
-- If host pool, must be prefixed with 'pool:'
-- If vlan, must be prefixed with 'vlan:'
-- If asn, must be prefixed with 'asn:'
-- If country, must be prefixed with 'country:'
function getRRDName(ifid, host_or_network, rrdFile)
   if host_or_network ~= nil and string.starts(host_or_network, 'net:') then
      host_or_network = string.gsub(host_or_network, 'net:', '')
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/subnetstats/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'profile:') then
      host_or_network = string.gsub(host_or_network, 'profile:', '')
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/profilestats/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'vlan:') then
      host_or_network = string.gsub(host_or_network, 'vlan:', '')
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/vlanstats/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'pool:') then
      host_or_network = string.gsub(host_or_network, 'pool:', '')
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/host_pools/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'snmp:') then
      host_or_network = string.gsub(host_or_network, 'snmp:', '')
      -- snmpstats are ntopng-wide so ifid is ignored
      rrdname = os_utils.fixPath(dirs.workingdir .. "/snmpstats/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'flow_device:') then
      host_or_network = string.gsub(host_or_network, 'flow_device:', '')
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/flow_devices/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'sflow:') then
      host_or_network = string.gsub(host_or_network, 'sflow:', '')
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/sflow/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'vlan:') then
      host_or_network = string.gsub(host_or_network, 'vlan:', '')
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/vlanstats/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'asn:') then
      host_or_network = string.gsub(host_or_network, 'asn:', '')
      host_or_network = host_or_network:gsub("(%d)", "%1/") -- asn 1234 becomes 1/2/3/4
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/asnstats/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'country:') then
      host_or_network = string.gsub(host_or_network, 'country:', '')
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/countrystats/")
   else
      rrdname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/rrd/")
   end

   if(host_or_network ~= nil) then
      rrdname = rrdname .. getPathFromKey(host_or_network) .. "/"
   end

   return os_utils.fixPath(rrdname..(rrdFile or ''))
end

-- ########################################################

function getPathFromMac(addr)
   if not isMacAddress(addr) then return end

   local mac = {}
   local vlan = addr:match("@%d+$") or ''

   for i, p in ipairs(addr:split(":")) do
      mac[i] = string.format('%.2x', tonumber(p, 16) or 0)
   end

   local manufacturer = {mac[1], mac[2], mac[3]}
   local nic = {mac[4], mac[5], mac[6]}

   -- each manufacturer has its own directory
   local res = os_utils.fixPath("macs/"..table.concat(manufacturer, "_"))
   -- the nic identifier goes as-is because it is non structured
   res = os_utils.fixPath(res.."/"..table.concat(nic, "/"))
   -- finally the vlan
   res = res..vlan

   return res
end

-- ##############################################

function getPathFromIPv6(addr)
   local ipv6 = {"0000", "0000", "0000", "0000",
		 "0000", "0000", "0000", "0000"}

   local ip, subnet = (addr or ''):match("([^/]+)/?(%d*)")

   if ip == nil then ip = '' end
   if subnet == nil then subnet = '' end

   local prefix = ip or ''
   local suffix = ''
   if ip:find("::") then
      local s = ip:gsub("::","x")
      local t = s:split("x")
      prefix, suffix = t[1] or '', t[2] or ''
   end

   for i, p in ipairs(prefix:split(":") or {prefix}) do
      ipv6[i] = string.format('%.4x', tonumber(p, 16) or 0)
   end

   local i = 1
   for _, p in pairsByKeys(suffix:split(":") or {suffix}, rev) do
      ipv6[8 - i + 1] = string.format('%.4x', tonumber(p, 16) or 0)
      i = i + 1
   end

   local most_significant = {ipv6[1], ipv6[2], ipv6[3], ipv6[4]}
   local interface_identifier = {ipv6[5], ipv6[6], ipv6[7], ipv6[8]}

   -- most significant part of the address goes in a hierarchical structure
   local res = table.concat(most_significant, "/")
   -- the interface identifies goes as-is because it is non structured
   res = os_utils.fixPath(res.."/"..table.concat(interface_identifier, "_"))

   if not isEmptyString(subnet) then
      res = os_utils.fixPath(res.."/"..subnet)
   end

   return res
end

-- ##############################################

function getPathFromKey(key)
   if key == nil then key = "" end

   if isIPv6(key) then
      return getPathFromIPv6(key)
   elseif isMacAddress(key) then
      return getPathFromMac(key)
   end

   key = tostring(key):gsub("[%.:]", "/")

   return os_utils.fixPath(key)
end
