--
-- (C) 2013-21 - ntop.org
--

local icmp_utils = {}

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

function icmp_utils.get_icmp_type_label(ip_version, icmp_type)
   local key = string.format("icmp_v%u_types.type_%u", ip_version, icmp_type)
   local res = i18n(key)

   return res or ""
end

-- #######################

function icmp_utils.get_icmp_code_label(ip_version, icmp_type, icmp_code)
   local key = string.format("icmp_v%u_codes.type_%u.code_%u", ip_version, icmp_type, icmp_code)
   local res = i18n(key)

   return res or ""
end

-- #######################

function icmp_utils.get_icmp_label(ip_version, icmp_type, icmp_code)
   if not icmp_locale_loaded then
      load_icmp_locale()
   end

   local type_label = icmp_utils.get_icmp_type_label(ip_version, icmp_type)
   local code_label = icmp_utils.get_icmp_code_label(ip_version, icmp_type, icmp_code)

   if not isEmptyString(code_label) then
      return code_label
   else
      return type_label
   end
end


return icmp_utils
