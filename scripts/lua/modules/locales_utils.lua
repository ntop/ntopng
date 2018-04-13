--
-- (C) 2014-18 - ntop.org
--

i18n = require "i18n"

function i18n.loadLocaleFile(path, locale)
  local chunk = assert(loadfile(path))
  local data = chunk()
  i18n.load({[locale]=data})
end

-- Provides a fallback for not already localized strings
i18n.loadLocaleFile(dirs.installdir..'/scripts/locales/en.lua', "en")

local locales = {}

locales.default_locale = "en"

-- language is a global variable set from C that corresponds to the user default language
-- it may be null when lua_utils are imported from periodic scripts
if language == nil then
   language = locales.default_locale
end

i18n.setLocale(language)

local common_locales = {
   {code="en", name=i18n("locales.en")},
}

local pro_only_locales = {
   {code="it", name=i18n("locales.it")},
   {code="de", name=i18n("locales.de")},
}

local function lookupLocale(localename, is_pro)
   local base_path
   local arr

   if not is_pro then
      base_path = dirs.installdir..'/scripts/locales/'
      arr = common_locales
   else
      base_path = dirs.installdir..'/scripts/lua/pro/../locales/'
      arr = pro_only_locales
   end

   for _, locale in pairs(arr) do
      if locale.code == localename then
         return base_path .. localename .. ".lua"
      end
   end

   return nil
end

-- Note: en already loaded
if (language ~= "en") and (not ntop.isnEdge()) then
   local locale_path = lookupLocale(language, false) or (ntop.isPro() and lookupLocale(language, true))

   if locale_path then
      i18n.loadLocaleFile(locale_path, language)
   end
end

local available_locales = {}

for _, locale in ipairs(common_locales) do
   available_locales[#available_locales + 1] = locale
end

if ntop.isPro() then
   for _, locale in ipairs(pro_only_locales) do
      available_locales[#available_locales + 1] = locale
   end
end

function locales.getAvailableLocales()
   return available_locales
end

return locales
