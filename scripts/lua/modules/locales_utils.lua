--
-- (C) 2014-17 - ntop.org
--
i18n = require "i18n"
i18n.loadFile(dirs.installdir..'/scripts/locales/it.lua')
i18n.loadFile(dirs.installdir..'/scripts/locales/en.lua')

local locales = {}

locales.default_locale = "en"

-- language is a global variable set from C that corresponds to the user default language
-- it may be null when lua_utils are imported from periodic scripts
if language == nil then
   language = locales.default_locale
end

i18n.setLocale(language)

local available_locales = {
   {code="en", name=i18n("locales.en")},
   -- {code="it", name=i18n("locales.it")}
}

function locales.getAvailableLocales()
   return available_locales
end

return locales
