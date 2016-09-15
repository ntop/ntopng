--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "top_talkers"

local top_countries_intf = {}

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/top_scripts/?.lua;" .. package.path
  local new = require("top_aggregate")
  if (type(new) ~= "table") then new = {} end
  -- Add pro methods to local method table
  for k,v in pairs(new) do
    top_countries_intf[k] = v
  end
end

local function getTopCountries(ifid, ifname)
  -- cap the maximum # of entries at 10. Use treshold, but no not use delta
  -- do not filter by col or by val (nil, nil).
  -- column is top_countries_intf.key
  -- key is top_countries_intf.JSONkey
  return getCurrentTopGroupsSeparated(ifid, ifname,
                                      10, true, false,
                                      nil, nil,
                                      top_countries_intf.key,
                                      top_countries_intf.JSONkey,
                                      nil, true, nil,
                                      top_countries_intf.uniqueKey)
end

local function getTopCountriesBy(ifid, ifname, filter_col, filter_val)
   local lastdump_key = getLastDumpKey(top_countries_intf.uniqueKey, filter_col, filter_val)
   return getCurrentTopGroupsSeparated(ifid, ifname,
				       10, true, false,
				       filter_col, filter_val,
				       top_countries_intf.key,
				       top_countries_intf.JSONkey,
				       nil, true, nil,
				       lastdump_key)
end

local function getTopCountriesClean(ifid, ifname, param)
  top = getCurrentTopGroups(ifid, ifname, 5, false, false,
                                      nil, nil, top_countries_intf.key,
                                      top_countries_intf.JSONkey, true, param,
                                      top_countries_intf.uniqueKey)
  section_beginning = string.find(top, '%[')
  if (section_beginning == nil) then
    return("[ ]\n")
  else
    return(string.sub(top, section_beginning))
  end
end

local function topCountriesSectionInTableOP(tblarray, arithOp)
  local ret = {}
  local outer_cnt = 1
  local num_glob = 1

  for _,tbl in pairs(tblarray) do
    for _,outer in pairs(tbl) do
      if (ret[outer_cnt] == nil) then ret[outer_cnt] = {} end
      for key, value in pairs(outer) do
        for _,record in pairs(value) do
          local found = false
          if (ret[outer_cnt][key] == nil) then ret[outer_cnt][key] = {} end
          for _,el in pairs(ret[outer_cnt][key]) do
            if (found == false and el["address"] == record["address"]) then
              el["value"] = arithOp(el["value"], record["value"])
              found = true
            end
          end
          if (found == false) then
            ret[outer_cnt][key][num_glob] = record
            num_glob = num_glob + 1
          end
        end
      end
    end
  end

  return ret
end

local function printTopCountriesTable(tbl)
  local rsp = "{\n"

  for i,v in pairs(tbl) do
    local outouterlooped = 0
    for dk,dv in pairs(v) do
      rsp = rsp..'"'..dk..'": [\n'
      local keys = getKeys(dv, "value")
      local outerlooped = 0
      for tv,tk in pairsByKeys(keys, rev) do
        rv = dv[tk]
        rsp = rsp.."{ "
        local looped = 0
        for k,v in pairs(rv) do
          rsp = rsp..'"'..k..'": '
          if (k == "value") then
            rsp = rsp..tostring(v)
          else
            rsp = rsp..'"'..v..'"'
          end
          rsp = rsp..", "
          looped = looped + 1
        end
        if (looped > 0) then
          rsp = string.sub(rsp, 1, -3)
        end
        rsp = rsp.."},\n"
        outerlooped = outerlooped + 1
      end
      if (outerlooped > 0) then
        rsp = string.sub(rsp, 1, -3)
      end
      rsp = rsp.."],\n"
      outouterlooped = outouterlooped + 1
    end
    if (outouterlooped > 0) then
      rsp= string.sub(rsp, 1, -3)
    end
  end

  rsp = rsp.."\n}"

  return rsp

end

local function getTopCountriesFromJSONDirection(table, wantedDir, add_vlan)
  local elements = ""

  -- For each VLAN, get countries and concatenate them
  for i,vlan in pairs(table["vlan"]) do
      local vlanid = vlan["label"]
      local vlanname = vlan["name"]
      -- XXX countries is an array of (senders, receivers) pairs?
      for i2,countriespair in pairs(vlan[top_countries_intf.JSONkey]) do
        -- countriespair is { "senders": [...], "receivers": [...] }
        for k2,direction in pairs(countriespair) do
          -- direction is "senders": [...] or "receivers": [...]
          if (k2 ~= wantedDir) then goto continue end
          -- scan countries
          for i2,country in pairs(direction) do
            -- country is { "label": ..., "value": ..., "url": ... }
            elements = elements.."{ "
            local n_el = 0
            for k3,v3 in pairs(country) do
              elements = elements..'"'..k3..'": '
              if (k3 == "value") then
                elements = elements..tostring(v3)
              else
                elements = elements..'"'..v3..'"'
              end
              elements = elements..", "
              n_el = n_el + 1
            end
            if (add_vlan ~= nil) then
              elements = elements..'"vlanm": "'..vlanname..'", '
              elements = elements..'"vlan": "'..vlanid..'", '
            end
            if (n_el ~= 0) then
              elements = string.sub(elements, 1, -3)
            end
            elements = elements.." },\n"
          end
          ::continue::
        end
      end
  end

  return elements
end

local function printTopCountriesFromTable(table, add_vlan)
  if (table == nil or table["vlan"] == nil) then return "[ ]\n" end

  local elements = "{\n"
  elements = elements..'"senders": [\n'
  local result = getTopCountriesFromJSONDirection(table, "senders", add_vlan)
  if (result ~= "") then
    result = string.sub(result, 1, -3) --remove comma
  end
  elements = elements..result
  elements = elements.."],\n"
  elements = elements..'"receivers": [\n'
  result = getTopCountriesFromJSONDirection(table, "receivers", add_vlan)
  if (result ~= "") then
    result = string.sub(result, 1, -3) --remove comma
  end
  elements = elements..result
  elements = elements.."]\n"
  elements = elements.."}\n"

  return elements
end

local function getTopCountriesFromJSON(content, add_vlan)
  if(content == nil) then return("[ ]\n") end
  local table = json.decode(content, 1)
  local rsp = printTopCountriesFromTable(table, add_vlan)
  if (rsp == nil or rsp == "") then return "[ ]\n" end
  return rsp
end

local function getHistoricalTopCountries(ifid, ifname, epoch, add_vlan)
  if (epoch == nil) then
    return("[ ]\n")
  end
  return getTopCountriesFromJSON(ntop.getMinuteSampling(ifid, tonumber(epoch)), add_vlan)
end

top_countries_intf.name = "Countries"
top_countries_intf.infoScript = "hosts_stats.lua"
top_countries_intf.infoScriptKey = "country"
top_countries_intf.key = "country"
top_countries_intf.JSONkey = "countries"
top_countries_intf.uniqueKey = "top_countries"
top_countries_intf.getTop = getTopCountries
top_countries_intf.getTopBy = getTopCountriesBy
top_countries_intf.getTopClean = getTopCountriesClean
top_countries_intf.getTopFromJSON = getTopCountriesFromJSON
top_countries_intf.printTopTable = printTopCountriesTable
top_countries_intf.getHistoricalTop = getHistoricalTopCountries
top_countries_intf.topSectionInTableOp = topCountriesSectionInTableOP
top_countries_intf.numLevels = 2

return top_countries_intf
