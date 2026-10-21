local i18n = {}

local store
local translationCache, fallbacksCache = {}, {}
local function clearCaches()
  translationCache = {}
  fallbacksCache = {}
end
local locale
local pluralizeFunction
local defaultLocale = 'en'
local fallbackLocale = defaultLocale

local currentFilePath = (...):gsub("%.init$","")

local plural      = require(currentFilePath .. '.plural')
local interpolate = require(currentFilePath .. '.interpolate')
local variants    = require(currentFilePath .. '.variants')
local version     = require(currentFilePath .. '.version')

i18n.plural, i18n.interpolate, i18n.variants, i18n.version, i18n._VERSION =
  plural, interpolate, variants, version, version

-- private stuff

local function dotSplit(str)
  local fields, length = {},0
    str:gsub("[^%.]+", function(c)
    length = length + 1
    fields[length] = c
  end)
  return fields, length
end

local function isPluralTable(t)
  return type(t) == 'table' and type(t.other) == 'string'
end

local function isPresent(str)
  return type(str) == 'string' and #str > 0
end

local function assertPresent(functionName, paramName, value)
  if isPresent(value) then return end

  local msg = "i18n.%s requires a non-empty string on its %s. Got %s (a %s value). %s"
  error(msg:format(functionName, paramName, tostring(value), type(value), debug.traceback()))
end

local function assertPresentOrPlural(functionName, paramName, value)
  if isPresent(value) or isPluralTable(value) then return end

  local msg = "i18n.%s requires a non-empty string or plural-form table on its %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertPresentOrTable(functionName, paramName, value)
  if isPresent(value) or type(value) == 'table' then return end

  local msg = "i18n.%s requires a non-empty string or table on its %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertFunctionOrNil(functionName, paramName, value)
  if value == nil or type(value) == 'function' then return end

  local msg = "i18n.%s requires a function (or nil) on param %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function defaultPluralizeFunction(count)
  return plural.get(variants.root(i18n.getLocale()), count)
end

local function pluralize(t, data)
  assertPresentOrPlural('interpolatePluralTable', 't', t)
  data = data or {}
  local count = data.count or 1
  local plural_form = pluralizeFunction(count)
  return t[plural_form]
end

local function treatNode(node, data)
  if type(node) == 'string' then
    return interpolate(node, data)
  elseif isPluralTable(node) then
    return interpolate(pluralize(node, data), data)
  end
  return node
end

local function recursiveLoad(currentContext, data)
  local composedKey
  for k,v in pairs(data) do
    composedKey = (currentContext and (currentContext .. '.') or "") .. tostring(k)
    assertPresent('load', composedKey, k)
    assertPresentOrTable('load', composedKey, v)
    if type(v) == 'string' then
      i18n.set(composedKey, v)
    else
      recursiveLoad(composedKey, v)
    end
  end
end

-- ntop patch: locale tables are adopted as-is (not flattened key by key), so keys that
-- contain dots ("a.b" stored as a single key) must be resolved by joining path segments
local function resolveDotted(node, path, i, length)
  if type(node) ~= 'table' then return nil end

  local key, j = path[i], i

  while true do
    local child = node[key]

    if child ~= nil then
      if j == length then return child end
      local r = resolveDotted(child, path, j + 1, length)
      if r ~= nil then return r end
    end

    j = j + 1
    if j > length then return nil end
    key = key .. "." .. path[j]
  end
end

local function localizedTranslate(key, loc, data)
  local path, length = dotSplit(loc .. "." .. key)
  local node = store

  for i=1, length do
    local child = node[path[i]]
    if not child then
      -- Slow path: dotted keys
      node = resolveDotted(store, path, 1, length)
      if not node then return nil end
      break
    end
    node = child
  end

  return treatNode(node, data)
end

-- public interface

