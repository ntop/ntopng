--
-- A script to find unused strings in en.lua localization script
--

package.path = "../scripts/locales/?.lua"

-- ************************************************************

-- The locale file to check
local locale = "en"

-- If true, only unused strings will be printed
local quiet = true

-- This contains a list of paths to search the localized strings uses
local search_paths = {
  "../scripts/lua",
  "../pro/scripts/lua",
}

-- This contains a list of key prefixes to ignore
local prefix_ignore = {
  "alert_messages.",
  "show_alerts.host_delete_config_confirm",
  "show_alerts.network_delete_config_confirm",
  "show_alerts.iface_delete_config_confirm",
  "policy_presets.",
}

-- ************************************************************

local locale_strings = require(locale)

local function execCmd(command)
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  return result
end

-- Checks for unused strings
local function check_unused(key, value)
  local paths = table.concat(search_paths, " ")
  local found = false

  for _, ignore in pairs(prefix_ignore) do
    if string.sub(key, 1, string.len(ignore)) == ignore then
      return
    end
  end

  for _, quotes in ipairs({"\\\"", "'"}) do
    local cmd = "find " .. paths .. " -name \"*.lua\" -type f -exec grep -m 1 -F \"i18n(" .. quotes .. key .. quotes .. "\" {} \\;"

    local res = execCmd(cmd)
    if res ~= "" and res ~= nil then
      found = true
      break
    end
  end

  if not quiet or not found then
    print(key)
  end

  if not found and not quiet then
    print("\tNot Found!")
  end
end

local function expand_keys(prefix, key_vals)
  for k, v in pairs(key_vals) do
    local value_type = type(v)
    -- push
    prefix[#prefix + 1] = k

    if value_type == "string" then
      local key = table.concat(prefix, ".")

      check_unused(key, v)
    elseif value_type == "table" then
      -- recursion
      expand_keys(prefix, v)
    else
      print("Error: unknown type '" .. value_type .. "'")
      os.exit(1)
    end

    -- pop
    prefix[#prefix] = nil
  end
end

expand_keys({}, locale_strings[locale])
