--
-- (C) 2017-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "prefs_utils"
local host_pools_utils = require "host_pools_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local max_num_to_find = 5
local res = {results={}}
local results = res.results
local menu_subpages = require "prefs_menu"

local query = _GET["query"] or ""

local function matchesQuery(value, query)
  return string.find(string.lower(value), string.lower(query))
end

local function queryResultShorten(result, query, context)
  local maxlen = 35
  local idx = matchesQuery(result, query)
  local left_slice, right_slice = shortenInTheMiddle(result, idx, idx + string.len(query), maxlen)

  return context..(
    ternary(left_slice ~= 1, "...", "")..
    string.sub(result, left_slice, right_slice)..
    ternary(right_slice ~= string.len(result), "...", "")
  )
end

local function addResult(result, tab, context)
  results[#results + 1] = {name=queryResultShorten(noHtml(result), query, context), tab=tab.id}
end

for _, tab in pairs(menu_subpages) do
  if isSubpageAvailable(tab) and not (tab.disabled) then
    -- Menu match, do not proceed with children
    if matchesQuery(tab.label, query) then
      addResult(tab.label, tab, "")
    else
      for _, entry in pairs(tab.entries) do
        if entry.hidden ~= true then
          -- Entry title match, do not proceed with description
          if matchesQuery(entry.title, query) then
            -- Decorate with tab label
            addResult(entry.title, tab, tab.label .. ": ")
            break
          --[[elseif matchesQuery(entry.description, query) then
            -- Decorate with entry title and tab label
            addResult(entry.description, tab, tab.label .. " [" .. entry.title .. "]: ")]]--
          end
        end
      end
    end
  end
end

print(json.encode(res, nil, 1))
