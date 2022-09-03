--
-- (C) 2014-22 - ntop.org
--

local clock_start = os.clock()

-- GENERIC UTILS

-- split
function split(s, delimiter)
   result = {};
   if(s ~= nil) then
      if delimiter == nil then
         -- No delimiter, split all characters
         for match in s:gmatch"." do
   	    table.insert(result, match);
         end
      else
         -- Split by delimiter
         for match in (s..delimiter):gmatch("(.-)"..delimiter) do
   	    table.insert(result, match);
         end
      end
   end
   return result;
end

-- startswith
function startswith(s, char)
   return string.sub(s, 1, string.len(s)) == char
end

-- strsplit

function strsplit(s, delimiter)
   result = {};
   for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      if(match ~= "") then result[match] = true end
   end
    return result;
end

-- isempty
function isempty(array)
  local count = 0
  for _,__ in pairs(array) do
    count = count + 1
  end
  return (count == 0)
end

-- isin
function isin(s, array)
  if (s == nil or s == "" or array == nil or isempty(array)) then return false end
  for _, v in pairs(array) do
    if (s == v) then return true end
  end
  return false
end

-- hasKey
function hasKey(key, theTable)
   if((theTable == nil) or (theTable[key] == nil)) then
      return(false)
   else
      return(true)
   end
end

-- ###############################################

