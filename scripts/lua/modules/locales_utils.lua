--
-- (C) 2014-18 - ntop.org
--

i18n = require "i18n"
local dirs = ntop.getDirs()

local locales = {}

-- ##############################################

local default_locale = "en"
local default_locale_path = dirs.installdir..'/scripts/locales/en.lua'
local available_locales = {}
local locales_initialized = false

local supported_locales = {
   {code = "en"},
   {code = "it"},
   {code = "de"},
   {code = "jp"},
   {code = "pt"},
   {code = "cz"}
}

-- ##############################################

function locales.loadLocaleFile(path, locale)
  local chunk = assert(loadfile(path))
  local data = chunk()

  -- Check if plugin specific locales exist
  local plugins_locales = dirs.workingdir .. "/plugins/locales/" .. locale .. ".lua"

  if ntop.exists(plugins_locales) then
    local chunk = assert(loadfile(plugins_locales))
    local plugins_data = chunk()

    -- Add the plugins localized strings
    for k, v in pairs(plugins_data) do
      data[k] = v
    end
  end
  
  i18n.load({[locale]=data})
end

-- ##############################################

local function lookupLocale(localename)
   local base_path = dirs.installdir..'/scripts/locales/'
   local locale_path = base_path .. localename .. ".lua"

   if ntop.exists(locale_path) then
      return locale_path
   end

   return nil
end

-- ##############################################

local function initLocales()
   if(locales_initialized) then
      -- Already initialized
      return
   end

   -- Provides a fallback for not already localized strings
   locales.loadLocaleFile(default_locale_path, default_locale)

   locales.default_locale = default_locale

   -- language is a global variable set from C that corresponds to the user default language
   -- it may be null when lua_utils are imported from periodic scripts
   if language == nil then
      local admin_lang = ntop.getPref("ntopng.user.admin.language")
      language = ternary(isEmptyString(admin_lang), locales.default_locale, admin_lang)
   end

   i18n.setLocale(language)

   -- Note: en already loaded
   if (language ~= "en") and (not ntop.isnEdge()) then
      local locale_path = lookupLocale(language)

      if locale_path then
         locales.loadLocaleFile(locale_path, language)
      end
   end

   -- use pairsByKeys to impose an order
   for _, locale in ipairs(supported_locales) do
      local localename = locale["code"]

      if lookupLocale(localename) then
         available_locales[#available_locales + 1] = locale
      end
   end

   locales_initialized = true
end

-- ##############################################

function locales.getAvailableLocales()
   initLocales()

   return available_locales
end

-- ##############################################

function locales.readDefaultLocale()
  local path = default_locale_path
  local chunk = assert(loadfile(path))
  local data = chunk()

  return(data)
end

-- ##############################################

-- Locales lazy loading: only load them when a script calls i18n(...)
local orig_i18n_metatable = getmetatable(i18n)
local i18n_mt = {}

-- Replace the i18n(...) invocation
function i18n_mt.__call(...)
   -- ensure that the loacales are loaded
   initLocales()

   -- call the original i18n function
   return(orig_i18n_metatable.__call(...))
end

setmetatable(i18n, i18n_mt)

-- ##############################################

return locales
