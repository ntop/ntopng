--
-- (C) 2013-18 - ntop.org
--

--- Simple class for JSON parsing

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local parseElement

local function skipWhitespaces(content, pos)
  local _,nend = content:find("^[ \n\r\t]+", pos)
  if (nend ~= nil) then
     return nend+1
  else
     return pos
  end
end

local function parseNumber(content, pos)
  -- Integer part
  local integer_part = content:match('^-?[1-9]%d*', pos)
                       or content:match("^-?0", pos)

  if not integer_part then
    return nil
  end

  -- Decimal part
  local lstart = pos + integer_part:len()
  local decimal_part = content:match('^%.%d+', i) or ""
  lstart = lstart + decimal_part:len()

  -- Exponential
  local exponent_part = content:match('^[eE][-+]?%d+', i) or ""
  lstart = lstart + exponent_part:len()
  local full_number_text = integer_part .. decimal_part .. exponent_part
  local cnumber = tonumber(full_number_text)

  if not cnumber then
    return nil
  end

  return cnumber, lstart
end

local function parseString(content, pos)
  if (content:sub(pos, pos) ~= '"') then
    return ""
  end
  local i = pos + 1
  local clen = content:len()
  local val = ""

  while (i <= clen) do
    local c = content:sub(i, i)
    if (c == '"') then
      return val, i+1
    end
    val = val..c
    i = i + 1
  end

  return ""
end

local function parseObject(content, pos)
  if (content:sub(pos, pos) ~= '{') then
    return {}, pos
  end
  local lstart = skipWhitespaces(content, pos+1)
  local val = {}

  -- Handle empty array
  if (content:sub(lstart, lstart) == '}') then
    return val, lstart+1
  end

  local clen = content:len()
  while (lstart <= clen) do
    local key, nstart = parseString(content, lstart)
    lstart = skipWhitespaces(content, nstart)
    if (content == nil or lstart == nil or
        content:sub(lstart, lstart) ~= ':') then
      return {}, lstart
    end
    lstart = skipWhitespaces(content, lstart+1)
    local nval, nstart = parseElement(content, lstart)
    val[key] = nval
    -- We have key and value, must have a } or a ,
    lstart = skipWhitespaces(content, nstart)
    if (content == nil or lstart == nil) then
      return {}, clen
    end
    if (content:sub(lstart, lstart) == '}') then
      return val, lstart+1
    end
    if (content:sub(lstart, lstart) ~= ',') then
      return {}, lstart
    end
    lstart = skipWhitespaces(content, lstart+1) -- skip comma
  end

  return {}, lstart
end

local function parseArray(content, pos)
  if (content:sub(pos, pos) ~= '[') then
    return {}, pos
  end

  local lstart = skipWhitespaces(content, pos+1)
  local val = {}
  -- Handle empty array
  if (content:sub(lstart, lstart) == ']') then
    return val, lstart+1
  end
  local idx = 1 -- keep 1 to n convention
  local clen = content:len()

  while (lstart <= clen) do
    local nval, nstart = parseElement(content, lstart)
    val[idx] = nval
    idx = idx + 1
    lstart = skipWhitespaces(content, nstart)
    -- Need a ] or a , now
    if (content == nil or lstart == nil) then
      return {}, clen
    end
    if (content:sub(lstart, lstart) == ']') then
      return val, lstart+1
    end
    if (content:sub(lstart, lstart) ~= ',') then
      return {}, lstart
    end
    lstart = skipWhitespaces(content, lstart+1)
  end
  return {}, lstart
end

parseElement = function(content, pos)
  pos = skipWhitespaces(content, pos)

  if (pos > content:len()) then
    return {}, pos
  end

  if (content:find('^"', pos)) then
    return parseString(content, pos)
  elseif (content:find('^[-0123456789 ]', pos)) then
    return parseNumber(content, pos)
  elseif (content:find('^%{', pos)) then
    return parseObject(content, pos)
  elseif (content:find('^%[', pos)) then
    return parseArray(content, pos)
  else
    return {}, pos
  end
end

-- Exposed methods:
-- printTable: prints an indented version of a JSON parsing table
-- parseJSON: creates a table from a JSON

function printTable(tbl, indent)
  if (tbl == nil) then return end
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      io.write(formatting)
      printTable(v, indent+1)
    elseif type(v) == 'boolean' then
      io.write(formatting .. tostring(v).."\n")
    else
      io.write(formatting .. v.."\n")
    end
  end
end

function parseJSON(content)
  if (content == nil) then return {} end
  local table = parseElement(content, 1)
  --printTable(table)
  return table
end
