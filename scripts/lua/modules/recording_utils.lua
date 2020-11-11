--
-- (C) 2014-20 - ntop.org
--

local dirs = ntop.getDirs()
require "lua_utils"
--require "prefs_utils"
local json = require("dkjson")
local os_utils = require("os_utils")

local prefs = ntop.getPrefs()

local extraction_queue_key = "ntopng.traffic_recording.extraction_queue"
local extraction_stop_queue_key = "ntopng.traffic_recording.extraction_stop_queue"
local extraction_seqnum_key = "ntopng.traffic_recording.extraction_seqnum"
local extraction_jobs_key = "ntopng.traffic_recording.extraction_jobs"
local is_available_key = "ntopng.cache.traffic_recording_available"
local provider_key = "ntopng.prefs.traffic_recording.ifid_%d.provider"
local external_providers_reminder_dismissed_key = "ntopng.prefs.traffic_recording.ifid_%d.reminder_dismissed"
local is_running_job_pending_key = "ntopng.cache.traffic_recording_job_pending"

local recording_utils = {}

recording_utils.default_disk_space = 10 * 1024

-- #################################

local function extraction_checks_to_i18n(err)
   local map = {
      ERR_MISSING_TIMELINE = "traffic_recording.msg_err_missing_timeline",
      ERR_TIMELINE_PATH_NOT_EXISTING = "traffic_recording.msg_err_timeline_path_not_existing",
      ERR_UNABLE_TO_ACCESS_TIMELINE = "traffic_recording.msg_err_unable_to_access_timeline",
      OK = "traffic_recording.msg_ok",
   }

   return map[err] or 'traffic_recording.msg_err_unknown'
end

-- #################################

