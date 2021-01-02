--
-- (C) 2014-21 - ntop.org
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

local nedge_supported_locales = {
   ["jp"] = true,
   ["en"] = true,
}

-- ##############################################

local function loadfile_to_data(file_path)
  local data = {}
  -- `loadfile` opens the named `file_path`, parses it and returns the compiled chunk as a function.
  -- Does not execute it.
  local chunk = assert(loadfile(file_path))

  data = chunk()

  -- Execution can return nil when the parsed `file_path` does not end with a return statement
  if not data then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Execution of loaded chunk returned nil for %s", file_path))
  end

  return data or {}
end

-- ##############################################

function locales.loadLocaleFile(path, locale)
  local data = loadfile_to_data(path)
  local os_utils = require("os_utils")
  local plugins_utils = require("plugins_utils")

  -- Check if plugin specific locales exist
  local plugins_locales = os_utils.fixPath(plugins_utils.getRuntimePath() .. "/locales/" .. locale .. ".lua")

  if ntop.exists(plugins_locales) then
     local plugins_data = loadfile_to_data(plugins_locales)

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

   local is_nedge = ntop.isnEdge()

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
   if ((not is_nedge) or nedge_supported_locales[language]) then
      local locale_path = lookupLocale(language)

      if locale_path then
         locales.loadLocaleFile(locale_path, language)
      end
   end

   -- use pairsByKeys to impose an order
   for _, locale in ipairs(supported_locales) do
      local localename = locale["code"]

      if ((not is_nedge) or nedge_supported_locales[localename]) and lookupLocale(localename) then
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
  local data = loadfile_to_data(default_locale_path)

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