-- removes trailing/leading spaces
function trimString(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- ###############################################

-- removes all spaces
function trimSpace(what)
   if(what == nil) then return("") end
   return(string.gsub(string.gsub(what, "%s+", ""), "+%s", ""))
end

-- ###############################################

-- TODO: improve this function
function jsonencode(what)
   what = string.gsub(what, '"', "'")
   -- everything but all ASCII characters from the space to the tilde
   what = string.gsub(what, "[^ -~]", " ")
   -- cleanup line feeds and carriage returns
   what = string.gsub(what, "\n", " ")
   what = string.gsub(what, "\r", " ")
   -- escape all the remaining backslashes
   what = string.gsub(what, "\\", "\\\\")
   -- max 1 sequential whitespace
   what = string.gsub(what, " +"," ")
   return(what)
end

-- ###########################################

-- Merges table a and table b into a new table. If some elements are presents in
-- both a and b, b elements will have precedence.
-- NOTE: this does *not* perform a deep merge. Only first level is merged.
function table.merge(a, b)
  local merged = {}
  a = a or {}
  b = b or {}

  if((a[1] ~= nil) and (b[1] ~= nil)) then
    -- index based tables
    for _, t in ipairs({a, b}) do
       for _,v in pairs(t) do
         merged[#merged + 1] = v
       end
   end
  else
     -- key based tables
     for _, t in ipairs({a, b}) do
       for k,v in pairs(t) do
         merged[k] = v
       end
     end
  end

  return merged
end

-- ###########################################

-- Performs a deep copy of the table.
function table.clone(orig)
   local orig_type = type(orig)
   local copy

   if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in next, orig, nil do
         copy[table.clone(orig_key)] = table.clone(orig_value)
      end
      setmetatable(copy, table.clone(getmetatable(orig)))
   else -- number, string, boolean, etc
      copy = orig
   end

   return copy
end

-- ###########################################

-- From http://lua-users.org/lists/lua-l/2014-09/msg00421.html
-- Returns true if tables are equal
function table.compare(t1, t2, ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)

  if ty1 ~= ty2 then return false end
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then return t1 == t2 end

  for k1,v1 in pairs(t1) do
      local v2 = t2[k1]
      if v2 == nil or not table.compare(v1, v2) then return false end
  end

  for k2,v2 in pairs(t2) do
      local v1 = t1[k2]
      if v1 == nil or not table.compare(v1, v2) then return false end
  end

  return true
end

-- ##############################################

-- returns the MAXIMUM value found in a table t, together with the corresponding
-- index argmax. a pair argmax, max is returned.
function tmax(t)
    local argmx, mx = nil, nil
    if (type(t) ~= "table") then return nil, nil end
    for k, v in pairs(t) do
	-- first iteration
	if mx == nil and argmx == nil then
	    mx = v
	    argmx = k
	elseif (v == mx and k > argmx) or v > mx then
	-- if there is a tie, prefer the greatest argument
	-- otherwise grab the maximum
	    argmx = k
	    mx = v
	end
    end
    return argmx, mx
end

-- ##############################################

-- returns the MINIMUM value found in a table t, together with the corresponding
-- index argmin. a pair argmin, min is returned.
function tmin(t)
    local argmn, mn = nil, nil
    if (type(t) ~= "table") then return nil, nil end
    for k, v in pairs(t) do
	-- first iteration
	if mn == nil and argmn == nil then
	    mn = v
	    argmn = k
	elseif (v == mn and k > argmn) or v < mn then
	-- if there is a tie, prefer the greatest argument
	-- otherwise grab the minimum
	    argmn = k
	    mn = v
	end
    end
    return argmn, mn
end

-- ###########################################

function toboolean(s)
  if((s == "true") or (s == true)) then
    return true
  elseif((s == "false") or (s == false)) then
    return false
  else
    return nil
  end
end

-- ###########################################

--
-- Find the highest divisor which divides input value.
-- val_idx can be used to index divisors values.
-- Returns the highest_idx
--
function highestDivisor(divisors, value, val_idx, iterator_fn)
  local highest_idx = nil
  local highest_val = nil
  iterator_fn = iterator_fn or ipairs

  for i, v in iterator_fn(divisors) do
    local cmp_v
    if val_idx ~= nil then
      v = v[val_idx]
    end

    if((highest_val == nil) or ((v > highest_val) and (value % v == 0))) then
      highest_val = v
      highest_idx = i
    end
  end

  return highest_idx
end

-- ###########################################

--- Test if each element inside the table t satisfies the predicate function
--- @param t table The table containing values to test
--- @param predicate function The function that return a boolean value (true|false)
--- @return boolean
function table.all(t, predicate)

   if type(t) ~= 'table' then
      traceError(TRACE_DEBUG, TRACE_CONSOLE, "the first paramater is not a table!")
      return false
   end
   if type(predicate) ~= 'function' then
      traceError(TRACE_DEBUG, TRACE_CONSOLE, "the passed predicate is not a function!")
      return false
   end

   if t == nil then return false end

   for _, value in pairs(t) do

      -- check if the value satisfies the boolean predicate
      local term = predicate(value)

      -- if the return value is valid and true then do nothing
      -- otherwise stop the loop and return false
      if term == nil then
         -- inform the client about the nil value
         traceError(TRACE_DEBUG, TRACE_CONSOLE, "a null term has been returned from the predicate function!")
         return false
      elseif not term then
         return false
      end
   end

   -- each entry satisfies the predicate
   return true
end

-- ###########################################

--- Perform a linear search to check if an element is inside a table
--- @param t table The table to scan
--- @param needle any The element to search
--- @param comp function The compare function used to compare the searched element with others
--- @return boolean True if the element is insie the table, False otherwise
function table.contains(t, needle, comp)

   if (t == nil) then return false end
   if (type(t) ~= "table") then return false end
   if (#t == 0) then return false end

   local default_compare = (function(e) return e == needle end)
   comp = comp or default_compare

   for _, element in ipairs(t) do
      if comp(element) then return true end
   end

   return false
end

-- ###########################################

--- Insert an element inside the table if is not present
function table.insertIfNotPresent(t, element, comp)
   if table.contains(t, element, comp) then return end
   t[#t+1] = element
end

-- ###########################################

--- Fold right table with a custom function
--- @param t table Table to fold
--- @param func function Function to execute on table values
--- @param val any The returned default value
function table.foldr(t, func, val)
   for i,v in pairs(t) do
       val = func(val, v)
   end
   return val
end

-- ###########################################

function table.has_key(table, key)
   return table[key] ~= nil
end

function table.slice(t, start_table, end_table)
    if t == nil then
        error("The array to slice cannot be nil!")
    end

    if end_table > #t then
       end_table = #t
    end

    if start_table < 1 then
        error("Invalid bounds!")
    end

    local res = {}
    for i = start_table, end_table, 1 do
        res[#res + 1] = t[i]
    end

    return res
end

if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

-- ##############################################

-- Note: Regexs are applied by default. Pass plain=true to disable them.
function string.contains(str, start, is_plain)
   if type(str) ~= 'string' or type(start) ~= 'string' or isEmptyString(str) or isEmptyString(start) then
      return false
   end

   local i, _ = string.find(str, start, 1, is_plain)

   return(i ~= nil)
end

-- ##############################################

function string.containsIgnoreCase(str, start, is_plain)
   return string.contains(string.lower(str), string.lower(start), is_plain)
end

-- ##############################################

function shortenString(name, max_len)
   local ellipsis = "\u{2026}" -- The unicode ellipsis (takes less space than three separate dots)
   if(name == nil) then return("") end

   if max_len == nil then
      max_len = ntop.getPref("ntopng.prefs.max_ui_strlen")
      max_len = tonumber(max_len)
      if(max_len == nil) then max_len = 24 end
   end

   if(string.len(name) < max_len + 1 --[[ The space taken by the ellipsis --]]) then
      return(name)
   else
      return(string.sub(name, 1, max_len)..ellipsis)
   end
end

-- ##############################################

function convertDate(vardate)
   local m,d,y,h,i,s = string.match(vardate, '(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)')
   local key = ntop.getPref('ntopng.user.' .. _SESSION["user"] .. '.date_format')

   if(key == "little_endian") then
      return string.format('%s/%s/%s %s:%s:%s', d,m,y,h,i,s)
   elseif( key == "middle_endian") then
      return string.format('%s/%s/%s %s:%s:%s', m,d,y,h,i,s)
   else
      return string.format('%s/%s/%s %s:%s:%s', y,m,d,h,i,s)
   end

end

if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end
