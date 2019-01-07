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
   local admin_lang = ntop.getPref("ntopng.user.admin.language")
   language = ternary(isEmptyString(admin_lang), locales.default_locale, admin_lang)
end

i18n.setLocale(language)

local supported_locales = {
   en = {code = "en"},
   it = {code = "it"},
   de = {code = "de"},
   jp = {code = "jp"}
}

local function lookupLocale(localename, is_pro)
   local base_path = dirs.installdir..'/scripts/locales/'
   local locale_path = base_path .. localename .. ".lua"

   if ntop.exists(locale_path) and supported_locales[localename] then
      return locale_path
   end

   -- Look for pro-only locales
   if ntop.isPro() then
      base_path = dirs.installdir..'/scripts/lua/pro/../locales/'
      locale_path = base_path .. localename .. ".lua"

      if ntop.exists(locale_path) and supported_locales[localename] then
	 return locale_path
      end
   end

   return nil
end

-- Note: en already loaded
if (language ~= "en") and (not ntop.isnEdge()) then
   local locale_path = lookupLocale(language)

   if locale_path then
      i18n.loadLocaleFile(locale_path, language)
   end
end

local available_locales = {}

for localename, locale in pairs(supported_locales) do
   if lookupLocale(localename) then
      available_locales[#available_locales + 1] = locale
   end
end

function locales.getAvailableLocales()
   return available_locales
end

return locales