--! @brief Check if an interface is a ZMQ interface that can be used with external interfaces for traffic recording and flow import
--! @param ifid the interface identifier 
--! @return true if supported, false otherwise
function recording_utils.isSupportedZMQInterface(ifid)
  local ifname = getInterfaceName(ifid)
  -- localhost in collectore mode is accepted
  local zmq_prefix_any = "tcp://*"
  local zmq_prefix_loh = "tcp://127.0.0.1"
  if (ifname:sub(1, #zmq_prefix_any) == zmq_prefix_any or
      ifname:sub(1, #zmq_prefix_loh) == zmq_prefix_loh) and
      ifname:sub(-1) == "c" then
    return true
  end
  return false
end

local function getZMQPort(addr)
  local values = split(addr, ':')
  if #values == 3 then
    local port = split(values[3], 'c')
    return port[1]
  end
  return nil
end

--! @brief Return the ZMQ endpoint that should be used by an external process (n2disk) to deliver flows to ntopng
--! @param ifid the interface identifier 
--! @return the endpoint
function recording_utils.getZMQProbeAddr(ifid)
  local port = getZMQPort(getInterfaceName(ifid))
  if port == nil then
    port = "5556"
  end
  return "tcp://127.0.0.1:"..port
end

--! @brief Check if an interface is supported for recording (packet interface, or ZMQ interface that can be used with external interfaces for traffic dump and flow import)
--! @param ifid the interface identifier 
--! @return true if supported, false otherwise
function recording_utils.isSupportedInterface(ifid)
  if interface.isPacketInterface() or 
     recording_utils.isSupportedZMQInterface(ifid) then
    return true
  end
  return false
end

--! @brief Check if a reminder that warns the user about available external traffic rec. providers has to be shown
--! @return true if the reminder has to be shown, false otherwise
function recording_utils.isExternalProvidersReminderDismissed(ifid)
   local k = string.format(external_providers_reminder_dismissed_key, ifid)
   local cur_pref = ntop.getPref(k)

   if cur_pref == "true" then
      return true -- reminder has been explicitly dismissed
   end

   if recording_utils.getCurrentTrafficRecordingProvider(ifid) ~= "ntopng" then
      return true -- an external traffic recording provider has already been selected
   end

   local providers = recording_utils.getAvailableTrafficRecordingProviders()
   if #providers == 1 then
      return true -- there's only one provider
   end

   return false
end

--! @brief Dismiss the reminder for external traffic recording providers
--! @return nil
function recording_utils.dismissExternalProvidersReminder(ifid)
   local k = string.format(external_providers_reminder_dismissed_key, ifid)
   ntop.setPref(k, "true")
end

-- only called during boot
function recording_utils.checkAvailable()
  local is_available = false

  if(not ntop.isWindows())
    and (not ntop.isnEdge())
    and os_utils.hasService("n2disk-ntopng", "dummy") then
    is_available = true
  end

  ntop.setCache(is_available_key, ternary(is_available, "1", "0"))

  -- forcing a setJobAsCompleted after startup to handle interrupted jobs
  ntop.setCache(is_running_job_pending_key, "1")
end

--! @brief Check if traffic recording is available and allowed for the current user on an interface
--! @return true if recording is available, false otherwise
function recording_utils.isAvailable()
  if isAdministrator() and (ntop.getCache(is_available_key) == "1") then
    return true
  end
  return false
end

--! @brief Check if traffic recording and extraction is allowed for the current user on an interface
--! @return true if extraction is available, false otherwise
function recording_utils.isExtractionAvailable()
  if ntop.isPcapDownloadAllowed() and (ntop.getCache(is_available_key) == "1") then
    return true
  end

  return false
end

--! @brief Return information about the recording service (n2disk) including systemid and version
--! @return a table with the information
function recording_utils.getN2diskInfo()
  local info = {}

  local n2disk_version = os_utils.execWithOutput("n2disk --version")
  local lines = split(n2disk_version, "\n")
  for i = 1, #lines do
    local line = lines[i]
    line = string.gsub(line, "%s+", " ")
    local pair = split(line, " ")
    if pair[1] ~= nil and pair[2] ~= nil then
      if pair[1] == "n2disk" then
        info.version = trimString(pair[2])
      elseif pair[1] == "SystemID:" then
        info.systemid = trimString(pair[2])
      end
    end
  end

  local license_file = io.open("/etc/n2disk.license", "r")
  if license_file ~= nil then
    local license = license_file:read "*l"
    info.license = license
    license_file:close()
  end

  return info
end

--! @brief Install a license for n2disk
--! @param key The license key
--! @return true if the license is installed, false in case it is not possible
function recording_utils.setLicense(key)
   return os_utils.ntopctlCmd("n2disk-ntopng", "set-license", key)
end

local function setLicenseFromRedis()
  local n2disk_license = ntop.getCache('ntopng.prefs.n2disk_license')
  if not isEmptyString(n2disk_license) then
    recording_utils.setLicense(n2disk_license)
  end
end

local function isZCInterface(ifname)
  local proc_info = io.open("/proc/net/pf_ring/dev/"..ifname.."/info", "r")
  if proc_info ~= nil then
    local info = proc_info:read "*a"
    proc_info:close()
    if string.match(info, "ZC") then
      return true
    end
  end
  -- return true -- DEBUG
  return false
end

local function isRecordingEnabledInCache(ifid)
  local enabled = ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.enabled')
  if not isEmptyString(enabled) and 
     (enabled == "true" or enabled == "1") then
     return true
  end
  return false
end

local function getInUseExtInterfaces(current_ifid)
  local inuse_ext_interfaces = {}
  local ntopng_interfaces = interface.getIfNames()
  for other_ifid,other_ifname in pairs(ntopng_interfaces) do
    if other_ifid ~= current_ifid then
      if isRecordingEnabledInCache(other_ifid) then
        local other_ext_ifname = ntop.getCache('ntopng.prefs.ifid_'..other_ifid..'.traffic_recording.ext_ifname')
        if not isEmptyString(other_ext_ifname) then
          inuse_ext_interfaces[other_ext_ifname] = true
        end
      end
    end
  end
  return inuse_ext_interfaces
end

--! @brief Return external interfaces, not in use by ntopng, that can be used through ZMQ interface for traffic recording and flow import
--! @param ifid the interface identifier 
--! @return a table with external interfaces information
function recording_utils.getExtInterfaces(ifid)
  local ext_interfaces = {}
  local all_interfaces = ntop.listInterfaces()
  local ntopng_interfaces = swapKeysValues(interface.getIfNames()) 
  local inuse_ext_interfaces = getInUseExtInterfaces(ifid)
 
  for ifname,_ in pairs(all_interfaces) do
    if ntopng_interfaces[ifname] == nil and -- not in use as packet interface by ntopng 
       inuse_ext_interfaces[ifname] == nil and -- not in use by other zmq interfaces
       all_interfaces[ifname].module ~= nil and -- detected by pf_ring
       all_interfaces[ifname].module ~= "pf_ring" -- ('pf_ring-zc', 'napatech', ..)
      then
      local prefix = ""
      if all_interfaces[ifname].module == "pf_ring-zc" then
        prefix = "zc:"
      end
      ext_interfaces[ifname] = {
        ifdesc = prefix..ifname,
        module = all_interfaces[ifname].module
      }
    end
  end

  return ext_interfaces
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

-- Return memory information (values in MB)
local function memInfo()
  local mem_info = {}

  for line in io.lines("/proc/meminfo") do 
    local pair = split(line, ':')
    local k = pair[1]
    if pair[2] ~= nil then
      local value = split(trimString(pair[2]), ' ')
      local v = tonumber(value[1])
      if value[2] ~= nil and value[2] == 'kB' then
        v = v/1024 -- kB to MB
      end
      mem_info[k] = math.floor(v)
    end
  end

  if mem_info['MemAvailable'] == nil and 
     mem_info['MemFree'] ~= nil and 
     mem_info['SReclaimable'] ~= nil then
    mem_info['MemAvailable'] = mem_info['MemFree'] + mem_info['SReclaimable']
  end

  return mem_info
end

local function dirname(s)
  s = s:gsub('/$', '')
  local s, n = s:gsub('/[^/]*$', '')
  if n == 1 then
    return ternary(string.len(s) > 0, s, "/")
  else 
    return '.' 
  end
end

--! @brief Return the root path for recorded pcap data
--! @param ifid the interface identifier 
--! @return the path
function recording_utils.getPcapPath(ifid)
  local storage_path = dirs.pcapdir
  return storage_path.."/"..ifid.."/pcap"
end

local function getPcapExtractionPath(ifid)
  local storage_path = dirs.pcapdir
  return storage_path.."/"..ifid.."/extr_pcap"
end

local function getTimelinePath(ifid)
  local storage_path = dirs.pcapdir
  return storage_path.."/"..ifid.."/timeline"
end

local function getPcapFileDir(job_id, ifid)
  local dir_path = getPcapExtractionPath(ifid)
  return dir_path.."/"..job_id
end

local function getPcapFilePath(job_id, ifid, file_id)
  local dir_path = getPcapFileDir(job_id, ifid)
  return dir_path.."/"..file_id..".pcap"
end

-- Read information about used disk space for an interface dump
local function interfaceStorageUsed(ifid)
  local pcap_path = recording_utils.getPcapPath(ifid)
  return getFolderSize(pcap_path) 
end

--! @brief Read information about a volume, including storage size and available space
--! @param path the volume path (or a folder inside the volume)
function recording_utils.volumeInfo(path)
  local volume_info = {
    path = path, 
    dev = "", 
    total = 0, 
    used = 0, 
    avail = 0, 
    used_perc = 0,
    mount = "",
  }

  local root_path = path
  while not ntop.isdir(root_path) and string.len(root_path) > 1 do
    root_path = dirname(root_path) 
  end

  if ntop.isdir(root_path) then
    -- use environment variable POSIXLY_CORRECT=1 to guarantee the
    -- the results are returned in number of 512-byte blocks (otherwise,
    -- linux will return 1K blocks and BSD 512-byte blocks) 
    local line = os_utils.execWithOutput("POSIXLY_CORRECT=1 df "..root_path.." 2>/dev/null|tail -n1")

    if line ~= nil then
      line = line:gsub('%s+', ' ')
      local values = split(line, ' ')

      if #values >= 6 then
	volume_info.dev = values[1]
	-- Multiply by 512 as results are in 512-byte blocks 
        volume_info.total = (tonumber(values[2]) or 0) * 512
        volume_info.used =  (tonumber(values[3]) or 0) * 512
        volume_info.avail = (tonumber(values[4]) or 0) * 512

        volume_info.used_perc = values[5]
        volume_info.mount = values[6]
      end
    end
  end

  return volume_info
end

--! @brief Read information about the storage, including storage size and available space
--! @param ifid the interface identifier
--! @param timeout the maxium time to compute the size
--! @return a table containing storage information (size is in bytes)
function recording_utils.storageInfo(ifid, timeout)
  local storage_info = recording_utils.volumeInfo(dirs.pcapdir)

  -- Interface storage info
  storage_info.if_used = interfaceStorageUsed(ifid)

  -- PCAP Extraction storage info
  local extraction_path = getPcapExtractionPath(ifid)
  storage_info.extraction_used = getFolderSize(extraction_path, timeout)

  return storage_info
end

local function getN2diskInterfaceName(ifid)
   local cur_provider = recording_utils.getCurrentTrafficRecordingProvider(ifid)

   if cur_provider == "ntopng" then
      if interface.isPacketInterface() then
	 return getInterfaceName(ifid)
      else
	 return ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.ext_ifname')
      end
   else
      -- custom provider starts with n2disk@...
      -- the interface name of a custom provider it is assumed to be the one
      -- following the initial n2disk@
      return cur_provider:gsub("^n2disk@", "")
   end
end

-- Encode an interface name in a string that can be used in the n2disk configuration file name
local function getConfigInterfaceName(ifid)
  local ifname = getN2diskInterfaceName(ifid)
  return ifname:gsub("%,", "_")
end

local function n2disk_service_name(provider)
   -- a service that is started manually by the sysadmin is normally called n2disk
   -- a service that is started and managed by ntopng is called n2disk-ntopng
   return ternary(provider ~= "ntopng", "n2disk", "n2disk-ntopng")
end

local function n2diskctl(command, ifid, ...)
   local cur_provider = recording_utils.getCurrentTrafficRecordingProvider(ifid)
   local confifname = getConfigInterfaceName(ifid)

   return os_utils.ntopctlCmd(n2disk_service_name(cur_provider), command, confifname, ...)
end

--! @brief Generate a configuration for the traffic recording service (n2disk)
--! @param ifid the interface identifier 
--! @param params the traffic recording settings
function recording_utils.createConfig(ifid, params)
  local ifname = getN2diskInterfaceName(ifid)

  setLicenseFromRedis()

  if isEmptyString(ifname) then
    return false
  end

  local real_ifname = ifname
  if not interface.isPacketInterface() and isZCInterface(ifname) then
    -- real_ifname = ifname -- DEBUG
    real_ifname = "zc:"..ifname
  end

  local conf_dir = dirs.workingdir.."/n2disk"
  local filename = conf_dir.."/n2disk-" .. getConfigInterfaceName(ifid) .. ".conf"
  local storage_path = dirs.pcapdir

  if isEmptyString(storage_path) then
    return false
  end

  local defaults = {
    buffer_size = 1024,       -- Buffer size (MB)
    max_file_size = 256,      -- Max file length (MB)
    max_file_duration = 60,   -- Max file duration (sec)
    max_disk_space = recording_utils.default_disk_space, -- Max disk space (MB)
    snaplen = 1536,           -- Capture length
    writer_core = 0,          -- Writer thread affinity
    reader_core = 1,          -- Reader thread affinity
    indexer_cores = { 2 },    -- Indexer threads affinity
    -- Optional parameters
    -- zmq_endpoint = "tcp://*:5556" -- ZMQ endpoint for stats/flows
  }

  local ifspeed = (getInterfaceSpeed(getInterfaceId(ifname)) or 1000)

  -- Reading system memory info

  local mem_info = memInfo()
  local mem_available_mb = mem_info['MemAvailable']

  -- Computing file and buffer size

  local num_buffered_files = 4
  local min_file_size = 16 
  if ifspeed > 10000 then -- 40/100G
    defaults.max_file_size = 4*1024
    min_file_size = 1024
  elseif ifspeed > 1000 then -- 10G
    defaults.max_file_size = 1*1024
    min_file_size = 256
  elseif ifspeed > 100 then -- 1G
    defaults.max_file_size = 256
  else -- 10/100M
    defaults.max_file_size = 64
    num_buffered_files = 2
  end
  defaults.buffer_size = num_buffered_files * defaults.max_file_size

  local total_n2disk_mem = defaults.buffer_size * 2 -- pcap + index buffer

  if mem_available_mb ~= nil and mem_available_mb < total_n2disk_mem then
    local min_n2disk_buffer_size = (min_file_size * num_buffered_files) -- min memory for n2disk to work
    local min_n2disk_mem = min_n2disk_buffer_size * 2 -- pcap + index buffer
    if mem_available_mb < min_n2disk_mem then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Not enough memory available ("..mem_available_mb.."MB available, min required is "..min_n2disk_mem.."MB)") 
      return false
    end
    defaults.buffer_size = (mem_available_mb/2) -- leave some room for index memory and other processes
    defaults.max_file_size = math.floor(defaults.buffer_size/num_buffered_files)
  end

  -- Computing core affinity

  local indexing_threads = 1 -- 1G
  if ifspeed > 10000 then    -- 40/100G
    indexing_threads = 4
  elseif ifspeed > 1000 then -- 10G
    indexing_threads = 2
  end
  local n2disk_threads = indexing_threads + 2

  local line = os_utils.execWithOutput("nproc")
  local cores = tonumber(line)

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

  local pcap_path = recording_utils.getPcapPath(ifid)
  local timeline_path = getTimelinePath(ifid)

  f:write("--interface="..real_ifname.."\n")
  f:write("--dump-directory="..pcap_path.."\n")
  f:write("--index\n")
  f:write("--timeline-dir="..timeline_path.."\n")
  f:write("--buffer-len="..config.buffer_size.."\n")
  f:write("--max-file-len="..config.max_file_size.."\n")
  f:write("--max-file-duration="..config.max_file_duration.."\n")
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
  if not isEmptyString(prefs.user) then
    f:write("-u="..prefs.user.."\n");
  else
    f:write("--dont-change-user\n");
  end
  if interface.isPacketInterface() then
    if prefs.capture_direction == "in" then
      f:write("--capture-direction=1\n")
    elseif prefs.capture_direction == "out" then
      f:write("--capture-direction=2\n")
    else
      f:write("--capture-direction=0\n")
    end
  end
  if config.zmq_endpoint ~= nil then
    f:write("--zmq="..config.zmq_endpoint.."\n")
    f:write("--zmq-probe-mode\n")
    f:write("--zmq-export-flows\n")
  end
  -- Ignored by systemd, required by init.d
  f:write("--daemon\n")
  f:write("-P=/var/run/n2disk-"..ifname..".pid\n")

  f:close()

  return true
end

local function isRecordingEnabled(ifid)
  local cur_provider = recording_utils.getCurrentTrafficRecordingProvider(ifid)

  if cur_provider == "ntopng" then
    if isRecordingEnabledInCache(ifid) then
      return true
    end
  else
    -- if the user has specified a custom provider different than ntopng, it is
    -- assumed that he/she wants the recording so the service is considered enabled
    return true
  end

  return false
end 

--! @brief Check if traffic recording is available and enabled on an interface
--! @param ifid the interface identifier 
--! @return true if recording is enabled, false otherwise
function recording_utils.isEnabled(ifid)
  if recording_utils.isAvailable() then
    return isRecordingEnabled(ifid)
  end

  return false
end

--! @brief Check if traffic extraction is available and recording is enabled on an interface
--! @param ifid the interface identifier 
--! @return true if extraction is available and recording is enabled, false otherwise
function recording_utils.isExtractionEnabled(ifid)
  if recording_utils.isExtractionAvailable() then
    return isRecordingEnabled(ifid)
  end

  return false
end

local function isRecordingServiceActive(ifid)
   local cur_provider = recording_utils.getCurrentTrafficRecordingProvider(ifid)
   local confifname = getConfigInterfaceName(ifid)

   if cur_provider == "ntopng" then
      return os_utils.isActive("n2disk-ntopng", confifname)
   else
      return os_utils.isActive("n2disk", confifname)
   end
end

--! @brief Check if the traffic recording service is running
--! @param ifid the interface identifier 
--! @return true if the service is running, false otherwise
function recording_utils.isActive(ifid)
   if not recording_utils.isAvailable() then
      return false
   end

   return isRecordingServiceActive(ifid)
end

--! @brief Check if traffic recording is running and extraction is allowed for the current user on an interface
--! @param ifid the interface identifier 
--! @return true if the service is running and extraction available, false otherwise
function recording_utils.isExtractionActive(ifid)
   if not recording_utils.isExtractionAvailable() then
      return false
   end

   return isRecordingServiceActive(ifid)
end


function recording_utils.getAvailableTrafficRecordingProviders()
   local res = {}

   local list_with_status = os_utils.serviceListWithStatus("n2disk")
   for _, provider in ipairs(list_with_status) do
      res[#res + 1] = provider
   end

   -- this is the default provider, that is, ntopng
   -- when it manages an n2disk instance for the recording of traffic
   res[#res + 1] = {name = "ntopng"}

   return res
end

function recording_utils.getCurrentTrafficRecordingProvider(ifid)
   local traffic_recording_provider_pref = string.format("ntopng.prefs.traffic_recording.ifid_%d.provider", ifid)
   local provider = ntop.getCache(traffic_recording_provider_pref)

   return ternary(isEmptyString(provider), "ntopng", provider)
end

function recording_utils.setCurrentTrafficRecordingProvider(ifid, cur_provider)
   local traffic_recording_provider_pref = string.format("ntopng.prefs.traffic_recording.ifid_%d.provider", ifid)
   if cur_provider == "ntopng" then
      ntop.setCache(traffic_recording_provider_pref, cur_provider)
      return true
   end

   local providers = recording_utils.getAvailableTrafficRecordingProviders()

   for _, provider in ipairs(providers) do
      if provider["name"] == cur_provider then
	 ntop.setCache(traffic_recording_provider_pref, cur_provider)
	 return true
      end
   end

   return false
end

--! @brief Returns the path to the timeline of the selected traffic recorder
--! @param ifid the interface identifier 
--! @return the timeline, if found, or nil
function recording_utils.getCurrentTrafficRecordingProviderTimelinePath(ifid)
   local cur_provider = recording_utils.getCurrentTrafficRecordingProvider(ifid)

   if cur_provider == "ntopng" then
      return getTimelinePath(ifid)
   else
      local stats = recording_utils.stats(ifid)
      if stats["TimelinePath"] and ntop.exists(stats["TimelinePath"]) then
	 return "timeline:"..stats["TimelinePath"]
      end
   end
end

--! @brief Parse the configuration file of a manually-started n2disk and returns the timeline if found
--! @param ifid the interface identifier 
--! @return true if extraction is possible and false otherwise, along with a check message
function recording_utils.checkExtraction(ifid)
   local res = {}
   -- try and open the timeline. Failing to open the timeline would cause failing to do the extractions
   local timeline_path = recording_utils.getCurrentTrafficRecordingProviderTimelinePath(ifid)

   if not timeline_path then
      res = {status = "ERR_MISSING_TIMELINE"}
      -- timeline missing from the conf, won't be able to perform any extraction
   else
      timeline_path = timeline_path:gsub("^timeline:", "")

      if not ntop.exists(timeline_path) then
	 -- unable to read timeline
	 res = {status = "ERR_TIMELINE_PATH_NOT_EXISTING"}
      else
	 local f = io.open(timeline_path, "r")

	 if not f then
	    -- unable to open the timeline, insufficient permissions?
	    res = {status = "ERR_UNABLE_TO_ACCESS_TIMELINE"}
	 else
	    -- everything is OK
	    f:close()
	    res = {status = "OK"}
	 end
      end
   end

   return res["status"] == "OK", i18n(extraction_checks_to_i18n(res["status"]))
end

--! @brief Start (or restart) the traffic recording service
--! @param ifid the interface identifier 
function recording_utils.restart(ifid)
  local confifname = getConfigInterfaceName(ifid)
  os_utils.enableService("n2disk-ntopng", confifname)
  os_utils.restartService("n2disk-ntopng", confifname)
end

--! @brief Stop the traffic recording service
--! @param ifid the interface identifier 
function recording_utils.stop(ifid)
  local confifname = getConfigInterfaceName(ifid)
  os_utils.stopService("n2disk-ntopng", confifname)
  os_utils.disableService("n2disk-ntopng", confifname)
end

--! @brief Return the log trace of the traffic recording service (n2disk)
--! @param ifid the interface identifier 
--! @param rows the number of lines to return
--| @note lines are retuned in reverse order (most recent line first)
--! @return the log trace
function recording_utils.log(ifid, rows)
   return n2diskctl("log", ifid, "|tail -n", rows, "|tac")
end

--! @brief Return statistics from the traffic recording service (n2disk)
--! @param ifid the interface identifier
--! @return the statistics
function recording_utils.stats(ifid)
   local stats = {}
   local proc_stats = n2diskctl("stats", ifid)

   local lines = split(proc_stats, "\n") or {}

   for i = 1, #lines do
      local pair = split(lines[i], ": ")
      if pair[1] ~= nil and pair[2] ~= nil then
	 stats[pair[1]] = trimString(pair[2])
      end
   end

   return stats
end

-- Read information about used disk space for all ntopng interfaces 
-- (skipping the provided ifid if not nil)
local function allInterfacesStorageUsage(ifid)
  local info = { reserved_disk_space = 0, used_disk_space = 0, delta_disk_space = 0 }
  local ntopng_interfaces = interface.getIfNames()
  for id,name in pairs(ntopng_interfaces) do
    if ifid == nil or id ~= ifid then
      if isRecordingEnabledInCache(id) then
        local disk_space = ntop.getCache('ntopng.prefs.ifid_'..id..'.traffic_recording.disk_space')
        local if_disk_space = 0
        if not isEmptyString(disk_space) then
          if_disk_space = tonumber(disk_space)
        end
        info.reserved_disk_space = info.reserved_disk_space + (if_disk_space*1024*1024)
        info.used_disk_space = info.used_disk_space + interfaceStorageUsed(id)
      end
    end
  end
  if info.reserved_disk_space > info.used_disk_space then
    info.delta_disk_space = info.reserved_disk_space - info.used_disk_space -- available, to be used
  end
  return info
end

function recording_utils.recommendedSpace(ifid, storage_info)
  -- available disk space
  local avail = storage_info.avail + storage_info.if_used

  -- compute available disk space based on space reserved by other interfaces
  local current = allInterfacesStorageUsage(ifid)
  if avail > current.delta_disk_space then
    avail = avail - current.delta_disk_space
  else
    avail = 0
  end

  local recommended = avail - (avail*0.2)
  return math.floor(recommended)
end

--! @brief Check if there is pcap data for a specified time interval (fully included in the dump window) 
--! @param ifid the interface identifier 
--! @param epoch_begin the begin time (epoch)
--! @param epoch_end the end time (epoch)
--! @return a table with 'available' = true if the specified interval is included in the dump window, 'epoch_begin'/'epoch_end' are also returned with the actual available window.
function recording_utils.isDataAvailable(ifid, epoch_begin, epoch_end)
   local info = {}
   info.available = false

   if recording_utils.isExtractionEnabled(ifid) then
      local stats = recording_utils.stats(ifid)

      if stats['FirstDumpedEpoch'] ~= nil and stats['LastDumpedEpoch'] ~= nil then
	 local first_epoch = tonumber(stats['FirstDumpedEpoch'])
	 local last_epoch = tonumber(stats['LastDumpedEpoch'])

	 if first_epoch > 0 and last_epoch > 0 and 
              epoch_end > first_epoch and epoch_begin < last_epoch then
	    info.epoch_begin = epoch_begin
	    info.epoch_end = epoch_end
	    if first_epoch > epoch_begin then
	       info.epoch_begin = first_epoch
	    end
	    if last_epoch < epoch_end then
	       info.epoch_end = last_epoch
	    end
	    info.available = true
	 end
      end
   end

   if recording_utils.getCurrentTrafficRecordingProvider(ifid) ~= "ntopng" then
      local extraction_checks_ok, extraction_checks_msg = recording_utils.checkExtraction(ifid)

      if not extraction_checks_ok then
	 info.available = nil
	 info.extraction_checks_msg = extraction_checks_msg
      end
   end

   return info
end

--! @brief Return the list of pcap files extracted for a job
--! @param job_id the job identifier 
--! @return the list of pcap files (paths)
function recording_utils.getJobFiles(id)
   local job_json = ntop.getHashCache(extraction_jobs_key, id)
   local files = {}
   if not isEmptyString(job_json) then
      local job = json.decode(job_json)
      local file_id = 1
      local file = getPcapFilePath(job.id, job.ifid, file_id)
      while ntop.exists(file) do
	 table.insert(files, file)
	 file_id = file_id + 1
	 file = getPcapFilePath(job.id, job.ifid, file_id) 
      end
   end
   return files
end

--! @brief Delete an extraction job and its pcap data on disk, if any
--! @param job_id the job identifier 
function recording_utils.deleteJob(job_id)
  local job_json = ntop.getHashCache(extraction_jobs_key, job_id)
  if not isEmptyString(job_json) then
    ntop.delHashCache(extraction_jobs_key, tostring(job_id))
    local job = json.decode(job_json)
    local dir_path = getPcapFileDir(job.id, job.ifid)
    ntop.rmdir(dir_path)
  end
end

--! @brief Delete and stop all the extraction jobs for the specified interface.
--! @param ifid the interface identifier
function recording_utils.deleteAndStopAllJobs(ifid)
  for _, job in pairs(recording_utils.getExtractionJobs(ifid)) do
    if job.status == "completed" then
      recording_utils.deleteJob(job.id)
    else
      recording_utils.stopJob(job.id)
    end
  end
end

--! @brief Return statistics about the extraction jobs.
--! @param ifid the interface identifier 
--! @return the jobs statistics (ready, total)
function recording_utils.extractionJobsInfo(ifid)
  local job_ids = ntop.getHashKeysCache(extraction_jobs_key) or {}
  local jobs_info = { total = 0, ready = 0 }

  for id,_ in pairs(job_ids) do
    local job_json = ntop.getHashCache(extraction_jobs_key, id)
    local job = json.decode(job_json)
    if ifid == nil or job.ifid == ifid then
      if job.status == "completed" or job.status == "failed" then
        jobs_info.ready = jobs_info.ready + 1
      end
      jobs_info.total = jobs_info.total + 1
    end
  end

  return jobs_info
end

--! @brief Return the list of scheduled extraction jobs.
--! @param ifid the interface identifier
--! @return the list of jobs
function recording_utils.getExtractionJobs(ifid)
  local jobs = {}
  local job_ids = ntop.getHashKeysCache(extraction_jobs_key) or {}

  for id,_ in pairs(job_ids) do
    local job_json = ntop.getHashCache(extraction_jobs_key, id)
    local job = json.decode(job_json)
    if ifid == nil or job.ifid == ifid then
      jobs[tonumber(id)] = job
    end
  end

  return jobs
end

--! @brief Stop a running extraction job.
--! @param job_id the job identifier 
function recording_utils.stopJob(job_id)
  ntop.rpushCache(extraction_stop_queue_key, job_id)
end

--! @brief Schedule a new extraction job.
--! @param ifid the interface identifier 
--! @param params the extraction parameters. time_from/time_to (epoch) are mandatory. filter (nBPF format) is optional.
--! @return the newly created job 
function recording_utils.scheduleExtraction(ifid, params)

  if params.time_from == nil or params.time_to == nil then
    return nil
  end
  if params.filter == nil then
    params.filter = ""
  end

  local id = ntop.incrCache(extraction_seqnum_key)

  local job = {
    id = id,
    ifid = tonumber(ifid),
    time = os.time(),
    status = 'waiting',
    time_from = tonumber(params.time_from),
    time_to = tonumber(params.time_to),
    filter = params.filter,
    chart_url = params.chart_url,
    timeline_path = params.timeline_path
  }

  ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job))

  ntop.rpushCache(extraction_queue_key, tostring(job.id))
  
  local job_info = { id = job.id }
  return job_info
end

local function setStuckJobsAsFailed()
  local jobs = {}
  local job_ids = ntop.getHashKeysCache(extraction_jobs_key) or {}

  for id,_ in pairsByKeys(job_ids, rev) do
    local job_json = ntop.getHashCache(extraction_jobs_key, id)
    local job = json.decode(job_json)
    if job.status == "processing" then
      job.status = "failed"
      job.error_code = 9 -- stuck
      ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job))
    else
      break -- optimization
    end
  end
end

local function setJobAsCompleted()
  local datapath_extractions = ntop.getExtractionStatus()
  for id,status in pairs(datapath_extractions) do
    local job_json = ntop.getHashCache(extraction_jobs_key, id)
    if not isEmptyString(job_json) then
      local job = json.decode(job_json)
      if job.status == "processing" then
        if status.status == 0 then
          job.status = "completed"
        else
          job.status = "failed"
          job.error_code = status.status
        end
        job.extracted_pkts = status.extracted_pkts
        job.extracted_bytes = status.extracted_bytes
        ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job)) 
      end
    end
  end
  setStuckJobsAsFailed()
