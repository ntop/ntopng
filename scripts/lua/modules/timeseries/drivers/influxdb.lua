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

local HIGH_FREQUENCY_EXPORT_TIMEOUT_SECONDS = 45
local MAX_INSERTS_PER_BUFFER = 100

-------------------------------------------------------

function driver:new(options)
  local obj = {
    buffer_file = nil,
    buffer_file_name = "",
    periodicity = nil,
    step = nil,
    num_inserts = 0,
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-------------------------------------------------------

local function get_buffer_file_creation_key(ifid, step)
  local file_key = ifid .. "_" .. step
  return "ntopng.cache.ts_influxdb_buffer_" .. file_key .. "_timestamp"
end

local function get_buffer_file_name_key(ifid, step)
  local file_key = ifid .. "_" .. step
  return "ntopng.cache.ts_influxdb_buffer_" .. file_key
end

-- File used for strings buffering
local function get_buffer_file(schema, tags)
  local ifid = tags.ifid or -1
  local step = schema.options.step
  local temp_file = nil
  local temp_fname = nil

  if step < 60 then
    -- This is an high frequency data, we accumulate many points
    local cache_key = get_buffer_file_name_key(ifid, step)
    temp_fname = ntop.getCache(cache_key)

    if isEmptyString(temp_fname) or not ntop.exists(temp_fname) then
      -- allocate new file
      temp_fname = os.tmpname()
      ntop.setCache(cache_key, temp_fname)
      ntop.setCache(get_buffer_file_creation_key(ifid, step), tostring(os.time()))
    end
  else
    -- This is a low frequency data, we do not need to accumulate, so the lifetime
    -- is bound to this script
    temp_fname = os.tmpname()
  end

  temp_file = io.open(temp_fname, "a")
  return temp_file, temp_fname
end

-- checks if it's time to export data to influxdb
local function check_buffer_flush(bufname, num_insertss, ifid, step, now, is_flushing)
  local will_export = false

  if num_insertss >= MAX_INSERTS_PER_BUFFER then
    will_export = true
  elseif step < 60 then
    local creation_date = tonumber(ntop.getCache(get_buffer_file_creation_key(ifid, step)))

    if (not creation_date) or ((now - creation_date) >= HIGH_FREQUENCY_EXPORT_TIMEOUT_SECONDS) then
      -- only export after the specified timeout
      ntop.delCache(get_buffer_file_name_key(ifid, step))

      will_export = true
    end
  elseif is_flushing then
    -- always export the buffer for low frequency data
    will_export = true
  end

  if will_export then
    --traceError(TRACE_NORMAL, TRACE_CONSOLE, "exporting buffer file " .. bufname .. " [ifid=" .. ifid .. " step=" .. step .. "]")
    ntop.rpushCache("ntopng.ts_file_queue", bufname)
    return true
  end

  return false
end

function driver:append(schema, timestamp, tags, metrics)
  local tags_string = table.tconcat(tags, "=", ",")
  local metrics_string = table.tconcat(metrics, "=", ",")

  if not self.buffer_file then
    self.buffer_file, self.buffer_file_name = get_buffer_file(schema, tags)
    self.num_inserts = 0
  end

  if not self.buffer_file then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "cannot open buffer file for in schema " .. schema.name)
    return false
  end

  -- E.g. iface:ndpi_categories,category=Network,ifid=0 bytes=371707
  -- NB: time format is in nanoseconds UTC
  local api_line = schema.name .. "," .. tags_string .. " " .. metrics_string .. " " .. timestamp .. "000000000\n"

  self.buffer_file:write(api_line)

  if check_buffer_flush(self.buffer_file_name, self.num_inserts, tags.ifid or -1, schema.options.step, timestamp, false) then
    self.buffer_file = nil
  else
    self.num_inserts = self.num_inserts + 1
  end

  self.periodicity = schema.options.step
  self.ifid = tags.ifid

  return true
end

-------------------------------------------------------

function driver:flush()
  local step = self.periodicity
  local ifid = self.ifid
  local now = os.time()

  if (step ~= nil) and (ifid ~= nil) and (self.buffer_file ~= nil) then
    if check_buffer_flush(self.buffer_file_name, self.num_inserts, ifid, step, now, true) then
      self.buffer_file = nil
    end
  end

  return true
end

-------------------------------------------------------

return driver
