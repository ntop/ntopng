--
-- (C) 2018 - ntop.org
--

-- This file contains a small set of utility functions

-- ##############################################

function string.starts(String,Start)
   if type(String) ~= 'string' or type(Start) ~= 'string' then
      return false
   end
   return string.sub(String,1,string.len(Start))==Start
end

-- ##############################################

function string.ends(String,End)
   if type(String) ~= 'string' or type(End) ~= 'string' then
      return false
   end
   return End=='' or string.sub(String,-string.len(End))==End
end

-- ##############################################

-- Print contents of `tbl`, with indentation.
-- You can call it as tprint(mytable)
-- The other two parameters should not be set
function tprint(s, l, i)
   l = (l) or 1000; i = i or "";-- default item limit, indent string
   if (l<1) then io.write("ERROR: Item limit reached.\n"); return l-1 end;
   local ts = type(s);
   if (ts ~= "table") then io.write(i..' '..ts..' '..tostring(s)..'\n'); return l-1 end
   io.write(i..' '..ts..'\n');
   for k,v in pairs(s) do
      local indent = ""

      if(i ~= "") then
         indent = i .. "."
      end
      indent = indent .. tostring(k)

      l = tprint(v, l, indent);
      if (l < 0) then break end
   end

   return l
end

-- ##############################################

--
-- Concatenates table keys to values with separators
--
-- Parameters
--    keys_values: the table which contains the items
--    kv_sep: a string to be put between a key and a value
--    group_sep: a string to be put between key-value groups
--    last_sep: a string to be put after last value, if table is not empty
--    value_quote: a string to be used to quote values
--
function table.tconcat(keys_values, kv_sep, group_sep, last_sep, value_quote)
  local groups = {}
  kv_sep = kv_sep or ""
  group_sep = group_sep or ""
  last_sep = last_sep or ""
  value_quote = value_quote or ""

  for k, v in pairs(keys_values) do
    local parts = {k, kv_sep, value_quote, v, value_quote}
    groups[#groups + 1] = table.concat(parts, "")
  end

  if #groups > 0 then
    return table.concat(groups, group_sep) .. last_sep
  else
    return ""
  end
end

-- ##############################################

function table.empty(tbl)
  if(tbl == nil) then return true end

  if next(tbl) == nil then
    return true
  end

  return false
end

-- ##############################################

function isIPv6(ip)
  return((not isEmptyString(ip)) and ntop.isIPv6(ip))
end

-- ##############################################

function firstToUpper(str)
   str = tostring(str)
   return (str:gsub("^%l", string.upper))
end

-- ##############################################

function pairsByKeys(t, f)
  local a = {}

  -- io.write(debug.traceback().."\n")
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

-- ##############################################

function pairsByValues(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, function(x, y) return f(t[x], t[y]) end)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

-- ##############################################

function pairsByField(t, field, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end

  table.sort(a, function(x, y) return f(t[x][field], t[y][field]) end)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

-- ##############################################

function asc(a,b)
  return (a < b)
end

-- ##############################################

function rev(a,b)
   return (a > b)
end

-- ##############################################

function asc_insensitive(a,b)
  if type(a) ~= "string" then return asc(a,b) end
  return (string.lower(a) < string.lower(b))
end

-- ##############################################

function rev_insensitive(a,b)
  if type(a) ~= "string" then return rev(a,b) end
  return (string.lower(a) > string.lower(b))
end

-- ##############################################

function string.split(s, p)
  local temp = {}
  local index = 0
  local last_index = string.len(s)

  while true do
    local i, e = string.find(s, p, index)

    if i and e then
      local next_index = e + 1
      local word_bound = i - 1
      table.insert(temp, string.sub(s, index, word_bound))
      index = next_index
    else
      if index > 0 and index <= last_index then
        table.insert(temp, string.sub(s, index, last_index))
      elseif index == 0 then
        temp = nil
      end
      break
    end
  end

  return temp
end

-- ##############################################

function isMacAddress(address)

  if (address == nil) then return false end

   if(string.match(address, "^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") ~= nil)  or
     (string.match(address, "^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x%@%d+$") ~= nil) then
      return true
   end
   return false
end

-- ##############################################

function isEmptyString(str)
  if((str == nil) or (str == "")) then
    return true
  else
    return false
  end
end

-- ##############################################

function ternary(cond, T, F)
   if cond then return T else return F end
end

-- ##############################################

function isAdministrator()
   return ntop.isAdministrator()
end

-- ##############################################

function getSystemInterfaceId()
   -- NOTE: keep in sync with SYSTEM_INTERFACE_ID in ntop_defines.h
   -- This must be a string as it is passed in interface.select
   return "-1"
end

-- ##############################################

function getSystemInterfaceName()
   -- NOTE: keep in sync with SYSTEM_INTERFACE_NAME in ntop_defines.h
   return "__system__"
end
