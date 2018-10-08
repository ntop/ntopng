--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()
require "lua_utils"
require "prefs_utils"

prefs = ntop.getPrefs()

local recording_utils = {}

recording_utils.n2disk_bin = "/usr/local/bin/n2disk"

-- #################################

local function executeWithOuput(c)
  local f = assert(io.popen(c, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  return s
end

function recording_utils.isAvailable()
  if not ntop.isWindows() and ntop.exists(recording_utils.n2disk_bin) then
    return true
  end
  return false
end

function recording_utils.getInterfaces()
  local ntopng_interfaces = interface.getIfNames()
  local ntopng_interfaces_map = swapKeysValues(ntopng_interfaces)
  local all_interfaces = ntop.listInterfaces()
  local n2disk_interfaces = {}

  for k,v in pairs(all_interfaces) do
    if not string.match(k, "usb") then
      local is_zc = false
      local in_use = false

      if ntopng_interfaces_map[k] ~= nil then
        in_use = true
      end

      local proc_info = io.open("/proc/net/pf_ring/dev/"..k.."/info", "r")
      if proc_info ~= nil then
        local info = proc_info:read "*a"
        if string.match(info, "ZC") then
          is_zc = true
        end
      end

      n2disk_interfaces[k] = {
        desc = v.description,
        is_zc = is_zc,
        in_use = in_use
      }
    end
  end

  return n2disk_interfaces
end

local function nextFreeCore(num_cores, busy_cores, start)
  local busy_map = swapKeysValues(busy_cores) 
  for i=start,num_cores-1 do
    if busy_map[i] == nil then
      return i
    end
  end
  return start
end

function recording_utils.createConfig(ifname, params)
  local conf_dir = dirs.workingdir.."/n2disk"
  local filename = conf_dir.."/n2disk-"..ifname..".conf"

  local defaults = {
    path = "/storage",        -- Storage path
    buffer_size = 1024,       -- Buffer size (MB)
    max_file_size = 256,      -- Max file length (MB)
    max_disk_space = 10*1024, -- Max disk space (MB)
    snaplen = 1536,           -- Capture length
    writer_core = 0,          -- Writer thread affinity
    reader_core = 1,          -- Reader thread affinity
    indexer_cores = { 2 },    -- Indexer threads affinity
    -- Optional parameters
    -- zmq_endpoint = "tcp://*:5556" -- ZMQ endpoint for stats/flows
  }

  local ifspeed = (interface.getMaxIfSpeed(ifname) or 1000)

  -- Computing file and buffer size

  if ifspeed > 10000 then -- 40/100G
    defaults.max_file_size = 4*1024
  elseif ifspeed > 1000 then -- 10G
    defaults.max_file_size = 1*1024
  end
  defaults.buffer_size = 4*defaults.max_file_size

  -- Computing core affinity

  local indexing_threads = 1 -- 1G
  if ifspeed > 10000 then    -- 40/100G
    indexing_threads = 4
  elseif ifspeed > 1000 then -- 10G
    indexing_threads = 2
  end
  local n2disk_threads = indexing_threads + 2

  local cores = tonumber(executeWithOuput("nproc"))

  local ntopng_affinity = split(prefs.cpu_affinity, ',')
  local busy_cores = {}
  if cores - (#ntopng_affinity) >= n2disk_threads then
    -- enough cores to isolate all threads, skipping ntopng threads
    busy_cores = ntopng_affinity
  end

  local first_core = 0

  defaults.writer_core = nextFreeCore(cores, busy_cores, first_core)
  table.insert(busy_cores, defaults.writer_core)
  first_core = (defaults.writer_core + 1) % cores

  defaults.reader_core = nextFreeCore(cores, busy_cores, first_core)
  table.insert(busy_cores, defaults.reader_core)
  first_core = (defaults.reader_core + 1) % cores

  defaults.indexer_cores = {}
  for i=1,indexing_threads do
    local indexer_core = nextFreeCore(cores, busy_cores, first_core)
    table.insert(defaults.indexer_cores, indexer_core)
    table.insert(busy_cores, indexer_core)
    first_core = (indexer_core + 1) % cores
  end 

  -- Checking options

  if params.path == nil then
    return false
  end

  local config = table.merge(defaults, params)

  -- Writing configuration file

  local ret = ntop.mkdir(conf_dir)

  if not ret then
    return false
  end

  local f = io.open(filename, "w")

  if not f then
    return false
  end

  f:write("--interface="..ifname.."\n")
  f:write("--dump-directory="..config.path.."/n2disk/"..ifname.."\n")
  f:write("--index\n")
  f:write("--timeline-dir="..config.path.."/n2disk/"..ifname.."\n")
  f:write("--buffer-len="..config.buffer_size.."\n")
  f:write("--max-file-len="..config.max_file_size.."\n")
  f:write("--disk-limit="..config.max_disk_space.."\n")
  f:write("--snaplen="..config.snaplen.."\n")
  f:write("--writer-cpu-affinity="..config.writer_core.."\n")
  f:write("--reader-cpu-affinity="..config.reader_core.."\n")
  f:write("--compressor-cpu-affinity=")
  for i, v in ipairs(config.indexer_cores) do
    f:write(v..ternary(i == #config.indexer_cores, "", ","))
  end
  f:write("\n")
  f:write("--index-on-compressor-threads\n")
  if config.zmq_endpoint ~= nil then
    f:write("--zmq="..config.zmq_endpoint.."\n")
    f:write("--zmq-export-flows\n")
  end

  f:close()

  return true
end

function recording_utils.isActive(ifname)
  local check_cmd = "systemctl is-active n2disk@"..ifname
  local is_active = executeWithOuput(check_cmd)
  return ternary(string.match(is_active, "^active"), true, false)
end

function recording_utils.start(ifname)
  os.execute("systemctl enable n2disk@"..ifname)
  os.execute("systemctl restart n2disk@"..ifname)
end

function recording_utils.stop(ifname)
  os.execute("systemctl stop n2disk@"..ifname)
  os.execute("systemctl disable n2disk@"..ifname)
end

-- #################################

return recording_utils

