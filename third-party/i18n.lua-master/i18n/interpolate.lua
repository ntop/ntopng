local unpack = unpack or table.unpack -- lua 5.2 compat

-- matches a string of type %{age}
local function interpolateValue(string, variables)
  return string:gsub("(.?)%%{%s*(.-)%s*}",
    function (previous, key)
      if previous == "%" then
        return
      else
        return previous .. tostring(variables [key])
      end
    end)
end

-- matches a string of type %<age>.d
local function interpolateField(string, variables)
  return string:gsub("(.?)%%<%s*(.-)%s*>%.([cdEefgGiouXxsq])",
    function (previous, key, format)
      if previous == "%" then
        return
      else
        return previous .. string.format("%" .. format, variables[key] or "nil")
      end
    end)
end

local DEBUG = false

local function interpolate(pattern, variables)
  variables = variables or {}
  local result = pattern
  result = interpolateValue(result, variables)
  result = interpolateField(result, variables)

  if not DEBUG then
    result = string.format(result, unpack(variables))
  else
    local err, res = pcall(function () result = string.format(result, unpack(variables)) end)

    if err then
      tprint(debug.traceback())
      return(result)
    else
      result = res
    end
  end

  return result
end

return interpolate
