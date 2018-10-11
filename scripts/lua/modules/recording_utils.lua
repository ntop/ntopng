--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()
require "lua_utils"
require "prefs_utils"

prefs = ntop.getPrefs()

local n2disk_ctl = "/usr/local/bin/n2diskctl"
local n2disk_ctl_cmd = "sudo "..n2disk_ctl

local recording_utils = {}

recording_utils.default_disk_space = 10*1024

-- #################################

local function executeWithOuput(c)
  local f = assert(io.popen(c, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  return s
end

function recording_utils.isAvailable()
  if not ntop.isWindows() and ntop.exists(n2disk_ctl) then
    return true
  end
  return false
end

function recording_utils.getInterfaces()
  local ntopng_interfaces = interface.getIfNames()
  local n2disk_interfaces = {}

  for id,ifname in pairs(ntopng_interfaces) do
    local is_zc = false

    local proc_info = io.open("/proc/net/pf_ring/dev/"..ifname.."/info", "r")
    if proc_info ~= nil then
      local info = proc_info:read "*a"
      if string.match(info, "ZC") then
        is_zc = true
      end
      proc_info:close()
    end

    n2disk_interfaces[ifname] = {
      id = id,
      desc = "",
      is_zc = is_zc
    }
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

local function memInfo()
  local mem_info = {}
  for line in io.lines("/proc/meminfo") do 
    local values = split(line, ':')
    mem_info[values[1]] = trimString(values[2])
  end
  return mem_info
end

function recording_utils.createConfig(ifname, params)
  local conf_dir = dirs.workingdir.."/n2disk"
  local filename = conf_dir.."/n2disk-"..ifname..".conf"
  local storage_path = dirs.storagedir

  if isEmptyString(storage_path) then
    return false
  end

  local defaults = {
    buffer_size = 1024,       -- Buffer size (MB)
    max_file_size = 256,      -- Max file length (MB)
    max_disk_space = recording_utils.default_disk_space, -- Max disk space (MB)
    snaplen = 1536,           -- Capture length
    writer_core = 0,          -- Writer thread affinity
    reader_core = 1,          -- Reader thread affinity
    indexer_cores = { 2 },    -- Indexer threads affinity
    -- Optional parameters
    -- zmq_endpoint = "tcp://*:5556" -- ZMQ endpoint for stats/flows
  }

  local ifspeed = (interface.getMaxIfSpeed(ifname) or 1000)

  -- Reading system memory info

  local mem_info = memInfo()
  local mem_total_mb = math.floor(tonumber(split(mem_info['MemTotal'], ' ')[1])/1024)

  -- Computing file and buffer size

  if ifspeed > 10000 then -- 40/100G
    defaults.max_file_size = 4*1024
  elseif ifspeed > 1000 then -- 10G
    defaults.max_file_size = 1*1024
  end
  defaults.buffer_size = 4*defaults.max_file_size

  local min_sys_mem = 768
  local min_n2disk_mem = 128
  if defaults.buffer_size + min_sys_mem > mem_total_mb then
    if mem_total_mb < min_sys_mem then
      return false
    end
    defaults.buffer_size = mem_total_mb - min_sys_mem
    defaults.max_file_size = math.floor(defaults.buffer_size/4)
  end

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
  f:write("--dump-directory="..storage_path.."/n2disk/"..ifname.."\n")
  f:write("--index\n")
  f:write("--timeline-dir="..storage_path.."/n2disk/"..ifname.."\n")
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
  local check_cmd = n2disk_ctl_cmd.." is-active "..ifname
  local is_active = executeWithOuput(check_cmd)
  return ternary(string.match(is_active, "^active"), true, false)
end

function recording_utils.restart(ifname)
  os.execute(n2disk_ctl_cmd.." enable "..ifname)
  os.execute(n2disk_ctl_cmd.." restart "..ifname)
end

function recording_utils.stop(ifname)
  os.execute(n2disk_ctl_cmd.." stop "..ifname)
  os.execute(n2disk_ctl_cmd.." disable "..ifname)
end

function recording_utils.log(ifname, rows)
  local log = executeWithOuput(n2disk_ctl_cmd.." log "..ifname.."|tail -n"..rows)
  return log
end

function recording_utils.set_license(key)
  os.execute(n2disk_ctl_cmd.." set-license "..key)
end

-- #################################

return recording_utils

