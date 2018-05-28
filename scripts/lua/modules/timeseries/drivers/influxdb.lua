--
-- (C) 2018 - ntop.org
--

local driver = {}

--
-- Sample query:
--    select * from "iface:ndpi" where ifid='0' and protocol='SSL'
--
-- See also callback_utils.uploadTSdata
--

-------------------------------------------------------

function driver:new(options)
  local obj = {}

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-------------------------------------------------------

function driver:append(schema, timestamp, tags, metrics)
  local tags_string = table.tconcat(tags, "=", ",")
  local metrics_string = table.tconcat(metrics, "=", ",")

  -- E.g. iface:ndpi_categories,category=Network,ifid=0 bytes=371707
  -- NB: time format is in nanoseconds UTC
  local api_line = schema.name .. "," .. tags_string .. " " .. metrics_string .. " " .. timestamp .. "000000000\n"

  return ntop.appendInfluxDB(api_line)
end

-------------------------------------------------------

function driver:flush()
  return true
end

-------------------------------------------------------

return driver
