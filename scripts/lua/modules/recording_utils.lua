--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()

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

function recording_utils.createConfig(ifname, params)
   local filename = "/etc/n2disk/n2disk-"..ifname..".conf"

   local defaults = {
      path = "/storage",        -- Storage path
      buffer_size = 4*1024,     -- Buffer size (MB)
      max_file_size = 1024,     -- Max file length
      max_disk_space = 10*1024, -- Max disk space (MB)
      snaplen = 1536,           -- Capture length
      writer_core = 0,          -- Writer thread affinity
      reader_core = 1,          -- Reader thread affinity
      indexer_cores = "2,3",    -- Indexer threads affinity
   }

   -- TODO 
   -- - auto-tune cpu affinity based on the actual cpu and ntopng configuration
   -- - auto-size max file size based on interface speed
   -- - write the configuration file in a place where ntopng can write

   if params.path == nil then -- mandatory parameters here
      return false
   end

   local config = table.merge(defaults, params)

   local f = io.open(filename, "w")

   if not f then
      return false
   end

   f:write("--interface="..config.interface.."\n")
   f:write("--dump-directory="..config.path.."/n2disk/"..ifname.."\n")
   f:write("--index\n")
   f:write("--timeline-dir="..config.path.."/n2disk/"..ifname.."\n")
   f:write("--buffer-len="..config.buffer_size.."\n")
   f:write("--max-file-len="..config.max_file_size.."\n")
   f:write("--disk-limit="..config.max_disk_space.."\n")
   f:write("--snaplen="..config.snaplen.."\n")
   f:write("--writer-cpu-affinity="..config.writer_core.."\n")
   f:write("--reader-cpu-affinity="..config..reader_core."\n")
   f:write("--compressor-cpu-affinity="..config..indexer_cores."\n")
   f:write("--index-on-compressor-threads\n")

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

