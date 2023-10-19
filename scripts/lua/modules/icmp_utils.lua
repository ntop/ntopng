--
-- (C) 2013-23 - ntop.org
--

local icmp_utils = {}

local clock_start = os.clock()

local icmp_locale_loaded = false
local dirs = ntop.getDirs()

local function get_icmp_locale_path(locale)
   local locale_path = dirs.installdir .. "/scripts/locales/icmp/" .. locale .. ".lua"

   return locale_path
end

-- #######################

local function load_icmp_locale()
   local to_load = {i18n.getLocale()}

   if i18n.getFallbackLocale() ~= i18n.getLocale() then
      to_load[#to_load + 1] = i18n.getFallbackLocale()
   end

   for _, cur_locale in ipairs(to_load) do
      local cur_locale_path = get_icmp_locale_path(cur_locale)

      if ntop.exists(cur_locale_path) then
	 i18n.load({
	       [cur_locale] = dofile(cur_locale_path)
	 })
      end
   end

   -- tprint({cur = current_locale, fb = fallback_locale, selected = selected_locale, cane = i18n("icmp_v4_types.type_000")})
   icmp_locale_loaded = true
end

-- #######################

function icmp_utils.get_icmp_type(icmp_type, omit_number)
  local icmp_type_string = i18n("icmp_info.type." .. tostring(icmp_type) .. ".info") or ""


  if isEmptyString(icmp_type_string) then
    icmp_type_string = tostring(icmp_type)
  else
     if(omit_number ~= true) then
	icmp_type_string = string.format("%s (%u)", icmp_type_string, icmp_type)
     end
  end

  return icmp_type_string 
end

-- #######################

function icmp_utils.get_icmp_type_label(icmp_type)
  return string.format("%s: %s", i18n("icmp_page.icmp_type"), icmp_utils.get_icmp_type(icmp_type)) 
end

-- #######################

function icmp_utils.get_icmp_code(icmp_type, icmp_code)
  local icmp_code_string = i18n("icmp_info.type." .. tostring(icmp_type) .. ".code." .. tostring(icmp_code)) or ""

  if isEmptyString(icmp_code_string) then
    icmp_code_string = tostring(icmp_type)
  else
    icmp_code_string = string.format("%s (%u)", icmp_code_string, icmp_type)
  end

  return icmp_code_string 
end

-- #######################

function icmp_utils.get_icmp_code_label(icmp_type, icmp_code)
  return string.format("%s: %s", i18n("icmp_page.icmp_code"), icmp_utils.get_icmp_code(icmp_type, icmp_code)) 
end

-- #######################

function icmp_utils.get_icmp_label(icmp_type, icmp_code)
  if not icmp_locale_loaded then
    load_icmp_locale()
  end

  -- local type_label = icmp_utils.get_icmp_type_label(icmp_type)
  --local code_label = icmp_utils.get_icmp_code_label(icmp_type, icmp_code)
  -- return string.format("%s, %s", type_label, code_label)

  return(icmp_utils.get_icmp_type(icmp_type))
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
