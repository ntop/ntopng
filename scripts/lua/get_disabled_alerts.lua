--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local json = require "dkjson"

sendHTTPHeader('application/json')

-- ################################################

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local pods_filter_s = _GET["custom_hosts"]

local sortPrefs = "disabled_alerts"

-- ################################################

if isEmptyString(sortColumn) or sortColumn == "column_" then
   sortColumn = getDefaultTableSort(sortPrefs)
else
   if((sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_"..sortPrefs, sortColumn)
   end
end

if isEmptyString(_GET["sortColumn"]) then
  sortOrder = getDefaultTableSortOrder(sortPrefs, true)
end

if((_GET["sortColumn"] ~= "column_")
  and (_GET["sortColumn"] ~= "")) then
    tablePreferences("sort_order_"..sortPrefs, sortOrder, true)
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number", perPage)
end

local sOrder = ternary(sortOrder == "desc", rev_insensitive, asc_insensitive)
local to_skip = (currentPage-1) * perPage

-- ################################################

if _GET["ifid"] then
  interface.select(_GET["ifid"])
end

local ifid = interface.getId()

-- ##############################################

local entitites = alerts_api.getAllEntitiesDisabledAlerts(ifid)
local data = {}
local sort_to_key = {}
local totalRows = 0

for entity_key, disabled_entities in pairsByKeys(entitites) do
  local entity_id = alert_consts.alertEntity(entity_key)

  for entity_value, disabled_alerts in pairsByKeys(disabled_entities) do
    for _, alert in pairs(alert_consts.alert_types) do
      if((alert.alert_id > 0) and ntop.bitmapIsSet(disabled_alerts, alert.alert_id)) then
        totalRows = totalRows + 1
        local idx = totalRows

        data[idx] = {
          entity_formatted = firstToUpper(alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(entity_id), entity_value)),
          entity_id = entity_id,
          entity_value = entity_value,
          alert = alert,
        }

        if sortColumn == "column_type" then
          sort_to_key[idx] = alert.alert_id
        else -- default
          sort_to_key[idx] = data[idx].entity_formatted
        end
      end
    end
  end
end

-- ##############################################

local res = {}
local i = 0

for key in pairsByValues(sort_to_key, sOrder) do
  if i >= to_skip + perPage then
    break
  end

  if (i >= to_skip) then
    local item = data[key]

    res[#res + 1] = {
      column_entity_formatted = firstToUpper(alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(item.entity_id), item.entity_value)),
      column_type = alert_consts.alertTypeLabel(item.alert.alert_id),
      column_entity_id = item.entity_id,
      column_entity_val = item.entity_value,
      column_type_id = item.alert.alert_id,
    }
  end

  i = i + 1
end

-- ##############################################

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = totalRows
result["data"] = res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
