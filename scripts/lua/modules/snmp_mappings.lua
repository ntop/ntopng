--
-- (C) 2020-22 - ntop.org
--
-- This file is used to report SNMP interface information sent by nprobe with --snmp-mappings

-- ################################################################################

local snmp_mappings = {}

local _localcache   = {}

local _prefix  = "cachedexporters."
local _postfix = ".ifnames"

-- ################################################################################

function snmp_mappings.get_all_exporters()
   local key = _prefix.."*".._postfix
   local rsp = ntop.getKeysCache(key)
   local rc = {}
   
   if(rsp ~= nil) then
      local len = string.len(_prefix) + 1
      local postfix_len = string.len(_postfix)
      
      for k,v in pairs(rsp) do
	 local len1
	 
	 k = string.sub(k, len)

	 len1 = string.len(k) - postfix_len
	 k = string.sub(k, 1, len1)

	 table.insert(rc, k)
      end
   end

   return(rc)
end

-- ################################################################################

local function _cache_device(snmp_device_ip)
   if(_localcache[snmp_device_ip] == nil) then
      local key = _prefix..snmp_device_ip.._postfix
     
      local rsp = ntop.getCache(key)
      
      if((rsp ~= nil) and (rsp ~= "")) then
	 local json = require "dkjson"

	 _localcache[snmp_device_ip] = json.decode(rsp) or {}
      else
	 _localcache[snmp_device_ip] = {}
      end      
   end
end

-- ################################################################################

function snmp_mappings.get_iface_names(snmp_device_ip)
   local ports
   
   _cache_device(snmp_device_ip)   
   ports = _localcache[snmp_device_ip]
   
   return ports
end

-- ################################################################################

function snmp_mappings.get_iface_name(snmp_device_ip, if_idx)
   local ports
   
   _cache_device(snmp_device_ip)   
   ports = _localcache[snmp_device_ip]
   
   if_idx = if_idx .. "" --  to string

   if((ports[if_idx] ~= nil) and (ports[if_idx].name ~= nil)) then
      return(ports[if_idx].name)
   end

   return nil
end

-- ################################################################################

function snmp_mappings.get_iface_idx(snmp_device_ip, if_name)
   local ports
   
   _cache_device(snmp_device_ip)   
   ports = _localcache[snmp_device_ip]
   
   for idx, info in pairs(ports) do
      if info.name and info.name == if_name then
         return idx
      end
   end

   return nil
end

-- ################################################################################

return snmp_mappings