end

-- Manages extraction jobs. This is called from a single, periodic script (housekeeping.lua) 
function recording_utils.checkExtractionJobs()

  -- stop extractions for stopped jobs, if any
  if ntop.isExtractionRunning() then
    local id = ntop.lpopCache(extraction_stop_queue_key)
    if not isEmptyString(id) then
      local job_json = ntop.getHashCache(extraction_jobs_key, id)
      if not isEmptyString(job_json) then
        local job = json.decode(job_json)

        -- job has been stopped, stopping extraction
        ntop.stopExtraction(job.id)

        job.status = 'stopped'
        ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job))
      end
    end
  end

  if not ntop.isExtractionRunning() then
    -- set the previous job as completed, if any
    if ntop.getCache(is_running_job_pending_key) == "1" then
      setJobAsCompleted()
      ntop.setCache(is_running_job_pending_key, "0")
    end

    -- run a new extraction job
    local id = ntop.lpopCache(extraction_queue_key)
    if not isEmptyString(id) then
      local job_json = ntop.getHashCache(extraction_jobs_key, id)
      if not isEmptyString(job_json) then
        local job = json.decode(job_json)

        -- computing available space as safety check
        local extraction_limit = 0
        local storage_info = recording_utils.storageInfo(job.ifid)
        local usage = allInterfacesStorageUsage(nil)
        if storage_info.avail > usage.delta_disk_space then
          local avail = storage_info.avail - usage.delta_disk_space
          extraction_limit = math.floor(avail)
        else
          extraction_limit = nil
        end 

        if extraction_limit ~= nil then
          -- running extraction
          ntop.runExtraction(job.id, 
            tonumber(job.ifid), 
            tonumber(job.time_from), 
            tonumber(job.time_to), 
            job.filter, 
            extraction_limit,
	    job.timeline_path)

          ntop.setCache(is_running_job_pending_key, "1")

          job.status = 'processing'
          ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job))
        else
          -- no space available - delay this job
          job.status = 'waiting_nospace'
          ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job))
          ntop.rpushCache(extraction_queue_key, tostring(job.id))
        end
      end
    end
  end
end

-- #################################

return recording_utils

