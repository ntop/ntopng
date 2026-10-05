--
-- (C) 2013-26 - ntop.org
--

local icmp_utils = {}

local clock_start = os.clock()

icmp_utils.ICMP_PROTOCOL = 1
icmp_utils.ICMPv6_PROTOCOL = 58

-- #######################

-- Maps an L4 protocol, either as a numeric id or as a protocol
-- name ("ICMP", "IPv6-ICMP"), to the ICMP version (4 or 6)
function icmp_utils.icmp_version_from_l4(l4_proto)
  local proto_id = tonumber(l4_proto)

  if(proto_id ~= nil) then
     return ternary(proto_id == icmp_utils.ICMPv6_PROTOCOL, 6, 4)
  end

  return ternary(string.upper(tostring(l4_proto or "")) == "IPV6-ICMP", 6, 4)
end

-- #######################

-- Reads the icmp_info locale table, which follows the two IANA registries
local function icmp_info_i18n(icmp_version, key)
   local res

   icmp_version = tonumber(icmp_version)

   if(icmp_version ~= 6) then res = i18n("icmp_info.icmp." .. key) end
   if(isEmptyString(res) and (icmp_version ~= 4)) then res = i18n("icmp_info.icmpv6." .. key) end

   return res or ""
end

-- #######################

function icmp_utils.get_icmp_type(icmp_type, omit_number, icmp_version)
   local icmp_type_string = icmp_info_i18n(icmp_version, "type." .. tostring(icmp_type) .. ".info")

   if isEmptyString(icmp_type_string) then
      -- Type numbers outside the IANA registries are unassigned
      icmp_type_string = string.format("%s (%s)", i18n("icmp_page.unassigned"), icmp_type)
   else
      if(omit_number ~= true) then
	      icmp_type_string = string.format("%s (%u)", icmp_type_string, icmp_type)
      end
   end

   return icmp_type_string 
end

-- #######################

function icmp_utils.get_icmp_type_label(icmp_type, icmp_version)
   return string.format("%s: %s", i18n("icmp_page.icmp_type"), icmp_utils.get_icmp_type(icmp_type, false, icmp_version)) 
end

-- #######################

function icmp_utils.get_icmp_code(icmp_type, icmp_code, icmp_version)
   local icmp_code_string = icmp_info_i18n(icmp_version,
      "type." .. tostring(icmp_type) .. ".code." .. tostring(icmp_code))

   if isEmptyString(icmp_code_string) then
      icmp_code_string = tostring(icmp_code)
   else
      icmp_code_string = string.format("%s (%u)", icmp_code_string, icmp_code)
   end

   return icmp_code_string 
end

-- #######################

function icmp_utils.get_icmp_code_label(icmp_type, icmp_code, icmp_version)
   return string.format("%s: %s", i18n("icmp_page.icmp_code"), icmp_utils.get_icmp_code(icmp_type, icmp_code, icmp_version)) 
end

-- #######################

function icmp_utils.get_icmp_label(icmp_type, icmp_code, icmp_version)
   return(icmp_utils.get_icmp_type(icmp_type, false, icmp_version))
end

if(trace_script_duration ~= nil) then
  io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

-- #######################

-- See Flow::incStats()
function icmp_utils.is_suspicious_entropy(e_min, e_max)
   local diff = e_max - e_min
   
   if((e_min < 5) or (e_max >= 6) or (diff > 0.3)) then
      return true
   else
      return false
   end
end

return icmp_utils