function i18n.set(key, value)
  assertPresent('set', 'key', key)
  assertPresentOrPlural('set', 'value', value)

  local path, length = dotSplit(key)
  local node = store

  for i=1, length-1 do
    key = path[i]
    node[key] = node[key] or {}
    node = node[key]
  end

  local lastKey = path[length]
  node[lastKey] = value
  clearCaches()
end

-- ntop patch: memoize translations requested without interpolation data. i18n() is called multiple times
function i18n.translate(key, data)
  local cacheable = (data == nil) or (next(data) == nil)
  local usedLocale

  if cacheable then
    usedLocale = locale
    local lc = translationCache[usedLocale]
    if lc then
      -- Only valid keys are ever stored in the cache, no need to validate them again on a hit
      local hit = lc[key]
      if hit ~= nil then return hit or nil end
    end
  else
    usedLocale = data.locale or locale
  end

  assertPresent('translate', 'key', key)

  data = data or {}

  local fbKey = usedLocale .. "\0" .. fallbackLocale
  local fallbacks = fallbacksCache[fbKey]
  if not fallbacks then
    fallbacks = variants.fallbacks(usedLocale, fallbackLocale)
    fallbacksCache[fbKey] = fallbacks
  end

  local result = nil
  for i=1, #fallbacks do
    local value = localizedTranslate(key, fallbacks[i], data)
    if value then result = value break end
  end

  if result == nil then result = data.default end

  if cacheable and data.default == nil then
    local lc = translationCache[usedLocale]
    if not lc then lc = {}; translationCache[usedLocale] = lc end
    lc[key] = result or false
  end

  return result
end

function i18n.setLocale(newLocale, newPluralizeFunction)
  assertPresent('setLocale', 'newLocale', newLocale)
  assertFunctionOrNil('setLocale', 'newPluralizeFunction', newPluralizeFunction)
  locale = newLocale
  pluralizeFunction = newPluralizeFunction or defaultPluralizeFunction
  clearCaches()
end

function i18n.setFallbackLocale(newFallbackLocale)
  assertPresent('setFallbackLocale', 'newFallbackLocale', newFallbackLocale)
  fallbackLocale = newFallbackLocale
  clearCaches()
end

function i18n.getFallbackLocale()
  return fallbackLocale
end

function i18n.getLocale()
  return locale
end

function i18n.reset()
  store = {}
  clearCaches()
  plural.reset()
  i18n.setLocale(defaultLocale)
  i18n.setFallbackLocale(defaultLocale)
end

-- ntop patch: fast merge of an already nested table into the store, avoiding the
-- per-key dotSplit() done by i18n.set().
local function fastMerge(dest, data, currentContext)
  for k, v in pairs(data) do
    local key = (type(k) == 'string') and k or tostring(k)
    local vt = type(v)

    if key == "" or key:find(".", 1, true) then
      -- Slow path: i18n.set splits the key on dots
      local composedKey = (currentContext and (currentContext .. '.') or "") .. key
      assertPresent('load', composedKey, key)
      if vt == 'string' then
        i18n.set(composedKey, v)
      else
        recursiveLoad(composedKey, v)
      end
    elseif vt == 'string' then
      dest[key] = v
    elseif vt == 'table' then
      if next(v) ~= nil then
        local node = dest[key]
        if type(node) ~= 'table' then
          node = {}
          dest[key] = node
        end
        fastMerge(node, v, (currentContext and (currentContext .. '.') or "") .. key)
      end
    else
      assertPresentOrTable('load', key, v)
    end
  end
end

function i18n.load(data)
  for loc, tbl in pairs(data) do
    if type(loc) == 'string' and type(tbl) == 'table' and store[loc] == nil then
      -- Adopt the (already nested) table without copying it: no per-key work at all
      store[loc] = tbl
    else
      fastMerge(store, {[loc] = tbl}, nil)
    end
  end
  clearCaches()
end

function i18n.loadFile(path)
  local chunk = assert(loadfile(path))
  local data = chunk()
  i18n.load(data)
end

setmetatable(i18n, {__call = function(_, ...) return i18n.translate(...) end})

i18n.reset()

return i18n
