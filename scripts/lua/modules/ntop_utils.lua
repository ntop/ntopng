--
-- (C) 2021 - ntop.org
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

-- @Brief Checks if a dotted-decimal SNMP OID starts with another dotted-decimal SNMP OID
-- @param oid_string The string-encoded dotted-decimal SNMP OID to check
-- @param oid_string_start A string-encoded dotted-decimal SNMP OID prefix
-- @return True if `oid_string` starts with `oid_string_start` or false otherwise
function string.oid_starts(oid_string, oid_string_start)
   if type(oid_string) ~= 'string' or type(oid_string_start) ~= 'string' then
      return false
   end

   -- Make sure both OIDs end with a dot, to avoid
   -- considering 1.3.6.1.4.1.99 starting with 1.3.6.1.4.1.9
   if not string.ends(oid_string, ".") then
      oid_string = oid_string.."."
   end

   if not string.ends(oid_string_start, ".") then
      oid_string_start = oid_string_start.."."
   end

   return string.sub(oid_string , 1, string.len(oid_string_start)) == oid_string_start
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

-- @brief Sorted iteration of a table whose keys are strings in dotted decimal format
--        Can be used to sort dotted-decimal IPs, SNMP oids, etc.
-- @param t The table to be iterated
-- @param f The sort function, either `asc` or `rev`
-- @return An iterator
function pairsByDottedDecimalKeys(t, f)
   local sorter = {}

   -- Build a support array for the actual sorting
   for key, value in pairs(t) do
      sorter[#sorter + 1] = {
	 sorter = key:split("%.") or {key}, -- An array that will be used to sort
	 key = key, -- Original key
	 value = value -- Original value
      }
   end

   table.sort(sorter,
	      function(left, right)
		 -- The minimum of the two lengths, used to to the comparisons
		 local len = math.min(#left.sorter, #right.sorter)

		 for i = 1, len do
		    -- Convert elements to numbers
		    local left_number, right_number = tonumber(left.sorter[i]), tonumber(right.sorter[i])

		    if left_number ~= right_number then
		       -- If numbers are different, compare them using the sort function
		       return f(left_number, right_number)
		    elseif i == len then
		       -- This is the lat time we do the comparison:
		       -- When lengths are not equal, legths are used at tie breaker
		       return f(#left.sorter, #right.sorter)
		    end
		 end
	      end
   )

   local i = 0
   local iter = function()
      i = i + 1

      if sorter[i] == nil then
	 return
      end

      return sorter[i].key, sorter[i].value
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

function isNoLoginUser()
  return _SESSION["user"] == ntop.getNologinUser()
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

-- ###########################################

function hasHighResolutionTs()
   local active_driver = ntop.getPref("ntopng.prefs.timeseries_driver")

   -- High resolution timeseries means dumping the host timeseries
   -- every 60 seconds instead of 300 seconds.
   return((active_driver == "influxdb") and
    (ntop.getPref("ntopng.prefs.ts_resolution") ~= "300"))
end
